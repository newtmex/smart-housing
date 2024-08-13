// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import { HousingProject } from "./HousingProject.sol";

/// @title NewHousingProject Library
/// @notice This library provides a function to deploy new HousingProject contracts.
/// @dev This is a lightweight library intended for contract creation and can be expanded with additional functionality.
library NewHousingProject {
	/// @notice Deploys a new instance of the HousingProject contract.
	/// @param name The name of the HousingProject token.
	/// @param symbol The symbol of the HousingProject token.
	/// @param coinbase Coinbase contraact address
	/// @param smartHousingAddr The address of the SmartHousing contract that will own the new HousingProject.
	/// @return The address of the newly created HousingProject contract.
	function deployHousingProject(
		string memory name,
		string memory symbol,
		address smartHousingAddr,
		address coinbase
	) external returns (HousingProject) {
		return new HousingProject(name, symbol, smartHousingAddr, coinbase);
	}
}
