// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "../lib/TokenPayments.sol";

interface ISmartHousing {
	function addProjectRent(uint256 amount) external;

	function createRefIDViaProxy(
		address userAddr,
		uint256 referrerId
	) external returns (uint256);

	function addProject(address projectAddress) external;

	function setUpSHT(ERC20TokenPayment calldata payment) external;
}

interface IUserModule {
	function getReferrer(address user) external view returns (uint, address);
}
