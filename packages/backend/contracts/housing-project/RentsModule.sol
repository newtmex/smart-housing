// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "./HousingSFT.sol";
import "./RewardSharing.sol";
import "../lib/TokenPayments.sol";
import "./CallsSmartHousing.sol";

/// @title Rents Module
/// @notice Handles rent payments, reward calculations, and distribution for Housing projects.
/// @dev This abstract contract should be inherited by the HousingProject contract.
abstract contract RentsModule is CallsSmartHousing {
	using TokenPayments for ERC20TokenPayment;
	using RewardShares for rewardshares;

	uint256 public rewardPerShare;
	uint256 public rewardsReserve;
	uint256 public facilityManagementFunds;

	ERC20Burnable public housingToken;
	HousingSFT public projectSFT;

	uint256 private constant REWARD_PERCENT = 75;
	uint256 private constant ECOSYSTEM_PERCENT = 18;
	uint256 private constant FACILITY_PERCENT = 7;

	/// @notice Receives rent payments and distributes rewards.
	/// @param rentPayment The details of the rent payment.
	function receiveRent(ERC20TokenPayment calldata rentPayment) external {
		uint256 rentAmount = rentPayment.amount;
		require(rentAmount > 0, "RentsModule: Insufficient rent amount");
		require(
			rentPayment.token == housingToken,
			"RentsModule: Invalid rent payment token"
		);

		rentPayment.receiveERC20();

		uint256 rentReward = (rentAmount * REWARD_PERCENT) / 100;
		uint256 ecosystemReward = (rentAmount * ECOSYSTEM_PERCENT) / 100;
		uint256 facilityReward = (rentAmount * FACILITY_PERCENT) / 100;

		rewardPerShare +=
			(rentReward * DIVISION_SAFETY_CONST) /
			projectSFT.getMaxSupply();
		rewardsReserve += rentReward;
		facilityManagementFunds += facilityReward;

		housingToken.burn(ecosystemReward);
		ISmartHousing(smartHousingAddr).addProjectRent(rentAmount);
	}

	/// @notice Claims rent rewards for a given token.
	/// @return attr The updated HousingAttributes.
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
		rewardShares = computeRewardShares(attr);

		uint256 totalReward = rewardShares.total();
		if (totalReward == 0) {
			return (attr, rewardShares, nonce);
		}

		require(rewardsReserve >= totalReward, "Computed rewards too large");
		rewardsReserve -= totalReward;

		(, address referrer) = getReferrer(attr.originalOwner);
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
