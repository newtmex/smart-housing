// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "prb-math/contracts/PRBMathUD60x18.sol";

library Emission {
	using PRBMathUD60x18 for uint256;

	// TODO check PRBMathUD60x18.SCALE
	uint256 private constant DECAY_RATE = 9998e14; // 0.9998 with 18 decimals
	uint256 private constant E0 = 2729727036845720116116; // initial emission

	function atEpoch(uint256 epoch) internal pure returns (uint256) {
		uint256 decayFactor = PRBMathUD60x18.pow(DECAY_RATE, epoch);
		return E0.mul(decayFactor) / 1e18;
	}

	/// @notice Computes E0 * ​​(0.9998^epochStart − 0.9998^epochEnd​)
	/// @param epochStart the starting epoch
	/// @param epochEnd the end epoch
	function throughEpochRange(
		uint256 epochStart,
		uint256 epochEnd
	) internal pure returns (uint256) {
		require(epochEnd > epochStart, "Invalid epoch range");

		uint256 startFactor = PRBMathUD60x18.pow(DECAY_RATE, epochStart);
		uint256 endFactor = PRBMathUD60x18.pow(DECAY_RATE, epochEnd);

		uint256 totalEmission = E0
			.mul(SafeMath.sub(startFactor, endFactor))
			.div(DECAY_RATE.ln());
		return totalEmission;
	}
}

library Entities {
	using SafeMath for uint256;

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
		uint256 othersTotal = totalValue
			.mul(UNITY - PROTOCOL_DEVELOPMENT_RATIO)
			.div(UNITY);

		uint256 team = othersTotal.mul(TEAM_AND_ADVISORS_RATIO).div(UNITY);
		uint256 growth = othersTotal.mul(GROWTH_RATIO).div(UNITY);
		uint256 staking = othersTotal.mul(STAKING_RATIO).div(UNITY);
		uint256 projectsReserve = othersTotal.mul(PROJECTS_RESERVE_RATIO).div(
			UNITY
		);
		uint256 lpAndListing = othersTotal.mul(LP_AND_LISTINGS_RATIO).div(
			UNITY
		);

		uint256 protocol = totalValue
			.sub(team)
			.sub(growth)
			.sub(staking)
			.sub(projectsReserve)
			.sub(lpAndListing);

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
			value
				.team
				.add(value.protocol)
				.add(value.growth)
				.add(value.staking)
				.add(value.projectsReserve)
				.add(value.lpAndListing);
	}

	function add(Value storage self, Value memory rhs) internal {
		self.team = self.team.add(rhs.team);
		self.protocol = self.protocol.add(rhs.protocol);
		self.growth = self.growth.add(rhs.growth);
		self.staking = self.staking.add(rhs.staking);
		self.projectsReserve = self.projectsReserve.add(rhs.projectsReserve);
		self.lpAndListing = self.lpAndListing.add(rhs.lpAndListing);
	}
}
