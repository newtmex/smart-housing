// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title Epochs and Periods Management Library
/// @notice This library provides functions to manage and calculate epochs and periods based on a genesis timestamp and an epoch length.
/// @dev The epoch length is specified in hours, and the period is calculated as 30 epochs.
library EpochsAndPeriods {
	struct Storage {
		uint256 genesis;
		uint256 epochLength;
	}

	/// @notice Initializes the storage with the current timestamp as the genesis and sets the epoch length.
	/// @param self The storage struct to initialize.
	/// @param _epochLength The length of an epoch in hours. This determines how long each epoch lasts.
	/// @dev This function should be called in the contract constructor to set the initial genesis timestamp and epoch length.
	function initialize(Storage storage self, uint256 _epochLength) internal {
		self.genesis = block.timestamp;
		self.epochLength = _epochLength;
	}

	/// @notice Returns the current epoch based on the genesis timestamp and epoch length.
	/// @param self The storage struct containing the genesis timestamp and epoch length.
	/// @return The current epoch number.
	/// @dev The epoch is calculated by dividing the time elapsed since genesis by the epoch length in seconds.
	function currentEpoch(
		Storage storage self
	) internal view returns (uint256) {
		require(self.genesis > 0, "Invalid genesis timestamp");
		return (block.timestamp - self.genesis) / (self.epochLength * 60 * 60);
	}

	/// @notice Returns the current period based on the current epoch.
	/// @param self The storage struct containing the genesis timestamp and epoch length.
	/// @return The current period number.
	/// @dev The period is calculated by dividing the current epoch by 30.
	function currentPeriod(
		Storage storage self
	) internal view returns (uint256) {
		return currentEpoch(self) / 30;
	}
}
