// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";


 /// @title LkSHTAttributes
 /// @dev Library for handling attributes and unlocking of the Locked SmartHousing Token (LkSHT).
 
library LkSHTAttributes {
	using SafeMath for uint256;

	// Constants
	// Duration for which tokens are locked (e.g., 3 years in production, 3 weeks for testing)
	uint256 constant LOCK_DURATION = 3 weeks;

	// Struct to represent attributes of Locked SmartHousing Tokens
	struct Attributes {
		uint256 initialAmount; // Initial amount of tokens locked
		uint256 amount; // Remaining amount of tokens locked
		uint256 startTimestamp; // Timestamp when the lock started
		uint256 endTimestamp; // Timestamp when the lock ends
	}

	// Initialization Functions

	
	 /// @dev Creates new attributes for a Locked SmartHousing Token.
	 /// @param startTimestamp The start time of the lock.
	 /// @param amount The amount of SmartHousing Tokens locked.
	 /// @return attributes The initialized attributes.
	 
	function newAttributes(
		uint256 startTimestamp,
		uint256 amount
	) internal pure returns (Attributes memory) {
		return
			Attributes({
				initialAmount: amount,
				amount: amount,
				startTimestamp: startTimestamp,
				endTimestamp: startTimestamp.add(LOCK_DURATION)
			});
	}

	// View Functions

	
	 /// @dev Calculates and deducts the unlocked amount based on the elapsed time.
	 /// @param self The attributes to update.
	 /// @return unlockedAmount The amount of tokens unlocked.
	 /// @return newSelf The updated attributes with the deducted amount.
	 
	function unlockMatured(
		Attributes memory self
	)
		internal
		view
		returns (uint256 unlockedAmount, Attributes memory newSelf)
	{
		uint256 elapsed = elapsedTime(self);
		unlockedAmount = self.amount.mul(elapsed).div(LOCK_DURATION);

		self.amount = self.amount.sub(unlockedAmount);
		newSelf = self;
	}

	
	 /// @dev Calculates the elapsed time since the lock started.
	 /// @param self The attributes to use.
	 /// @return elapsedTime The elapsed time in seconds.
	 
	function elapsedTime(
		Attributes memory self
	) internal view returns (uint256) {
		uint256 currentTime = block.timestamp;
		if (currentTime >= self.endTimestamp) {
			return LOCK_DURATION;
		} else {
			return currentTime.sub(self.startTimestamp);
		}
	}
}
