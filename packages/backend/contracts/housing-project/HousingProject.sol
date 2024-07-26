// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;

import "./HousingSFT.sol";

/// # HousingProject Contract Template
///
/// The `HousingProject` contract template serves as the foundational blueprint for deploying
/// individual real estate projects within the SamrtHousing ecosystem.
/// Each `HousingProject` contract represents a unique real estate development,
/// managing its ownership, revenue distribution, and participant interactions.
contract HousingProject is HousingSFT {
	// This is the address to the main SmartHousing contract
	// that will housing other logic like user and referral system management,
	// and distribution of rewards
	address immutable smartHousingAddr;

	constructor(
		address smartHousingAddr_,
		string memory uri,
		uint256 amountRaised,
		string memory name
	) HousingSFT(uri, name, amountRaised) {
		smartHousingAddr = smartHousingAddr_;
	}
}
