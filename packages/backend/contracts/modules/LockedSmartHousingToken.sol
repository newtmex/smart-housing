// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../lib/LkSHTAttributes.sol";
import "../lib/TokenPayments.sol";
import "../modules/SFT.sol";

library NewLkSHT {
	function create() external returns (LkSHT) {
		return new LkSHT("Locked Housing Token", "LkSHT");
	}
}

/// @title LockedSmartHousingToken
/// @dev SFT token that locks SmartHousing Tokens (SHT) during ICO.
/// Allows transfers only to whitelisted addresses.
contract LkSHT is SFT {
	using SafeMath for uint256;
	using TokenPayments for ERC20TokenPayment;

	struct LkSHTBalance {
		uint256 nonce;
		uint256 amount;
		LkSHTAttributes.Attributes attributes;
	}

	/// @dev Record the block timestamp when the contract is deployed
	uint256 immutable startTimestamp = block.timestamp;

	/// @dev Constructor to initialize the token with name and symbol
	constructor(
		string memory name_,
		string memory symbol_
	) SFT(name_, symbol_) {}

	/// @dev Event emitted when tokens are minted
	event TokensMinted(address indexed to, uint256 amount);

	/// @dev Returns the balance of the user along with attributes
	/// @param user The address of the user.
	/// @return Array of LkSHTBalance containing nonce, amount, and attributes
	function sftBalance(
		address user
	) public view returns (LkSHTBalance[] memory) {
		SftBalance[] memory _sftBals = _sftBalance(user);
		LkSHTBalance[] memory balance = new LkSHTBalance[](_sftBals.length);

		for (uint256 i; i < _sftBals.length; i++) {
			SftBalance memory _sftBal = _sftBals[i];

			balance[i] = LkSHTBalance({
				nonce: _sftBal.nonce,
				amount: _sftBal.amount,
				attributes: abi.decode(
					_sftBal.attributes,
					(LkSHTAttributes.Attributes)
				)
			});
		}

		return balance;
	}

	/// @dev Mints new Locked SmartHousing Tokens (LkSHT) by locking SHT.
	/// @param amount The amount of SHT to lock.
	/// @param to The address to mint the tokens to.
	function mint(uint256 amount, address to) external onlyOwner {
		require(amount > 0, "Amount must be greater than 0");

		bytes memory attributes = abi.encode(
			LkSHTAttributes.newAttributes(startTimestamp, amount)
		);

		super._mint(to, amount, attributes);

		emit TokensMinted(to, amount);
	}

	function getAttribute(
		uint256 nonce
	) external view returns (LkSHTAttributes.Attributes memory) {
		return
			abi.decode(
				_getRawTokenAttributes(nonce),
				(LkSHTAttributes.Attributes)
			);
	}
}
