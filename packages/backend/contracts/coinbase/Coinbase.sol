// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../modules/sht-module/SHTModule.sol";
import "../project-funding/ProjectFunding.sol";

/**
 * @title Coinbase
 * @dev This contract is used to start the ICO for housing projects.
 */
contract Coinbase is Ownable, SHTModule {
	using SafeMath for uint256;

	constructor() ERC20("SmartHousingToken", "SHT") {
		_mint(address(this), SHT.MAX_SUPPLY);
	}

	/**
	 * @dev Starts the ICO by initializing the first housing project.
	 * @param projectFundingAddr Address of the ProjectFunding contract.
	 * @param smartHousingAddress Address of the SmartHousing contract.
	 * @param fundingToken Address of the funding token (ERC20).
	 * @param fundingGoal The funding goal for the new project.
	 * @param fundingDeadline The deadline for the project funding.
	 */
	function startICO(
		address projectFundingAddr,
		address smartHousingAddress,
		address fundingToken,
		uint256 fundingGoal,
		uint256 fundingDeadline
	) external onlyOwner {
		ERC20TokenPayment memory icoPayment = _makeSHTPayment(SHT.ICO_FUNDS);

		_approve(address(this), projectFundingAddr, icoPayment.amount);

		ProjectFunding(projectFundingAddr).initFirstProject(
			icoPayment,
			smartHousingAddress,
			fundingToken,
			fundingGoal,
			fundingDeadline
		);
	}

	/**
	 * @dev Dispatches ecosystem funds if not already dispatched to SmartHousing contract.
	 * @param smartHousingAddr The address of the SmartHousing contract.
	 */
	function feedSmartHousing(address smartHousingAddr) external onlyOwner {
		ERC20TokenPayment memory feedPayment = _makeSHTPayment(
			SHT.ECOSYSTEM_DISTRIBUTION_FUNDS
		);

		// Ensure data integrity
		require(
			balanceOf(address(this)) >= feedPayment.amount,
			"Already dispatched"
		);

		_approve(address(this), smartHousingAddr, feedPayment.amount);

		ISmartHousing(smartHousingAddr).setUpSHT(feedPayment);
	}
}
