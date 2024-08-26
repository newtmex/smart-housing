// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

import "../../lib/TokenPayments.sol";
import "./SHT.sol";

/// @title SHTModule
/// @dev This contract manages the Smart Housing Token (SHT) within the platform.
/// It includes functionalities for making payments in SHT and querying the SHT token ID.
abstract contract SHTModule is ERC20, ERC20Burnable {
	function decimals() public pure override returns (uint8) {
		return uint8(SHT.DECIMALS);
	}

	/// @dev Makes an ERC20TokenPayment struct in SHT for and amount.
	/// @param shtAmount Amount of SHT to be sent.
	/// @return payment ERC20TokenPayment struct representing the payment.
	function _makeSHTPayment(
		uint256 shtAmount
	) internal view returns (ERC20TokenPayment memory) {
		return ERC20TokenPayment(IERC20(address(this)), shtAmount);
	}
}
