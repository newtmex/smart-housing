//SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "../modules/SFT.sol";

struct ERC20TokenPayment {
	IERC20 token;
	uint256 amount;
}

struct TokenPayment {
	address token;
	uint256 amount;
	uint256 nonce;
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

	// Receives both SFTs and ERC20, ERC20 have nonce as 0
	function receiveToken(
		TokenPayment memory payment,
		address from
	) internal {
		if (payment.nonce == 0) {
			IERC20(payment.token).transferFrom(
				from,
				address(this),
				payment.amount
			);
		} else {
			SFT(payment.token).safeTransferFrom(
				from,
				address(this),
				payment.nonce,
				payment.amount,
				""
			);
		}
	}
}
