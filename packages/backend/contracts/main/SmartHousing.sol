// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./User.sol";

/// @title SmartHousing
/// @notice SmartHousing leverages blockchain technology to revolutionize real estate investment and development by enabling the tokenization of properties.
/// @dev This contract allows for fractional ownership and ease of investment.
/// This innovative approach addresses the high costs and limited access to real estate investments in Abuja, Nigeria, making the market more inclusive and accessible.
/// By selling tokens, SmartHousing provides developers with immediate access to liquid funds, ensuring the timely and quality completion of affordable development projects.
/// The SmartHousing Contract is the main contract for the SmartHousing ecosystem.
/// This contract owns and deploys HousingProject contracts, which will represent the properties owned and managed by the SmartHousing project.
/// The management of ecosystem users will also be done in this contract.
contract SmartHousing is Ownable, UserModule {
	address public projectFundingAddress;
	address public coinbaseAddress;

	constructor(address conibase, address projectFunding) {
		coinbaseAddress = conibase;
		projectFundingAddress = projectFunding;
	}

	/// @notice Register a new user via proxy or get the referral ID if already registered.
	/// @param userAddr The address of the user.
	/// @param referrerId The ID of the referrer.
	/// @return The ID of the registered user.
	function createRefIDViaProxy(
		address userAddr,
		uint256 referrerId
	) external onlyProjectFunding returns (uint256) {
		return _createOrGetUserId(userAddr, referrerId);
	}

	/// @notice Modifier to restrict access to housing project functions.
	modifier onlyProjectFunding() {
		require(
			msg.sender == projectFundingAddress,
			"Caller is not the project funder"
		);
		_;
	}
}
