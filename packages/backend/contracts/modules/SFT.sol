// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title SFT Contract
 * @dev Semi-Fungible Token (SFT) contract that extends ERC1155. This contract allows minting, updating, and
 *      managing tokens with attributes. It also tracks token ownership and provides methods for querying
 *      token information and balances.
 *
 * The contract uses:
 * - `Counters` for incrementing and managing nonces.
 * - `EnumerableSet` for tracking nonces owned by addresses.
 */
contract SFT is ERC1155, Ownable {
	using Counters for Counters.Counter;
	using EnumerableSet for EnumerableSet.UintSet;

	/**
	 * @dev Struct representing the balance of an SFT with its attributes.
	 * @param nonce The unique identifier for the token.
	 * @param amount The amount of tokens held.
	 * @param attributes The token's attributes as a bytes array.
	 */
	struct SftBalance {
		uint256 nonce;
		uint256 amount;
		bytes attributes;
	}

	Counters.Counter private _nonceCounter;
	string private _name;
	string private _symbol;

	// Mapping from nonce to token attributes as bytes
	mapping(uint256 => bytes) private _tokenAttributes;

	// Mapping from address to list of owned token nonces
	mapping(address => EnumerableSet.UintSet) private _addressToNonces;

	/**
	 * @dev Constructor to initialize the SFT contract with a name and symbol.
	 * @param name_ The name of the token.
	 * @param symbol_ The symbol of the token.
	 */
	constructor(string memory name_, string memory symbol_) ERC1155("") {
		_name = name_;
		_symbol = symbol_;
	}

	/**
	 * @notice Internal function to mint new tokens with attributes and store the nonce.
	 * @param to The address to receive the minted tokens.
	 * @param amount The amount of tokens to mint.
	 * @param attributes The attributes of the minted tokens.
	 * @return nonce The unique identifier (nonce) of the newly minted tokens.
	 */
	function _mint(
		address to,
		uint256 amount,
		bytes memory attributes
	) internal returns (uint256 nonce) {
		_nonceCounter.increment();
		nonce = _nonceCounter.current();

		// Store the attributes
		_tokenAttributes[nonce] = attributes;

		// Mint the token with the nonce as its ID
		super._mint(to, nonce, amount, "");

		// Track the nonce for the address
		_addressToNonces[to].add(nonce);
	}

	/**
	 * @notice Returns the name of the token.
	 * @return The name of the token.
	 */
	function name() public view returns (string memory) {
		return _name;
	}

	/**
	 * @notice Returns the symbol of the token.
	 * @return The symbol of the token.
	 */
	function symbol() public view returns (string memory) {
		return _symbol;
	}

	/**
	 * @notice Returns the token name and symbol.
	 * @return name The name of the token.
	 * @return symbol The symbol of the token.
	 */
	function tokenInfo() public view returns (string memory, string memory) {
		return (_name, _symbol);
	}

	/**
	 * @notice Returns raw token attributes by nonce.
	 * @param nonce The nonce of the token.
	 * @return Attributes in bytes.
	 */
	function _getRawTokenAttributes(
		uint256 nonce
	) internal view returns (bytes memory) {
		return _tokenAttributes[nonce];
	}

	/**
	 * @notice Returns the list of nonces owned by an address.
	 * @param owner The address of the token owner.
	 * @return Array of nonces.
	 */
	function getNonces(address owner) public view returns (uint256[] memory) {
		return _addressToNonces[owner].values();
	}

	/**
	 * @notice Checks if the address owns a specific nonce.
	 * @param owner The address of the token owner.
	 * @param nonce The nonce to check.
	 * @return True if the address owns the nonce, otherwise false.
	 */
	function hasSFT(address owner, uint256 nonce) public view returns (bool) {
		return _addressToNonces[owner].contains(nonce);
	}

	/**
	 * @notice Burns the tokens of a specific nonce and mints new tokens with updated attributes.
	 * @param user The address of the token holder.
	 * @param nonce The nonce of the token to update.
	 * @param amount The amount of tokens to mint.
	 * @param attr The new attributes to assign.
	 * @return The new nonce for the minted tokens.
	 */
	function update(
		address user,
		uint256 nonce,
		uint256 amount,
		bytes memory attr
	) external onlyOwner returns (uint256) {
		_burn(user, nonce, amount);
		return amount > 0 ? _mint(user, amount, attr) : 0;
	}

	/**
	 * @notice Returns the balance of the user with their token attributes.
	 * @param user The address of the user.
	 * @return Array of SftBalance containing nonce, amount, and attributes.
	 */
	function _sftBalance(
		address user
	) internal view returns (SftBalance[] memory) {
		uint256[] memory nonces = getNonces(user);
		SftBalance[] memory balance = new SftBalance[](nonces.length);

		for (uint256 i; i < nonces.length; i++) {
			uint256 nonce = nonces[i];
			bytes memory attributes = _tokenAttributes[nonce];
			uint256 amount = balanceOf(user, nonce);

			balance[i] = SftBalance({
				nonce: nonce,
				amount: amount,
				attributes: attributes
			});
		}

		return balance;
	}

	/**
	 * @notice Override _beforeTokenTransfer to handle address-to-nonce mapping.
	 * @param operator The address performing the transfer.
	 * @param from The address sending tokens.
	 * @param to The address receiving tokens.
	 * @param ids The token IDs being transferred.
	 * @param amounts The amounts of tokens being transferred.
	 * @param data Additional data.
	 * @dev Updates the nonce mappings for the from and to addresses before token transfer.
	 */
	function _beforeTokenTransfer(
		address operator,
		address from,
		address to,
		uint256[] memory ids,
		uint256[] memory amounts,
		bytes memory data
	) internal virtual override {
		super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

		for (uint256 i = 0; i < ids.length; i++) {
			uint256 id = ids[i];

			_addressToNonces[from].remove(id);
			_addressToNonces[to].add(id);
		}
	}
}
