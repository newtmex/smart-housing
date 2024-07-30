// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./User.sol";
import "../lib/TokenPayments.sol";
import "../modules/sht-module/SHT.sol";
import "./distribution/Storage.sol";

/// @title SmartHousing
/// @notice SmartHousing leverages blockchain technology to revolutionize real estate investment and development by enabling the tokenization of properties.
/// @dev This contract allows for fractional ownership and ease of investment.
/// This innovative approach addresses the high costs and limited access to real estate investments in Abuja, Nigeria, making the market more inclusive and accessible.
/// By selling tokens, SmartHousing provides developers with immediate access to liquid funds, ensuring the timely and quality completion of affordable development projects.
/// The SmartHousing Contract is the main contract for the SmartHousing ecosystem.
/// This contract owns and deploys HousingProject contracts, which will represent the properties owned and managed by the SmartHousing project.
/// The management of ecosystem users will also be done in this contract.
contract SmartHousing is Ownable, UserModule {
	using TokenPayments for ERC20TokenPayment;
	using Distribution for Distribution.Storage;
	using EpochsAndPeriods for EpochsAndPeriods.Storage;

	address public projectFundingAddress;
	address public coinbaseAddress;
	address public shtTokenAddress;

	Distribution.Storage public distributionStorage;
	EpochsAndPeriods.Storage public epochsAndPeriodsStorage;

	enum Permissions {
		NONE,
		X_PROJECT
	}

	mapping(address => Permissions) public permissions;

	constructor(address conibase, address projectFunding) {
		coinbaseAddress = conibase;
		projectFundingAddress = projectFunding;

		epochsAndPeriodsStorage.initialize(24); // One epoch will span 24 hours
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

	function setUpSHT(ERC20TokenPayment calldata payment) external {
		require(
			msg.sender == coinbaseAddress,
			"Caller is not the coinbase address"
		);

		// Ensure that the SHT token has not been set already
		require(shtTokenAddress == address(0), "SHT token already set");
		shtTokenAddress = address(payment.token);

		// Verify that the correct amount of SHT has been sent
		require(
			payment.amount == SHT.ECOSYSTEM_DISTRIBUTION_FUNDS,
			"Must send all ecosystem funds"
		);
		payment.accept();

		// Set the total funds in distribution storage
		distributionStorage.setTotalFunds(
			epochsAndPeriodsStorage,
			payment.amount
		);
	}

	/// @notice Adds a new project and sets its permissions.
	/// @param projectAddress The address of the new project.
	function addProject(address projectAddress) external onlyProjectFunding {
		_setPermissions(projectAddress, Permissions.X_PROJECT);
	}

	/// @notice Sets the permissions for a given address.
	/// @param addr The address to set permissions for.
	/// @param perm The permissions to set.
	function _setPermissions(address addr, Permissions perm) internal {
		permissions[addr] = perm;
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
