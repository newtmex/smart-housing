// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "../main/Interface.sol";

abstract contract CallsSmartHousing {
	/// @notice The address of the main SmartHousing contract.
	address public immutable smartHousingAddr;

	constructor(address smartHousingAddr_) {
		smartHousingAddr = smartHousingAddr_;
	}

	/// @dev Gets the referrer address for a given original owner.
	/// @param userAddr The original owner of the token.
	/// @return The referrer address.
	function _getReferrer(
		address userAddr
	) internal view returns (uint256, address) {
		return IUserModule(smartHousingAddr).getReferrer(userAddr);
	}
}
