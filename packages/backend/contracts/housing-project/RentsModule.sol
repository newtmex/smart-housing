// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "./HousingSFT.sol";
import "./RewardSharing.sol";
import "../lib/TokenPayments.sol";

/// @title Rents Module
/// @notice Manages rent payments, reward calculations, and distribution for housing projects.
/// @dev This abstract contract should be inherited by the HousingProject contract.
abstract contract RentsModule {
	// State Variables
	uint256 public rewardPerShare;

	/// @dev Computes the reward shares for a given token based on its attributes.
	/// @param attr The attributes of the token.
	/// @return rewardShares The computed RewardShares.
	function _computeRewardShares(
		HousingAttributes memory attr
	) internal view returns (rewardshares memory) {
		uint256 currentRPS = rewardPerShare;
		if (currentRPS == 0 || attr.rewardsPerShare >= currentRPS) {
			return rewardshares({ userValue: 0, referrerValue: 0 });
		}

		uint256 reward = _computeReward(attr, currentRPS);
		return _splitReward(reward);
	}

	/// @dev Calculates the reward for a given token based on its attributes and current reward per share.
	/// @param attr The attributes of the token.
	/// @param currentRPS The current reward per share.
	/// @return The computed reward.
	function _computeReward(
		HousingAttributes memory attr,
		uint256 currentRPS
	) internal pure returns (uint256) {
		return
			((currentRPS - attr.rewardsPerShare) * attr.tokenWeight) /
			DIVISION_SAFETY_CONST;
	}

	/// @dev Splits the computed reward into user and referrer shares.
	/// @param reward The total computed reward.
	/// @return rewardShares The split reward shares.
	function _splitReward(
		uint256 reward
	) internal pure returns (rewardshares memory) {
		uint256 referrerShare = (reward * 30) / 100_00;
		uint256 userShare = reward - referrerShare;

		return
			rewardshares({
				userValue: userShare,
				referrerValue: referrerShare
			});
	}
}
