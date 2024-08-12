// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RentsModule.sol";

/// @title HousingProject Contract
/// @notice Represents a unique real estate project within the SmartHousing ecosystem.
/// @dev This contract inherits from RentsModule and HousingSFT.
contract HousingProject is RentsModule, Ownable {
	/// @notice Initializes the HousingProject contract.
	/// @param smartHousingAddr The address of the main SmartHousing contract.
	constructor(
		string memory name,
		string memory symbol,
		address smartHousingAddr
	) CallsSmartHousing(smartHousingAddr) {
		projectSFT = new HousingSFT(name, symbol);
	}

	event TokenIssued(address tokenAddress, string name, uint256 amountRaised);

	function setTokenDetails(
		uint256 amountRaised,
		address housingTokenAddr
	) external onlyOwner {
		require(address(housingToken) == address(0), "Token details set already");

		housingToken = ERC20Burnable(housingTokenAddr);

		projectSFT.setAmountRaised(amountRaised);
		string memory name = projectSFT.name();

		emit TokenIssued(address(projectSFT), name, amountRaised);
	}

	function getMaxSupply() public view returns (uint256) {
		return projectSFT.getMaxSupply();
	}
}
