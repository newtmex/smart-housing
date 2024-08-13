// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./HousingSFT.sol";

// Constants
uint256 constant DIVISION_SAFETY_CONST = 1_000_000_000_000_000_000;

// Structs
struct rewardshares {
	uint256 userValue;
	uint256 referrerValue;
}

// Library for managing reward shares
library RewardShares {
	/// @notice Calculates the total reward value (user + referrer).
	/// @param self The rewardshares struct containing user and referrer values.
	/// @return The total reward value.
	function total(rewardshares memory self) internal pure returns (uint256) {
		return self.userValue + self.referrerValue;
	}
}

// Utility functions

/// @notice Splits a reward amount into user and referrer shares.
/// @param reward The total reward amount to be split.
/// @return The rewardshares struct with user and referrer values.
function splitReward(uint256 reward) pure returns (rewardshares memory) {
	uint256 referrerValue = (reward * 666) / 10000; // Approximately 6.66% of the total reward
	uint256 userValue = reward - referrerValue;

	return rewardshares(userValue, referrerValue);
}

/// @notice Computes the reward for a given token based on its attributes and the current reward per share.
/// @param attr The attributes of the token.
/// @param contractRPS The current reward per share.
/// @return The computed reward amount.
function computeReward(
	HousingAttributes memory attr,
	uint256 contractRPS
) pure returns (uint256) {
	// Return 0 if the current reward per share is less than or equal to the token's recorded reward per share
	if (contractRPS <= attr.rewardsPerShare) {
		return 0;
	}

	return
		((contractRPS - attr.rewardsPerShare) * attr.tokenWeight) /
		DIVISION_SAFETY_CONST;
}
