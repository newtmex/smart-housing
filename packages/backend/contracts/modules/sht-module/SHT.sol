// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

/// @title SHT Library
/// @notice Contains constants related to the Smart Housing Token (SHT)
library SHT {
	/// @dev Number of decimal places for the token
	uint256 public constant DECIMALS = 18;

	/// @dev 1 unit of token in its smallest unit, considering DECIMALS
	uint256 public constant ONE = 10 ** DECIMALS;

	/// @dev Maximum supply of the SHT token
	uint256 public constant MAX_SUPPLY = 21_000_000 * ONE;

	/// @dev Funds allocated for ecosystem distribution
	uint256 public constant ECOSYSTEM_DISTRIBUTION_FUNDS =
		(13_650_000 * ONE) + 2_248_573_618_499_339;

	/// @dev Funds allocated for ICO (Initial Coin Offering)
	uint256 public constant ICO_FUNDS =
		MAX_SUPPLY - ECOSYSTEM_DISTRIBUTION_FUNDS;
}
