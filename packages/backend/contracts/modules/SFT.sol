// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

abstract contract SFT is ERC1155 {
	using Counters for Counters.Counter;
	using EnumerableSet for EnumerableSet.UintSet;

	Counters.Counter private _nonceCounter;

	// Mapping from nonce to token attributes as bytes
	mapping(uint256 => bytes) private _tokenAttributes;

	// Mapping from address to list of owned token nonces
	mapping(address => EnumerableSet.UintSet) private _addressToNonces;

	constructor() ERC1155("") {}

	// Private function to mint new tokens
	function _mint(
		address to,
		uint256 amount,
		bytes memory attributes,
		bytes memory data
	) internal returns (uint256) {
		_nonceCounter.increment();
		uint256 nonce = _nonceCounter.current();

		// Store the attributes
		_tokenAttributes[nonce] = attributes;

		// Mint the token with the nonce as its ID
		super._mint(to, nonce, amount, data);

		// Track the nonce for the address
		_addressToNonces[to].add(nonce);

		return nonce;
	}

	// Function to get token attributes by nonce
	function getRawTokenAttributes(
		uint256 nonce
	) public view returns (bytes memory) {
		return _tokenAttributes[nonce];
	}

	// Function to get list of nonces owned by an address
	function getNonces(address owner) public view returns (uint256[] memory) {
		return _addressToNonces[owner].values();
	}

	function hasSFT(address owner, uint256 nonce) public view returns (bool) {
		return _addressToNonces[owner].contains(nonce);
	}

	function _setTokenAttributes(uint256 nonce, bytes memory attr) internal {
		_tokenAttributes[nonce] = attr;
	}

	// Override _beforeTokenTransfer to handle address-to-nonce mapping
	function _beforeTokenTransfer(
		address operator,
		address from,
		address to,
		uint256[] memory ids,
		uint256[] memory amounts,
		bytes memory data
	) internal virtual override {
		super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

		if (from != address(0)) {
			for (uint256 i = 0; i < ids.length; i++) {
				_addressToNonces[from].remove(ids[i]);
			}
		}

		if (to != address(0)) {
			for (uint256 i = 0; i < ids.length; i++) {
				_addressToNonces[to].add(ids[i]);
			}
		}
	}
}