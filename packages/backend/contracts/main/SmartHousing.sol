// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

import "../lib/TokenPayments.sol";
import "../modules/sht-module/SHT.sol";
import "../project-funding/ProjectFunding.sol";
import "./Interface.sol";
import "./User.sol";

import { Distribution } from "./distribution/Storage.sol";
import { Epochs } from "../lib/Epochs.sol";
import { HousingStakingToken, NewHousingStakingToken, MIN_EPOCHS_LOCK, MAX_EPOCHS_LOCK, HstAttributes } from "./HST.sol";
import { HousingProject } from "../housing-project/HousingProject.sol";
import { rewardshares } from "../housing-project/RewardSharing.sol";
import { LkSHT } from "../modules/LockedSmartHousingToken.sol";

/// @title SmartHousing
/// @notice SmartHousing enables real estate tokenization for fractional ownership and investment.
/// @dev Main contract for the SmartHousing ecosystem. Manages HousingProjects, users, and staking.
contract SmartHousing is ISmartHousing, Ownable, UserModule, ERC1155Holder {
	using TokenPayments for ERC20TokenPayment;
	using Distribution for Distribution.Storage;
	using Epochs for Epochs.Storage;
	using EnumerableSet for EnumerableSet.AddressSet;
	using TokenPayments for TokenPayment;
	using SafeMath for uint256;

	// Contract addresses and instances
	address public projectFundingAddress;
	address public coinbaseAddress;
	address public shtTokenAddress;
	HousingStakingToken public hst;
	LkSHT public lkSht;

	// Storage for distribution and epochs
	Distribution.Storage public distributionStorage;
	Epochs.Storage public epochs;

	// Permission management
	enum Permissions {
		NONE,
		HOUSING_PROJECT
	}
	mapping(address => Permissions) public permissions;
	EnumerableSet.AddressSet private _projectsToken; // List of project SFT addresses

	/// @notice Constructor to initialize SmartHousing.
	/// @param coinbase Address of the coinbase.
	/// @param projectFunding Address of the ProjectFunding contract.
	constructor(address coinbase, address projectFunding) {
		coinbaseAddress = coinbase;
		projectFundingAddress = projectFunding;
		hst = NewHousingStakingToken.create();
		lkSht = ProjectFunding(projectFundingAddress).lkSht();

		// Initialize epochs and periods (24 hours for mainnet, 30 minutes for testing)
		epochs.initialize(30 minutes);
	}

	/// @notice Register a new user or get the referral ID if already registered.
	/// @param userAddr Address of the user.
	/// @param referrerId Referral ID of the referrer.
	/// @return User ID.
	function createRefIDViaProxy(
		address userAddr,
		uint256 referrerId
	) external onlyProjectFunding returns (uint256) {
		return _createOrGetUserId(userAddr, referrerId);
	}

	/// @notice Setup SHT token and distribute funds.
	/// @param payment Token payment details for SHT setup.
	function setUpSHT(ERC20TokenPayment calldata payment) external {
		require(msg.sender == coinbaseAddress, "Unauthorized");
		require(shtTokenAddress == address(0), "SHT already set");
		shtTokenAddress = address(payment.token);
		require(
			payment.amount == SHT.ECOSYSTEM_DISTRIBUTION_FUNDS,
			"Incorrect SHT amount"
		);
		payment.accept();

		distributionStorage.setTotalFunds(payment.amount);
	}

	/// @notice Add a new project and set its permissions.
	/// @param projectAddress Address of the new project.
	function addProject(address projectAddress) external onlyProjectFunding {
		_setPermissions(projectAddress, Permissions.HOUSING_PROJECT);
		HousingProject project = HousingProject(projectAddress);
		address projectSFTaddress = address(project.projectSFT());
		_projectsToken.add(projectSFTaddress);

		distributionStorage.addProject(
			projectAddress,
			projectSFTaddress,
			project.getMaxSupply()
		);
	}

	/// @notice Add rent to a project and update distribution storage.
	/// @param amount Amount of rent received.
	function addProjectRent(uint256 amount) external onlyHousingProject {
		address projectAddress = msg.sender;
		distributionStorage.addProjectRent(projectAddress, amount);
	}

	/// @notice Stake tokens for rewards.
	/// @param stakingTokens Array of token payments for staking.
	/// @param epochsLock Lock period in epochs.
	/// @param referrerId Referral ID of the referrer.
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

		_createOrGetUserId(caller, referrerId);
		distributionStorage.generateRewards(epochs);

		HstAttributes memory newAttr = _mintHstToken(
			stakingTokens,
			distributionStorage.projectsStakingRewards.checkpoint,
			distributionStorage.shtRewardPerShare,
			epochsLock,
			address(lkSht)
		);

		distributionStorage.enterStaking(newAttr.stakeWeight);
	}

	/// @notice Check if a user can claim rewards.
	/// @param user Address of the user.
	/// @param tokenNonce Nonce of the token.
	/// @return True if the user can claim rewards, otherwise false.
	function userCanClaim(
		address user,
		uint256 tokenNonce
	) public view returns (bool) {
		bool hasSft = hst.hasSFT(user, tokenNonce);
		if (!hasSft) return false;

		bool rewardsCanBeGenerated = distributionStorage
			.lastFundsDispatchTimestamp < block.timestamp;
		if (rewardsCanBeGenerated) return true;

		HstAttributes memory hstAttr = hst.getAttribute(tokenNonce);
		return
			hstAttr.shtRewardPerShare < distributionStorage.shtRewardPerShare;
	}

	/// @notice Claim rewards and update token attributes.
	/// @param hstNonce Nonce of the HST token.
	/// @param referrerId Referral ID of the referrer.
	/// @return newHstNonce New HST nonce.
	function claimRewards(
		uint256 hstNonce,
		uint256 referrerId
	) external returns (uint256 newHstNonce) {
		address caller = msg.sender;
		_createOrGetUserId(caller, referrerId);

		uint256 callerHstBal = hst.balanceOf(caller, hstNonce);
		require(callerHstBal > 0, "No HST token balance at nonce");

		distributionStorage.generateRewards(epochs);
		(uint256 claimedSHT, HstAttributes memory hstAttr) = distributionStorage
			.claimRewards(hst.getAttribute(hstNonce));
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
			(, address referrerAddr) = getReferrer(caller);
			if (referrerAddr != address(0)) {
				shtToken.transfer(referrerAddr, referrerValue);
			} else {
				shtToken.burn(referrerValue);
			}
		}

		shtToken.transfer(caller, claimedSHT.add(rentRewards));
	}

	/// @notice Get project distribution details.
	/// @param project Address of the project.
	/// @return Project distribution data.
	function projectDets(
		address project
	) public view returns (Distribution.ProjectDistributionData memory) {
		return distributionStorage.projectDets[project];
	}

	/// @notice Get the list of project tokens.
	/// @return Array of project token addresses.
	function projectsToken() public view returns (address[] memory) {
		return _projectsToken.values();
	}

	// Internal functions

	/// @notice Set permissions for an address.
	/// @param addr Address to set permissions for.
	/// @param perm Permissions to set.
	function _setPermissions(address addr, Permissions perm) internal {
		permissions[addr] = perm;
	}

	function _prepareProjectTokensAndLkShtNonces(
		TokenPayment[] calldata payments,
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

			if (payment.token == shtTokenAddress) {
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

	/// @notice Prepare project tokens and LkSHT for staking.
	/// @param payments Array of tokens to prepare.
	/// @param epochsLock Number of epochs to lock.
	/// @param projectsShareCheckpoint Number of epochs to lock.
	/// @param lkShtAddress Address of the LkSHT token.
	/// @return Attributes of the new HST token.
	function _mintHstToken(
		TokenPayment[] calldata payments,
		uint256 projectsShareCheckpoint,
		uint256 shtRewardPerShare,
		uint256 epochsLock,
		address lkShtAddress
	) internal returns (HstAttributes memory) {
		address caller = msg.sender;

		uint256 projectTokenCount = 0;
		uint256 lkShtNoncesCount = 0;
		uint256 shtAmount = 0;

		(
			TokenPayment[] memory projectTokens,
			uint256[] memory lkShtNonces
		) = _prepareProjectTokensAndLkShtNonces(payments, lkShtAddress);
		require(
			(projectTokens.length + lkShtNonces.length) < 10,
			"Max SFT tokens exceeded"
		);

		for (uint256 i = 0; i < payments.length; i++) {
			TokenPayment memory payment = payments[i];

			if (payment.token == shtTokenAddress) {
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
				epochsLock,
				shtAmount,
				lkShtNonces,
				caller
			);
	}

	// Modifiers

	/// @notice Modifier to check if caller is authorized to interact with the contract.
	modifier onlyProjectFunding() {
		require(msg.sender == projectFundingAddress, "Not authorized");
		_;
	}

	/// @notice Modifier to check if caller is a housing project.
	modifier onlyHousingProject() {
		require(
			permissions[msg.sender] == Permissions.HOUSING_PROJECT,
			"Not authorized"
		);
		_;
	}
}
