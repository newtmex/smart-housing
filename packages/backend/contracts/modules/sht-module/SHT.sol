// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

library SHT {
	uint256 public constant DECIMALS = 18;
	uint256 public constant ONE = 10 ** DECIMALS;
	uint256 public constant MAX_SUPPLY = 21_000_000 * ONE;
	uint256 public constant ECOSYSTEM_DISTRIBUTION_FUNDS =
		(13_650_000 * ONE) + 2_248_573_618_499_339;
	uint256 public constant ICO_FUNDS =
		MAX_SUPPLY - ECOSYSTEM_DISTRIBUTION_FUNDS;
}
