// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "../lib/TokenPayments.sol";
import "../modules/sht-module/SHT.sol";
import "../project-funding/ProjectFunding.sol";

import "./Interface.sol";
import "./User.sol";

import { Distribution } from "./distribution/Storage.sol";
import { EpochsAndPeriods } from "../lib/EpochsAndPeriods.sol";
import { HousingStakingToken, NewHousingStakingToken, MIN_EPOCHS_LOCK, MAX_EPOCHS_LOCK, HstAttributes } from "./HST.sol";

import { HousingProject } from "../housing-project/HousingProject.sol";
import { rewardshares } from "../housing-project/RewardSharing.sol";
import { LkSHT } from "../modules/LockedSmartHousingToken.sol";
import { ProjectFunding } from "../project-funding/ProjectFunding.sol";

/// @title SmartHousing
/// @notice SmartHousing leverages blockchain technology to revolutionize real estate investment and development by enabling the tokenization of properties.
/// @dev This contract allows for fractional ownership and ease of investment.
/// This innovative approach addresses the high costs and limited access to real estate investments in Abuja, Nigeria, making the market more inclusive and accessible.
/// By selling tokens, SmartHousing provides developers with immediate access to liquid funds, ensuring the timely and quality completion of affordable development projects.
/// The SmartHousing Contract is the main contract for the SmartHousing ecosystem.
/// This contract owns and deploys HousingProject contracts, which will represent the properties owned and managed by the SmartHousing project.
/// The management of ecosystem users will also be done in this contract.
contract SmartHousing is ISmartHousing, Ownable, UserModule, ERC1155Holder {
	using TokenPayments for ERC20TokenPayment;
	using Distribution for Distribution.Storage;
	using EpochsAndPeriods for EpochsAndPeriods.Storage;
	using EnumerableSet for EnumerableSet.AddressSet;
	using TokenPayments for TokenPayment;
	using SafeMath for uint256;

	address public projectFundingAddress;
	address public coinbaseAddress;
	address public shtTokenAddress;
	HousingStakingToken public hst;
	LkSHT public lkSht;

	Distribution.Storage public distributionStorage;
	EpochsAndPeriods.Storage public epochsAndPeriodsStorage;

	enum Permissions {
		NONE,
		HOUSING_PROJECT
	}

	mapping(address => Permissions) public permissions;
	EnumerableSet.AddressSet private _projectsToken; // Enumerable list of project addresses

	constructor(address coinbase, address projectFunding) {
		coinbaseAddress = coinbase;
		projectFundingAddress = projectFunding;
		hst = NewHousingStakingToken.create();
		lkSht = ProjectFunding(projectFundingAddress).lkSht();

		// TODO set this from env vars
		// TODO use this for mainnet epochsAndPeriodsStorage.initialize(24); // One epoch will span 24 seconds
		epochsAndPeriodsStorage.initialize(1); // One epoch will span 1 second
	}

	/// @notice Register a new user via proxy or get the referral ID if already registered.
	/// @param userAddr The address of the user.
	/// @param referrerId The ID of the referrer.
	/// @return The ID of the registered user.
	function createRefIDViaProxy(
		address userAddr,
		uint256 referrerId
	) external onlyProjectFunding returns (uint256) {
		return _createOrGetUserId(userAddr, referrerId);
	}

	function setUpSHT(ERC20TokenPayment calldata payment) external {
		require(
			msg.sender == coinbaseAddress,
			"Caller is not the coinbase address"
		);

		// Ensure that the SHT token has not been set already
		require(shtTokenAddress == address(0), "SHT token already set");
		shtTokenAddress = address(payment.token);

		// Verify that the correct amount of SHT has been sent
		require(
			payment.amount == SHT.ECOSYSTEM_DISTRIBUTION_FUNDS,
			"Must send all ecosystem funds"
		);
		payment.accept();

		// Set the total funds in distribution storage
		distributionStorage.setTotalFunds(
			epochsAndPeriodsStorage,
			payment.amount
		);
	}

	/// @notice Adds a new project and sets its permissions.
	/// @param projectAddress The address of the new project.
	function addProject(address projectAddress) external onlyProjectFunding {
		_setPermissions(projectAddress, Permissions.HOUSING_PROJECT);
		HousingProject project = HousingProject(projectAddress);
		address projectSFTaddress = address(
			HousingProject(projectAddress).projectSFT()
		);

		_projectsToken.add(projectSFTaddress); // Register the project's SFT address

		distributionStorage.addProject(
			projectAddress,
			projectSFTaddress,
			project.getMaxSupply()
		);
	}

	/// @notice Adds rent to a project and updates the distribution storage.
	/// @dev projectAddress is the msg.msg.sender which must be a recognised HousingProject contract
	/// @param amount The amount of rent received.
	function addProjectRent(uint256 amount) external onlyHousingProject {
		address projectAddress = msg.sender;
		distributionStorage.addProjectRent(projectAddress, amount);
	}

	function stake(
		TokenPayment[] calldata stakingTokens,
		uint256 epochsLock,
		uint256 referrerId
	) external {
		require(
			epochsLock >= MIN_EPOCHS_LOCK && epochsLock <= MAX_EPOCHS_LOCK,
			"Invalid epochs lock period"
		);

		address caller = msg.sender;

		// Try create ID
		_createOrGetUserId(caller, referrerId);

		// Generate rewards before staking
		distributionStorage.generateRewards(epochsAndPeriodsStorage);

		HstAttributes memory newAttr = _mintHstToken(
			stakingTokens,
			distributionStorage.projectsStakingRewards.checkpoint,
			distributionStorage.shtRewardPerShare,
			epochsLock,
			shtTokenAddress,
			address(ProjectFunding(projectFundingAddress).lkSht())
		);

		distributionStorage.enterStaking(newAttr.stakeWeight);
	}

	function currentEpoch() public view returns (uint256) {
		return epochsAndPeriodsStorage.currentEpoch();
	}

	function currentPeriod() internal view returns (uint256) {
		return epochsAndPeriodsStorage.currentPeriod();
	}

	function userCanClaim(
		address user,
		uint256 tokenNonce
	) public view returns (bool) {
		bool hasSft = hst.hasSFT(user, tokenNonce);
		if (!hasSft) {
			// User can't claim reward of token they don't own
			return false;
		}

		// hstAttr.shtRewardPerShare and distributionStorage.shtRewardPerShare could be equal
		// becasue of recent rewards genrated, so we check if rewards can be generated,
		// if yes, then user can potential claim rewards
		bool rewardsCanBeGenerated = distributionStorage
			.lastFundsDispatchEpoch < currentEpoch();
		if (rewardsCanBeGenerated) {
			return true;
		}

		HstAttributes memory hstAttr = abi.decode(
			hst.getRawTokenAttributes(tokenNonce),
			(HstAttributes)
		);

		return
			hstAttr.shtRewardPerShare < distributionStorage.shtRewardPerShare;
	}

	function claimRewards(
		uint256 hstNonce,
		uint256 referrerId
	) external returns (uint256 newHstNonce) {
		address caller = msg.sender;
		_createOrGetUserId(caller, referrerId);

		uint256 callerHstBal = hst.balanceOf(caller, hstNonce);

		require(callerHstBal > 0, "Caller does not own the hst token");

		distributionStorage.generateRewards(epochsAndPeriodsStorage);

		(uint256 claimedSHT, HstAttributes memory hstAttr) = distributionStorage
			.claimRewards(
				abi.decode(hst.getRawTokenAttributes(hstNonce), (HstAttributes))
			);
		uint256 rentRewards = 0;

		// Claim rent rewards from HousingProjects
		for (uint256 i = 0; i < hstAttr.projectTokens.length; i++) {
			TokenPayment memory projectToken = hstAttr.projectTokens[i];
			require(
				projectToken.token != address(0),
				"Invalid project address"
			);
			address projectAddress = distributionStorage
				.projectSftToProjectAddress[projectToken.token];

			// Call the external contract's claimRentReward function
			(
				,
				rewardshares memory rewardShares,
				uint256 newNonce
			) = HousingProject(projectAddress).claimRentReward(
					projectToken.nonce
				);
			hstAttr.projectTokens[i].nonce = newNonce;

			rentRewards = rentRewards.add(rewardShares.userValue);
		}

		// Update the attributes in the hst token
		newHstNonce = hst.update(
			caller,
			hstNonce,
			callerHstBal,
			abi.encode(hstAttr)
		);

		ERC20Burnable shtToken = ERC20Burnable(shtTokenAddress);

		if (claimedSHT > 0) {
			uint256 referrerValue = claimedSHT.mul(25).div(1000);
			claimedSHT = claimedSHT.sub(referrerValue);

			// Do referrer operations
			(, address referrerAddr) = getReferrer(caller);
			if (referrerAddr != address(0)) {
				shtToken.transfer(referrerAddr, referrerValue);
			} else {
				shtToken.burn(referrerValue);
			}
		}

		shtToken.transfer(caller, claimedSHT.add(rentRewards));
	}

	function projectDets(
		address project
	) public view returns (Distribution.ProjectDistributionData memory) {
		return distributionStorage.projectDets[project];
	}

	function projectsToken() public view returns (address[] memory) {
		return _projectsToken.values();
	}

	/// @notice Sets the permissions for a given address.
	/// @param addr The address to set permissions for.
	/// @param perm The permissions to set.
	function _setPermissions(address addr, Permissions perm) internal {
		permissions[addr] = perm;
	}

	function _prepareProjectTokensAndLkShtNonces(
		TokenPayment[] calldata payments,
		address shtAddress,
		address lkShtAddress
	)
		internal
		view
		returns (
			TokenPayment[] memory projectTokens,
			uint256[] memory lkShtNonces
		)
	{
		uint256 projectTokensCount = 0;
		uint256 lkShtNoncesCount = 0;

		for (uint256 i = 0; i < payments.length; i++) {
			TokenPayment memory payment = payments[i];

			if (payment.token == shtAddress) {
				// Do nothing
			} else if (payment.token == lkShtAddress) {
				lkShtNoncesCount++;
			} else if (_projectsToken.contains(payment.token)) {
				projectTokensCount++;
			} else {
				revert("Invalid Sent Token");
			}
		}

		projectTokens = new TokenPayment[](projectTokensCount);
		lkShtNonces = new uint256[](lkShtNoncesCount);
	}

	function _mintHstToken(
		TokenPayment[] calldata payments,
		uint256 projectsShareCheckpoint,
		uint256 shtRewardPerShare,
		uint256 lkDuration,
		address shtAddress,
		address lkShtAddress
	) internal returns (HstAttributes memory attr) {
		address caller = msg.sender;

		uint256 projectTokenCount = 0;
		uint256 lkShtNoncesCount = 0;
		uint256 shtAmount = 0;

		(
			TokenPayment[] memory projectTokens,
			uint256[] memory lkShtNonces
		) = _prepareProjectTokensAndLkShtNonces(
				payments,
				shtAddress,
				lkShtAddress
			);
		require(
			(projectTokens.length + lkShtNonces.length) < 10,
			"Max SFT tokens exceeded"
		);

		for (uint256 i = 0; i < payments.length; i++) {
			TokenPayment memory payment = payments[i];

			if (payment.token == shtAddress) {
				shtAmount = shtAmount.add(payment.amount);
			} else if (payment.token == lkShtAddress) {
				uint256 lkShtBal = lkSht.balanceOf(caller, payment.nonce);
				require(
					lkShtBal == payment.amount,
					"Must send all LkSHT balance"
				);

				shtAmount = shtAmount.add(lkShtBal);
				lkShtNonces[lkShtNoncesCount] = payment.nonce;
				lkShtNoncesCount++;
			} else if (_projectsToken.contains(payment.token)) {
				projectTokens[projectTokenCount] = payment;
				projectTokenCount++;
			} else {
				revert("Invalid Sent Token");
			}

			payment.receiveToken(caller);
		}

		return
			hst.mint(
				projectTokens,
				projectsShareCheckpoint,
				shtRewardPerShare,
				lkDuration,
				shtAmount,
				lkShtNonces,
				caller
			);
	}

	modifier onlyProjectFunding() {
		require(
			msg.sender == projectFundingAddress,
			"Caller is not the project funder"
		);
		_;
	}

	modifier onlyHousingProject() {
		require(
			permissions[msg.sender] == Permissions.HOUSING_PROJECT,
			"Caller is not an accepted housing project"
		);
		_;
	}
}
