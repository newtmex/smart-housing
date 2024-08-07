// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../lib/LkSHTAttributes.sol";
import "../lib/TokenPayments.sol";
import "../modules/SFT.sol";

library NewLkSHT {
	function create() external returns (LkSHT) {
		return new LkSHT("Locked Housing Token","LkSHT");
	}
}

/**
 * @title LockedSmartHousingToken
 * @dev SFT token that locks SmartHousing Tokens (SHT) during ICO.
 * Allows transfers only to whitelisted addresses.
 */
contract LkSHT is SFT {
	using SafeMath for uint256;
	using TokenPayments for ERC20TokenPayment;

	uint256 immutable startTimestamp = block.timestamp;

	constructor(
		string memory name_,
		string memory symbol_
	) SFT(name_, symbol_) {}

	event TokensMinted(address indexed to, uint256 amount);

	/**
	 * @dev Mints new Locked SmartHousing Tokens (LkSHT) by locking SHT.
	 * @param amount The amount of SHT to lock.
	 * @param to The address to mint the tokens to.
	 */
	function mint(uint256 amount, address to) external onlyOwner {
		bytes memory attributes = abi.encode(
			LkSHTAttributes.newAttributes(startTimestamp, amount)
		);

		super._mint(to, amount, attributes, "LockedSmartHousingToken");

		emit TokensMinted(to, amount);
	}
}
