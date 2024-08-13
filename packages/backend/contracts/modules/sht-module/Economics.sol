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

	/// @notice Computes emission at a specific epoch
	/// @param epoch The epoch to compute emission for
	/// @return Emission value at the given epoch
	function atEpoch(uint256 epoch) internal pure returns (uint256) {
		int256 decayFactor = PRBMathSD59x18.pow(DECAY_RATE, toInt256(epoch));
		return toUint256((E0 * decayFactor) / 1e18);
	}

	/// @notice Computes E0 * (0.9998^epochStart − 0.9998^epochEnd) / ln(0.9998)
	/// @param epochStart the starting epoch
	/// @param epochEnd the end epoch
	/// @return Total emission through the epoch range
	function throughEpochRange(
		uint256 epochStart,
		uint256 epochEnd
	) internal pure returns (uint256) {
		require(epochEnd > epochStart, "Invalid epoch range");

		int256 startFactor = epochDecayFactor(epochStart);
		int256 endFactor = epochDecayFactor(epochEnd);

		int256 totalEmission = (E0 * (startFactor - endFactor)) /
			DECAY_RATE.ln();

		// return the absolute value of totalEmission as uint256
		return toUint256(totalEmission * -1);
	}

	function epochDecayFactor(uint256 epoch) private pure returns (int256) {
		return
			PRBMathSD59x18.pow(
				DECAY_RATE,
				// Extrapolate epoch to size with decimal places of DECAY_RATE
				toInt256(epoch) * 1e18
			);
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

	/// @notice Allocates total value based on predefined ratios.
	/// @param totalValue The total value to be allocated.
	/// @return Allocated values for each category.
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

	/// @notice Computes the total value from individual allocations.
	/// @param value The `Value` struct containing allocations.
	/// @return The total value.
	function total(Value memory value) internal pure returns (uint256) {
		return
			value.team +
			value.protocol +
			value.growth +
			value.staking +
			value.projectsReserve +
			value.lpAndListing;
	}

	/// @notice Adds another `Value` struct to the current one.
	/// @param self The current `Value` struct.
	/// @param rhs The `Value` struct to add.
	function add(Value storage self, Value memory rhs) internal {
		self.team += rhs.team;
		self.protocol += rhs.protocol;
		self.growth += rhs.growth;
		self.staking += rhs.staking;
		self.projectsReserve += rhs.projectsReserve;
		self.lpAndListing += rhs.lpAndListing;
	}
}
