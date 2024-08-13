// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "./Interface.sol";

abstract contract UserModule is IUserModule {
	struct ReferralInfo {
		uint256 id;
		address referralAddress;
	}

	struct User {
		uint256 id;
		address addr;
		uint256 referrerId;
		uint256[] referrals;
	}

	uint256 public userCount;
	mapping(address => User) public users;
	mapping(uint256 => address) public userIdToAddress;

	event UserRegistered(
		uint256 userId,
		address userAddress,
		uint256 referrerId
	);
	event ReferralAdded(uint256 referrerId, uint256 referralId);

	/// @notice Register a new user or get the referral ID if already registered.
	/// @param referrerId The ID of the referrer.
	/// @return The ID of the registered user.
	function createRefID(uint256 referrerId) external returns (uint256) {
		address userAddr = msg.sender;
		return _createOrGetUserId(userAddr, referrerId);
	}

	/// @notice Gets the referrer and referrer ID of a user.
	/// @param userAddress The address of the user.
	/// @return referrerId The ID of the referrer, 0 if none.
	/// @return referrerAddress The address of the referrer, address(0) if none.
	function getReferrer(
		address userAddress
	) public view returns (uint256 referrerId, address referrerAddress) {
		User storage user = users[userAddress];
		referrerId = user.referrerId;
		referrerAddress = userIdToAddress[referrerId];
	}

	/// @notice Gets the user ID for a given address.
	/// @param userAddress The address of the user.
	/// @return userId The ID of the user.
	function getUserId(
		address userAddress
	) external view returns (uint256 userId) {
		return users[userAddress].id;
	}

	/// @notice Retrieves the referrals of a user.
	/// @param userAddress The address of the user.
	/// @return referrals An array of `ReferralInfo` structs representing the user's referrals.
	function getReferrals(
		address userAddress
	) external view returns (ReferralInfo[] memory) {
		uint256[] memory referralIds = users[userAddress].referrals;
		ReferralInfo[] memory referrals = new ReferralInfo[](
			referralIds.length
		);

		for (uint256 i = 0; i < referralIds.length; i++) {
			uint256 id = referralIds[i];
			address refAddr = userIdToAddress[id];
			referrals[i] = ReferralInfo({ id: id, referralAddress: refAddr });
		}

		return referrals;
	}

	/// @notice Internal function to create or get the user ID.
	/// @param userAddr The address of the user.
	/// @param referrerId The ID of the referrer.
	/// @return The ID of the user.
	function _createOrGetUserId(
		address userAddr,
		uint256 referrerId
	) internal returns (uint256) {
		User storage user = users[userAddr];

		// If user already exists, return the existing ID
		if (user.id != 0) {
			return user.id;
		}

		// Increment user count and assign new user ID
		userCount++;
		users[userAddr] = User({
			id: userCount,
			addr: userAddr,
			referrerId: referrerId,
			referrals: new uint256[](0)
		});
		userIdToAddress[userCount] = userAddr;

		// Add user to referrer's referrals list, if applicable
		if (
			referrerId != 0 &&
			referrerId != userCount &&
			userIdToAddress[referrerId] != address(0)
		) {
			users[userIdToAddress[referrerId]].referrals.push(userCount);
			emit ReferralAdded(referrerId, userCount);
		}

		emit UserRegistered(userCount, userAddr, referrerId);
		return userCount;
	}
}
