// SPDX-License-Identifier: SEE LICENSE IN LICENSE
pragma solidity 0.8.26;

abstract contract UserModule {
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
	) external view returns (uint256 referrerId, address referrerAddress) {
		User storage user = users[userAddress];
		referrerId = user.referrerId;
		referrerAddress = userIdToAddress[referrerId];
	}

	function getUserId(
		address userAddress
	) external view returns (uint256 userId) {
		return users[userAddress].id;
	}

	/// @notice Internal function to create or get the user ID.
	/// @param userAddr The address of the user.
	/// @param referrerId The ID of the referrer.
	/// @return The ID of the user.
	function _createOrGetUserId(
		address userAddr,
		uint256 referrerId
	) internal returns (uint256) {
		if (users[userAddr].id != 0) {
			return users[userAddr].id;
		}

		userCount++;
		users[userAddr] = User({
			id: userCount,
			addr: userAddr,
			referrerId: referrerId,
			referrals: new uint256[](1)
		});
		userIdToAddress[userCount] = userAddr;

		if (referrerId != 0 && userIdToAddress[referrerId] != address(0)) {
			users[userIdToAddress[referrerId]].referrals.push(userCount);
			emit ReferralAdded(referrerId, userCount);
		}

		emit UserRegistered(userCount, userAddr, referrerId);
		return userCount;
	}
}
