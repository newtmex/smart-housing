// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

interface ISmartHousing {
	function addProjectRent(uint256 amount) external;
}

interface IUserModule {
	function getReferrer(address user) external view returns (uint, address);
}
