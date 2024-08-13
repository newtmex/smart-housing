// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../modules/sht-module/SHTModule.sol";
import "../project-funding/ProjectFunding.sol";

/// @title Coinbase
/// @dev This contract is used to start the ICO for housing projects.
contract Coinbase is Ownable, SHTModule {
	constructor() ERC20("SmartHousingToken", "SHT") {
		_mint(address(this), SHT.MAX_SUPPLY);
	}

	/// @dev Starts the ICO by initializing the first housing project.
	/// @param projectFundingAddr Address of the ProjectFunding contract.
	/// @param smartHousingAddress Address of the SmartHousing contract.
	/// @param fundingToken Address of the funding token (ERC20).
	/// @param fundingGoal The funding goal for the new project.
	/// @param fundingDeadline The deadline for the project funding.
	function startICO(
		string memory name,
		string memory symbol,
		address projectFundingAddr,
		address smartHousingAddress,
		address fundingToken,
		uint256 fundingGoal,
		uint256 fundingDeadline
	) external onlyOwner returns (address) {
		ERC20TokenPayment memory icoPayment = _makeSHTPayment(SHT.ICO_FUNDS);

		// Directly approve the ProjectFunding contract to spend the ICO funds
		_approve(address(this), projectFundingAddr, icoPayment.amount);

		return
			ProjectFunding(projectFundingAddr).initFirstProject(
				icoPayment,
				name,
				symbol,
				smartHousingAddress,
				fundingToken,
				fundingGoal,
				fundingDeadline
			);
	}

	/// @dev Dispatches ecosystem funds if not already dispatched to SmartHousing contract.
	/// @param smartHousingAddr The address of the SmartHousing contract.
	function feedSmartHousing(address smartHousingAddr) external onlyOwner {
		uint256 feedAmount = SHT.ECOSYSTEM_DISTRIBUTION_FUNDS;
		require(balanceOf(address(this)) >= feedAmount, "Already dispatched");

		ERC20TokenPayment memory feedPayment = _makeSHTPayment(feedAmount);

		// Directly approve the SmartHousing contract to spend the ecosystem funds
		_approve(address(this), smartHousingAddr, feedAmount);

		ISmartHousing(smartHousingAddr).setUpSHT(feedPayment);
	}
}
