// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../../lib/EpochsAndPeriods.sol";

library Distribution {
	using EpochsAndPeriods for EpochsAndPeriods.Storage;

	struct Storage {
		uint256 totalFunds;
		uint256 genesisEpoch;
	}

	/// @notice Sets the total funds and the genesis epoch. This can only be done once.
	/// @param self The storage struct to set the total funds and genesis epoch.
	/// @param amount The amount of total funds to set.
	/// @param epochsAndPeriods The storage struct for epoch and period management.
	function setTotalFunds(
		Storage storage self,
		EpochsAndPeriods.Storage storage epochsAndPeriods,
		uint256 amount
	) internal {
		require(self.totalFunds == 0, "Total funds already set");
		self.totalFunds = amount;
		self.genesisEpoch = epochsAndPeriods.currentEpoch();
	}

	/// @notice Returns the total funds.
	/// @param self The storage struct containing the total funds.
	/// @return The total funds.
	function getTotalFunds(
		Storage storage self
	) internal view returns (uint256) {
		return self.totalFunds;
	}

	/// @notice Returns the genesis epoch when the total funds were set.
	/// @param self The storage struct containing the genesis epoch.
	/// @return The genesis epoch.
	function getGenesisEpoch(
		Storage storage self
	) internal view returns (uint256) {
		return self.genesisEpoch;
	}
}
