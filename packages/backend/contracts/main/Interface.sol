// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../lib/TokenPayments.sol";

/// @title SmartHousing Interface
/// @notice Interface for interacting with the SmartHousing contract.
interface ISmartHousing {
	/// @notice Adds rent payment to the project.
	/// @param amount The amount of rent to add.
	function addProjectRent(uint256 amount) external;

	/// @notice Creates a referral ID via a proxy.
	/// @param userAddr The address of the user.
	/// @param referrerId The ID of the referrer.
	/// @return The newly created referral ID.
	function createRefIDViaProxy(
		address userAddr,
		uint256 referrerId
	) external returns (uint256);

	/// @notice Adds a new project to the SmartHousing system.
	/// @param projectAddress The address of the new project.
	function addProject(address projectAddress) external;

	/// @notice Sets up the SmartHousingToken (SHT) using the provided payment details.
	/// @param payment The payment details for setting up SHT.
	function setUpSHT(ERC20TokenPayment calldata payment) external;
}

/// @title User Module Interface
/// @notice Interface for interacting with the user module to retrieve referrer information.
interface IUserModule {
	/// @notice Retrieves the referrer information for a given user.
	/// @param user The address of the user.
	/// @return A tuple containing the referrer ID and the referrer address.
	function getReferrer(address user) external view returns (uint256, address);
}
