// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import { SFT } from "../modules/SFT.sol";

// @title ERC20TokenPayment
// @dev Struct to define a payment with ERC20 tokens
struct ERC20TokenPayment {
	IERC20 token; // The ERC20 token contract address
	uint256 amount; // The amount of tokens to be transferred
}

// @title TokenPayment
// @dev Struct to define a payment with different token types including Native tokens
struct TokenPayment {
	address token; // Address of the token contract (0 address for Native tokens)
	uint256 amount; // The amount of tokens to be transferred
	uint256 nonce; // Nonce for SFTs (0 for ERC20)
}

/**
 * @title TokenPayments Library
 * @dev This library provides functions for handling payments in various token types, including ERC20 tokens,
 *      SFT (Semi-Fungible Tokens), and Native tokens (ETH). It includes methods for receiving and transferring
 *      tokens from different sources. The library is designed to handle payments securely and ensure that
 *      the correct amount of tokens is transferred to the contract.
 *
 * The library handles:
 * - ERC20 token payments
 * - SFT (Semi-Fungible Token) payments
 * - Native (ETH) payments
 *
 * Note: ERC20 tokens and SFTs must be approved for transfer before calling these functions.
 */
library TokenPayments {
	/**
	 * @notice Accepts an ERC20TokenPayment and transfers the tokens from the sender
	 * @param self The ERC20TokenPayment struct containing token and amount to transfer
	 * @dev Calls `receiveERC20` with the sender as the source of funds
	 */
	function accept(ERC20TokenPayment calldata self) internal {
		TokenPayments.receiveERC20(self, msg.sender);
	}

	/**
	 * @notice Receives ERC20 tokens from the sender and transfers them to the contract
	 * @param payment The ERC20TokenPayment struct containing token and amount to transfer
	 * @dev Transfers ERC20 tokens from the sender to the contract address
	 */
	function receiveERC20(ERC20TokenPayment calldata payment) internal {
		TokenPayments.receiveERC20(payment, msg.sender);
	}

	/**
	 * @notice Receives ERC20 tokens from a specified address
	 * @param payment The ERC20TokenPayment struct containing token and amount to transfer
	 * @param from The address from which tokens will be transferred
	 * @dev Transfers ERC20 tokens from the given address to the contract address
	 */
	function receiveERC20(
		ERC20TokenPayment calldata payment,
		address from
	) internal {
		payment.token.transferFrom(from, address(this), payment.amount);
	}

	/**
	 * @notice Receives payments of Native tokens, ERC20 tokens, or SFTs
	 * @param payment The TokenPayment struct containing token address, amount, and nonce
	 * @dev Handles Native tokens (ETH), ERC20 tokens, and SFT tokens based on the token address and nonce
	 *      - For Native tokens, ensures the sent amount matches the expected amount
	 *      - For ERC20 tokens, transfers tokens from the specified address
	 *      - For SFT tokens, transfers tokens using the SFT contract
	 */
	function receiveToken(TokenPayment memory payment) internal {
		receiveToken(payment, msg.sender);
	}

	/**
	 * @notice Receives payments of Native tokens, ERC20 tokens, or SFTs from a specified address
	 * @param payment The TokenPayment struct containing token address, amount, and nonce
	 * @param from The address from which tokens will be transferred
	 * @dev Handles Native tokens (ETH), ERC20 tokens, and SFT tokens based on the token address and nonce
	 *      - For Native tokens, ensures the sent amount matches the expected amount and sender is correct
	 *      - For ERC20 tokens, transfers tokens from the given address
	 *      - For SFT tokens, transfers tokens using the SFT contract
	 */
	function receiveToken(TokenPayment memory payment, address from) internal {
		if (payment.token == address(0)) {
			// Handling Native token payment (ETH)
			require(
				payment.amount == msg.value,
				"Expected payment amount must equal the sent amount"
			);
			require(
				from == msg.sender,
				"Can receive native payment only from caller"
			);
			// No additional actions are required as the Ethereum Virtual Machine handles balance movements
		} else if (payment.nonce == 0) {
			// Handling ERC20 token payment
			IERC20(payment.token).transferFrom(
				from,
				address(this),
				payment.amount
			);
		} else {
			// Handling SFT payment
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
