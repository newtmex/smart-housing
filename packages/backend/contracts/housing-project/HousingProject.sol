// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;

import "./RentsModule.sol";

/// @title HousingProject Contract
/// @notice Represents a unique real estate project within the SmartHousing ecosystem.
/// @dev This contract inherits from RentsModule and HousingSFT.
contract HousingProject is RentsModule {
	/// @notice The address of the main SmartHousing contract.
	address immutable smartHousingAddr;

	/// @notice Initializes the HousingProject contract.
	/// @param smartHousingAddr_ The address of the main SmartHousing contract.
	/// @param housingTokenAddr The address of the ERC20 token for the SmartHousing ecosystem.
	/// @param uri The base URI for the token.
	/// @param amountRaised The amount raised for the housing project.
	/// @param name The name of the housing project.
	constructor(
		address smartHousingAddr_,
		address housingTokenAddr,
		string memory uri,
		uint256 amountRaised,
		string memory name
	) RentsModule(housingTokenAddr) HousingSFT(uri, name, amountRaised) {
		smartHousingAddr = smartHousingAddr_;
	}
}
