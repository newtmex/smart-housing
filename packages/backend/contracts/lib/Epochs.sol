// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title Epochs and Periods Management Library
/// @notice Provides functions to manage and calculate epochs and periods based on a genesis timestamp and epoch length.
/// @dev The epoch length is specified in seconds, and the period is calculated as 30 epochs.
library Epochs {
	// Struct to store epoch management parameters
	struct Storage {
		uint256 genesis; // The genesis timestamp
		uint256 epochLength; // Length of each epoch in seconds
	}

	// Initialization Functions

	/// @notice Initializes the storage with the current timestamp as the genesis and sets the epoch length.
	/// @param self The storage struct to initialize.
	/// @param _epochLength The length of an epoch in seconds.
	/// @dev This function should be called in the contract constructor to set the initial genesis timestamp and epoch length.
	function initialize(Storage storage self, uint256 _epochLength) internal {
		self.genesis = block.timestamp;
		self.epochLength = _epochLength;

		require(self.epochLength > 0, "Invalid Epoch length");
	}

	// View Functions

	/// @notice Returns the current epoch based on the genesis timestamp and epoch length.
	/// @param self The storage struct containing the genesis timestamp and epoch length.
	/// @return The current epoch number.
	/// @dev The epoch is calculated by dividing the time elapsed since genesis by the epoch length in seconds.
	function currentEpoch(
		Storage storage self
	) internal view returns (uint256) {
		return computeEpoch(self, block.timestamp);
	}

	function computeEpoch(
		Storage storage self,
		uint256 timestamp
	) internal view returns (uint256) {
		require(self.genesis > 0, "Invalid genesis timestamp");
		require(timestamp > 0, "Invalid timestamp");
		require(self.epochLength > 0, "Invalid Epoch length");

		return (timestamp - self.genesis) / self.epochLength;
	}

	function epochEdgeTimestamps(
		Storage memory self,
		uint256 epoch
	) internal pure returns (uint256 epochStart, uint256 epochEnd) {
		epochStart = self.genesis + (epoch * self.epochLength);
		epochEnd = epochStart + self.epochLength - 1;
	}
}
