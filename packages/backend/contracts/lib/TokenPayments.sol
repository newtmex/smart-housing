//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/interfaces/IERC20.sol";

struct ERC20TokenPayment {
	IERC20 token;
	uint256 amount;
}

library TokenPayments {
	function accept(ERC20TokenPayment calldata self) internal {
		TokenPayments.receiveERC20(self, msg.sender);
	}

	function receiveERC20(ERC20TokenPayment calldata payment) internal {
		TokenPayments.receiveERC20(payment, msg.sender);
	}

	function receiveERC20(
		ERC20TokenPayment calldata payment,
		address from
	) internal {
		payment.token.transferFrom(from, address(this), payment.amount);
	}
}
