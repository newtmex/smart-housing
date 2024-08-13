// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../coinbase/Coinbase.sol";
import "./MintableERC20.sol";

contract CoinbaseMock is Coinbase {
	function mint(address to, uint256 amt) external onlyOwner {
		_mint(to, amt);
	}
}
