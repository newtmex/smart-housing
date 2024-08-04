// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title LkSHTAttributes
 * @dev Library for handling attributes and unlocking of the Locked SmartHousing Token.
 */
library LkSHTAttributes {
	using SafeMath for uint256;

	uint256 constant LOCK_DURATION = 3 * 365 days; // 3 years

	struct Attributes {
		uint256 initialAmount;
		uint256 amount;
		uint256 startTimestamp;
		uint256 endTimestamp;
	}

	/**
	 * @dev Creates new attributes for a Locked SmartHousing Token.
	 * @param startTimestamp The start time of the lock.
	 * @param amount The amount of SmartHousing Tokens locked.
	 * @return attributes The initialized attributes.
	 */
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

	/**
	 * @dev Calculates and deducts the unlocked amount based on the elapsed time.
	 * @param self The attributes to update.
	 * @return unlockedAmount The amount of tokens unlocked.
	 */
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

	/**
	 * @dev Calculates the elapsed time since the lock started.
	 * @param self The attributes to use.
	 * @return elapsedTime The elapsed time in seconds.
	 */
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
