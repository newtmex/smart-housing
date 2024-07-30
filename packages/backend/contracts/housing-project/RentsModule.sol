// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "./HousingSFT.sol";
import "./RewardSharing.sol";
import "../lib/TokenPayments.sol";
import "./CallsSmartHousing.sol";

/// @title Rents Module
/// @notice Handles rent payments, reward calculations, and distribution for Housing projects.
/// @dev This abstract contract should be inherited by the HousingProject contract.
abstract contract RentsModule is HousingSFT, CallsSmartHousing {
	using TokenPayments for ERC20TokenPayment;
	using RewardShares for rewardshares;

	uint256 public rewardPerShare;
	uint256 public rewardsReserve;
	uint256 public facilityManagementFunds;

	ERC20Burnable housingToken;

	/// @notice Receives rent payments and distributes rewards.
	/// @param rentPayment The details of the rent payment.
	function receiveRent(ERC20TokenPayment calldata rentPayment) external {
		// TODO set the appropriate rent per Project
		require(
			rentPayment.amount > 0,
			"RentsModule: Insufficient rent amount"
		);
		require(
			rentPayment.token == housingToken,
			"RentsModule: Invalid rent payment token"
		);
		rentPayment.receiveERC20();

		uint256 rentReward = (rentPayment.amount * 75) / 100;
		uint256 ecosystemReward = (rentPayment.amount * 18) / 100;
		uint256 facilityReward = (rentPayment.amount * 7) / 100;

		uint256 allShares = MAX_SUPPLY;
		uint256 rpsIncrease = (rentReward * DIVISION_SAFETY_CONST) / allShares;

		rewardPerShare += rpsIncrease;
		rewardsReserve += rentReward;
		facilityManagementFunds += facilityReward;

		housingToken.burn(ecosystemReward);
		SmartHousing(smartHousingAddr).addProjectRent(rentPayment.amount);
	}

	/// @notice Claims rent rewards for a given token.
	/// @return The updated HousingAttributes.
	function claimRentReward() external returns (HousingAttributes memory) {
		address caller = msg.sender;
		uint256 currentRPS = rewardPerShare;

		HousingAttributes memory attr = getUserSFT(caller);
		rewardshares memory rewardShares = computeRewardShares(attr);
		uint256 totalReward = rewardShares.total();

		if (totalReward == 0) {
			// Fail silently
			return attr;
		}

		require(rewardsReserve >= totalReward, "Computed rewards too large");

		rewardsReserve -= totalReward;

		// We use original owner since we are certain they are registered
		(, address referrer) = getReferrer(attr.originalOwner);
		if (rewardShares.referrerValue > 0) {
			if (referrer != address(0)) {
				housingToken.transfer(referrer, rewardShares.referrerValue); // Send to referrer
			} else {
				housingToken.burn(rewardShares.referrerValue); // Burn to add to ecosystem reward
			}
		}

		attr.rewardsPerShare = currentRPS;
		housingAttributes[caller] = attr;

		housingToken.transfer(caller, rewardShares.userValue); // Send to user

		return attr;
	}

	/// @notice Computes the amount of rent claimable for a given token.
	/// @param attr The attributes of the token.
	/// @return The amount of rent claimable.
	function rentClaimable(
		HousingAttributes memory attr
	) public view returns (uint256) {
		return computeRewardShares(attr).userValue;
	}

	/// @dev Computes the reward shares for a given token.
	/// @param attr The attributes of the token.
	/// @return The computed RewardShares.
	function computeRewardShares(
		HousingAttributes memory attr
	) internal view returns (rewardshares memory) {
		uint256 currentRPS = rewardPerShare;

		if (currentRPS == 0 || attr.rewardsPerShare >= currentRPS) {
			return rewardshares({ userValue: 0, referrerValue: 0 });
		}

		uint256 reward = computeReward(attr, currentRPS);

		return splitReward(reward);
	}
}
