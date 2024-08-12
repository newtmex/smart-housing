// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "prb-math/contracts/PRBMathSD59x18.sol";

/// @notice Emitted when trying to convert a uint256 number that doesn't fit within int256.
error ToInt256CastOverflow(uint256 number);

/// @notice Emitted when trying to convert a int256 number that doesn't fit within uint256.
error ToUint256CastOverflow(int256 number);

/// @notice Safe cast from uint256 to int256
function toInt256(uint256 x) pure returns (int256 result) {
	if (x > uint256(type(int256).max)) {
		revert ToInt256CastOverflow(x);
	}
	result = int256(x);
}

/// @notice Safe cast from int256 to uint256
function toUint256(int256 x) pure returns (uint256 result) {
	if (x < 0) {
		revert ToUint256CastOverflow(x);
	}
	result = uint256(x);
}

/// @dev see https://github.com/PaulRBerg/prb-math/discussions/50
library Emission {
	using PRBMathSD59x18 for int256;

	int256 private constant DECAY_RATE = 9998e14; // 0.9998 with 18 decimals
	int256 private constant E0 = 2729727036845720116116; // initial emission

	function atEpoch(uint256 epoch) internal pure returns (uint256) {
		int256 decayFactor = PRBMathSD59x18.pow(DECAY_RATE, toInt256(epoch));
		return toUint256((E0 * decayFactor) / 1e18);
	}

	/// @notice Computes E0 * ​​(0.9998^epochStart − 0.9998^epochEnd​)
	/// @param epochStart the starting epoch
	/// @param epochEnd the end epoch
	function throughEpochRange(
		uint256 epochStart,
		uint256 epochEnd
	) internal pure returns (uint256) {
		require(epochEnd > epochStart, "Invalid epoch range");

		int256 startFactor = PRBMathSD59x18.pow(
			DECAY_RATE,
			toInt256(epochStart)
		);
		int256 endFactor = PRBMathSD59x18.pow(DECAY_RATE, toInt256(epochEnd));

		int256 totalEmission = (E0 * (endFactor - startFactor)) /
			DECAY_RATE.ln();

		return toUint256(totalEmission);
	}
}

library Entities {
	uint32 public constant UNITY = 100_00;

	uint32 public constant TEAM_AND_ADVISORS_RATIO = 23_05;
	uint32 public constant PROTOCOL_DEVELOPMENT_RATIO = 30_05;
	uint32 public constant GROWTH_RATIO = 15_35;
	uint32 public constant STAKING_RATIO = 16_55;
	uint32 public constant PROJECTS_RESERVE_RATIO = 8_00;
	uint32 public constant LP_AND_LISTINGS_RATIO = 7_00;

	struct Value {
		uint256 team;
		uint256 protocol;
		uint256 growth;
		uint256 staking;
		uint256 projectsReserve;
		uint256 lpAndListing;
	}

	function fromTotalValue(
		uint256 totalValue
	) internal pure returns (Value memory) {
		uint256 othersTotal = (totalValue *
			(UNITY - PROTOCOL_DEVELOPMENT_RATIO)) / UNITY;

		uint256 team = (othersTotal * TEAM_AND_ADVISORS_RATIO) / UNITY;
		uint256 growth = (othersTotal * GROWTH_RATIO) / UNITY;
		uint256 staking = (othersTotal * STAKING_RATIO) / UNITY;
		uint256 projectsReserve = (othersTotal * PROJECTS_RESERVE_RATIO) /
			UNITY;
		uint256 lpAndListing = (othersTotal * LP_AND_LISTINGS_RATIO) / UNITY;

		uint256 protocol = totalValue -
			(team + growth + staking + projectsReserve + lpAndListing);

		return
			Value({
				team: team,
				protocol: protocol,
				growth: growth,
				staking: staking,
				projectsReserve: projectsReserve,
				lpAndListing: lpAndListing
			});
	}

	function total(Value memory value) internal pure returns (uint256) {
		return
			value.team +
			value.protocol +
			value.growth +
			value.staking +
			value.projectsReserve +
			value.lpAndListing;
	}

	function add(Value storage self, Value memory rhs) internal {
		self.team += rhs.team;
		self.protocol += rhs.protocol;
		self.growth += rhs.growth;
		self.staking += rhs.staking;
		self.projectsReserve += rhs.projectsReserve;
		self.lpAndListing += rhs.lpAndListing;
	}
}
