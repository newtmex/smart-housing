// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../lib/LkSHTAttributes.sol";
import "../lib/TokenPayments.sol";

/**
 * @title LockedSmartHousingToken
 * @dev ERC1155 token that locks SmartHousing Tokens (SHT) during ICO.
 * Allows transfers only to whitelisted addresses.
 */
abstract contract LockedSmartHousingToken is ERC1155, Ownable {
	using SafeMath for uint256;
	using TokenPayments for ERC20TokenPayment;

	IERC20 public smartHousingToken; // SmartHousing Token (SHT)
	uint256 public startTimestamp;
	mapping(address => bool) public whitelist; // Whitelisted addresses

	// Token ID for the LkSHT token
	uint256 public constant LOCKED_SHT_ID = 1;
	mapping(address => LkSHTAttributes.Attributes) public tokenAttributes;

	event TokensMinted(address indexed to, uint256 amount);
	event WhitelistUpdated(address indexed account, bool status);

	constructor() ERC1155("") {}

	/**
	 * @dev Mints new Locked SmartHousing Tokens (LkSHT) by locking SHT.
	 * @param amount The amount of SHT to lock.
	 * @param to The address to mint the tokens to.
	 */
	function _mint(uint256 amount, address to) internal {
		LkSHTAttributes.Attributes memory attributes = LkSHTAttributes
			.newAttributes(startTimestamp, amount);

		// Merge attributes if there were existing attributes
		if (tokenAttributes[to].startTimestamp != 0) {
			// TODO implment this using weights
		}
		tokenAttributes[to] = attributes;

		super._mint(to, LOCKED_SHT_ID, amount, "LockedSmartHousingToken");

		emit TokensMinted(to, amount);
	}

	/**
	 * @dev Allows the owner to update the whitelist.
	 * @param account The address to update.
	 * @param status The whitelist status.
	 */
	function updateWhitelist(address account, bool status) external onlyOwner {
		whitelist[account] = status;
		emit WhitelistUpdated(account, status);
	}

	/**
	 * @dev Transfers Locked SmartHousing Tokens (LkSHT) if the recipient is whitelisted.
	 * @param from The address to transfer tokens from.
	 * @param to The address to transfer tokens to.
	 * @param id The ID of the token.
	 * @param amount The amount of tokens to transfer.
	 * @param data Additional data.
	 */
	function safeTransferFrom(
		address from,
		address to,
		uint256 id,
		uint256 amount,
		bytes memory data
	) public override {
		require(whitelist[to], "Recipient not whitelisted");
		super.safeTransferFrom(from, to, id, amount, data);
	}
}
