// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract MintableERC20 is ERC20, Ownable, ERC20Burnable {
	constructor(
		string memory name_,
		string memory symbol_
	) ERC20(name_, symbol_) {}

	function mint(address to, uint256 amt) external onlyOwner {
		_mint(to, amt);
	}
}
