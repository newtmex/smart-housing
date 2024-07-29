// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;

import "./RentsModule.sol";

/// @title HousingProject Contract
/// @notice Represents a unique real estate project within the SmartHousing ecosystem.
/// @dev This contract inherits from RentsModule and HousingSFT.
contract HousingProject is RentsModule {
	/// @notice Initializes the HousingProject contract.
	/// @param smartHousingAddr The address of the main SmartHousing contract.
	constructor(
		address smartHousingAddr
	) CallsSmartHousing(smartHousingAddr) RentsModule() HousingSFT() {}

	event TokenIssued(address tokenAddress, string name, uint256 amountRaised);

	function setTokenDetails(
		string memory name_,
		string memory uri_,
		uint256 amountRaised_,
		address housingTokenAddr
	) external onlyOwner {
		require(
			address(housingToken) == address(0),
			"Token details set already"
		);
		require(amountRaised == 0, "Token details set already");

		housingToken = ERC20Burnable(housingTokenAddr);

		_setURI(uri_);
		amountRaised = amountRaised_;
		name = name_;

		emit TokenIssued(address(this), name, amountRaised);
	}
}
