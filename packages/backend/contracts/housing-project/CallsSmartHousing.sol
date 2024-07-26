// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;

import "../main/SmartHousing.sol";

abstract contract CallsSmartHousing {
	/// @notice The address of the main SmartHousing contract.
	address immutable smartHousingAddr;

	constructor(address smartHousingAddr_) {
		smartHousingAddr = smartHousingAddr_;
	}

	/// @dev Gets the referrer address for a given original owner.
	/// @param userAddr The original owner of the token.
	/// @return The referrer address.
	function getReferrer(
		address userAddr
	) internal view returns (uint, address) {
		return SmartHousing(smartHousingAddr).getReferrer(userAddr);
	}
}
