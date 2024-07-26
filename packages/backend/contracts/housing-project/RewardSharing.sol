// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;

import "./HousingSFT.sol";

uint256 constant DIVISION_SAFETY_CONST = 1_000_000_000_000_000_000;

struct rewardshares {
	uint256 userValue;
	uint256 referrerValue;
}

library RewardShares {
	function total(rewardshares memory self) internal pure returns (uint256) {
		return self.userValue + self.referrerValue;
	}
}

function splitReward(uint256 reward) pure returns (rewardshares memory) {
	uint256 referrerValue = (reward * 6_66) / 100_00; // would amount to approximately 5% of grand total
	uint256 userValue = reward - referrerValue;

	return rewardshares(userValue, referrerValue);
}

function computeReward(
	HousingAttributes memory attr,
	uint256 contractRPS
) pure returns (uint256) {
	if (contractRPS <= attr.rewardsPerShare) {
		return 0;
	}

	return
		((contractRPS - attr.rewardsPerShare) * attr.tokenWeight) /
		DIVISION_SAFETY_CONST;
}
