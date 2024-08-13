// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RentsModule.sol";
import "./CallsSmartHousing.sol";

/// @title HousingProject Contract
/// @notice Represents a unique real estate project within the SmartHousing ecosystem.
/// @dev This contract inherits from RentsModule and Ownable for management functions.
contract HousingProject is RentsModule, Ownable, CallsSmartHousing {
	using RewardShares for rewardshares;
	using TokenPayments for ERC20TokenPayment;

	// State Variables
	uint256 public rewardsReserve;
	uint256 public facilityManagementFunds;

	// Constants
	uint256 public constant REWARD_PERCENT = 75;
	uint256 public constant ECOSYSTEM_PERCENT = 18;
	uint256 public constant FACILITY_PERCENT = 7;

	HousingSFT public immutable projectSFT;
	ERC20Burnable public immutable housingToken;

	/// @notice Initializes the HousingProject contract.
	/// @param smartHousingAddr The address of the main SmartHousing contract.
	/// @param housingTokenAddr Coinbase contraact address
	/// @param name The name of the HousingSFT token.
	/// @param symbol The symbol of the HousingSFT token.
	constructor(
		string memory name,
		string memory symbol,
		address smartHousingAddr,
		address housingTokenAddr
	) CallsSmartHousing(smartHousingAddr) {
		projectSFT = new HousingSFT(name, symbol);

		// Initialize the housing token
		housingToken = ERC20Burnable(housingTokenAddr);
	}

	/// @notice Receives rent payments, calculates, and distributes rewards.
	/// @param rentPayment The details of the rent payment.
	function receiveRent(ERC20TokenPayment calldata rentPayment) external {
		uint256 rentAmount = rentPayment.amount;
		require(rentAmount > 0, "RentsModule: Insufficient amount");
		require(
			rentPayment.token == housingToken,
			"RentsModule: Invalid token"
		);

		rentPayment.receiveERC20();

		uint256 rentReward = (rentAmount * REWARD_PERCENT) / 100;
		uint256 ecosystemReward = (rentAmount * ECOSYSTEM_PERCENT) / 100;
		uint256 facilityReward = (rentAmount * FACILITY_PERCENT) / 100;

		// Update rewards and reserve
		rewardPerShare +=
			(rentReward * DIVISION_SAFETY_CONST) /
			projectSFT.getMaxSupply();
		rewardsReserve += rentReward;
		facilityManagementFunds += facilityReward;

		// Burn ecosystem reward and notify SmartHousing contract
		housingToken.burn(ecosystemReward);
		ISmartHousing(smartHousingAddr).addProjectRent(rentAmount);
	}

	/// @notice Claims rent rewards for a given token and updates attributes.
	/// @param nonce The nonce of the token to claim rewards for.
	/// @return attr The updated HousingAttributes.
	/// @return rewardShares The computed reward shares.
	/// @return newNonce The new nonce after updating the token.
	function claimRentReward(
		uint256 nonce
	)
		external
		returns (
			HousingAttributes memory attr,
			rewardshares memory rewardShares,
			uint256 newNonce
		)
	{
		address caller = msg.sender;
		uint256 currentRPS = rewardPerShare;

		attr = projectSFT.getUserSFT(caller, nonce);
		rewardShares = _computeRewardShares(attr);

		uint256 totalReward = rewardShares.total();
		if (totalReward == 0) {
			return (attr, rewardShares, nonce);
		}

		require(
			rewardsReserve >= totalReward,
			"RentsModule: Insufficient rewards reserve"
		);
		rewardsReserve -= totalReward;

		(, address referrer) = _getReferrer(attr.originalOwner);
		if (rewardShares.referrerValue > 0) {
			if (referrer != address(0)) {
				housingToken.transfer(referrer, rewardShares.referrerValue);
			} else {
				housingToken.burn(rewardShares.referrerValue);
			}
		}

		attr.rewardsPerShare = currentRPS;

		newNonce = projectSFT.update(
			caller,
			nonce,
			projectSFT.balanceOf(caller, nonce),
			abi.encode(attr)
		);

		housingToken.transfer(caller, rewardShares.userValue);

		return (attr, rewardShares, newNonce);
	}

	/// @notice Returns the maximum supply of the HousingSFT token.
	/// @return The maximum supply of the HousingSFT token.
	function getMaxSupply() external view returns (uint256) {
		return projectSFT.getMaxSupply();
	}

	/// @notice Calculates the amount of rent claimable for a given token.
	/// @param attr The attributes of the token.
	/// @return The amount of rent claimable.
	function rentClaimable(
		HousingAttributes memory attr
	) public view returns (uint256) {
		return _computeRewardShares(attr).userValue;
	}
}
