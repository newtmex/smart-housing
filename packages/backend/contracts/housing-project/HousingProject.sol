// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./RentsModule.sol";
import "./CallsSmartHousing.sol";

uint256 constant RENT_SPREAD_RANGE = 365 days;

/// @title HousingProject Contract
/// @notice Represents a unique real estate project within the SmartHousing ecosystem.
/// @dev This contract inherits from RentsModule and Ownable for management functions.
contract HousingProject is RentsModule, Ownable, CallsSmartHousing {
	using RewardShares for rewardshares;
	using TokenPayments for ERC20TokenPayment;

	uint256 public maxSupply;

	// State Variables
	uint256 public rewardsReserve;
	uint256 public rewardPerShare;

	uint256 public totalRewardsCollected;
	uint256 public totalRewardsGenerated;
	uint256 public rewardsAPR;
	uint256 public lastRewardGenerateTimestamp;
	uint256 public endRewardGenerateTimestamp;

	uint256 public facilityManagementFunds;

	// Constants
	uint256 public constant REWARD_PERCENT = 75;
	uint256 public constant ECOSYSTEM_PERCENT = 18;
	uint256 public constant FACILITY_PERCENT = 7;

	HousingSFT public immutable projectSFT;
	ERC20Burnable public immutable housingToken;

	/// @notice Initializes the HousingProject contract.
	/// @param smartHousingAddr The address of the main SmartHousing contract.
	/// @param housingTokenAddr Coinbase contraact address
	/// @param name The name of the HousingSFT token.
	/// @param symbol The symbol of the HousingSFT token.
	constructor(
		string memory name,
		string memory symbol,
		address smartHousingAddr,
		address housingTokenAddr
	) CallsSmartHousing(smartHousingAddr) {
		projectSFT = new HousingSFT(name, symbol);
		maxSupply = projectSFT.getMaxSupply();

		// Initialize the housing token
		housingToken = ERC20Burnable(housingTokenAddr);
	}

	/// @notice Receives rent payments, calculates, and distributes rewards.
	/// @param rentPayment The details of the rent payment.
	function receiveRent(ERC20TokenPayment calldata rentPayment) external {
		uint256 rentAmount = rentPayment.amount;
		require(rentAmount > 0, "RentsModule: Insufficient amount");
		require(
			rentPayment.token == housingToken,
			"RentsModule: Invalid token"
		);

		rentPayment.receiveERC20();

		// Calculate reward components
		uint256 rentReward = (rentAmount * REWARD_PERCENT) / 100;
		uint256 ecosystemReward = (rentAmount * ECOSYSTEM_PERCENT) / 100;
		uint256 facilityReward = (rentAmount * FACILITY_PERCENT) / 100;

		// Initialize reward generation if it's the first rent payment
		if (totalRewardsCollected == 0) {
			lastRewardGenerateTimestamp = block.timestamp;
		}

		// Update rewards and reserve
		endRewardGenerateTimestamp = block.timestamp + RENT_SPREAD_RANGE;
		totalRewardsCollected += rentReward;
		rewardsAPR =
			((totalRewardsCollected - totalRewardsGenerated) *
				DIVISION_SAFETY_CONST) /
			maxSupply /
			(endRewardGenerateTimestamp - lastRewardGenerateTimestamp);

		facilityManagementFunds += facilityReward;

		// Burn ecosystem reward and notify SmartHousing contract
		housingToken.burn(ecosystemReward);
		ISmartHousing(smartHousingAddr).addProjectRent(rentAmount);
	}

	/// @notice Generates rewards based on elapsed time since the last generation.
	/// @return generatedRewards The total rewards generated during the elapsed time.
	/// @return rpsIncrement The increment to be added to rewardPerShare.
	function _generateRewards()
		internal
		view
		returns (uint256 generatedRewards, uint256 rpsIncrement)
	{
		uint256 timeElapsed = _min(
			endRewardGenerateTimestamp,
			block.timestamp
		) - lastRewardGenerateTimestamp;

		if (timeElapsed > 0) {
			generatedRewards =
				(rewardsAPR * maxSupply * timeElapsed) /
				DIVISION_SAFETY_CONST;

			require(
				(totalRewardsGenerated + generatedRewards) <=
					totalRewardsCollected,
				"HousingProject: Rewards generated overflowed"
			);

			rpsIncrement =
				(generatedRewards * DIVISION_SAFETY_CONST) /
				maxSupply;
		}
	}

	/// @notice Claims rent rewards for a given token and updates attributes.
	/// @param nonce The nonce of the token to claim rewards for.
	/// @return attr The updated HousingAttributes.
	/// @return rewardShares The computed reward shares.
	/// @return newNonce The new nonce after updating the token.
	function claimRentReward(
		uint256 nonce
	)
		external
		returns (
			HousingAttributes memory attr,
			rewardshares memory rewardShares,
			uint256 newNonce
		)
	{
		// Generate rewards and increment reward per share
		{
			(
				uint256 generatedRewards,
				uint256 rpsIncrement
			) = _generateRewards();
			if (generatedRewards > 0) {
				rewardPerShare += rpsIncrement;
				rewardsReserve += generatedRewards;
				totalRewardsGenerated += generatedRewards;
				lastRewardGenerateTimestamp = _min(
					endRewardGenerateTimestamp,
					block.timestamp
				);
			}
		}

		address caller = msg.sender;

		// Fetch user attributes and compute rewards
		attr = projectSFT.getUserSFT(caller, nonce);
		rewardShares = _computeRewardShares(attr, rewardPerShare);

		uint256 totalReward = rewardShares.total();
		if (totalReward == 0) {
			return (attr, rewardShares, nonce);
		}

		require(
			rewardsReserve >= totalReward,
			"RentsModule: Insufficient rewards reserve"
		);
		rewardsReserve -= totalReward;

		// Transfer or burn referrer reward
		uint256 referrerValue = rewardShares.referrerValue;
		if (referrerValue > 0) {
			(, address referrer) = _getReferrer(attr.originalOwner);
			if (referrer != address(0)) {
				housingToken.transfer(referrer, referrerValue);
			} else {
				housingToken.burn(referrerValue);
			}
		}

		// Update user attributes and transfer reward
		attr.rewardsPerShare = rewardPerShare;
		newNonce = projectSFT.update(
			caller,
			nonce,
			projectSFT.balanceOf(caller, nonce),
			abi.encode(attr)
		);
		housingToken.transfer(caller, rewardShares.userValue);

		return (attr, rewardShares, newNonce);
	}

	/// @notice Helper function to calculate the minimum of two values.
	/// @param a The first value.
	/// @param b The second value.
	/// @return The minimum of the two values.
	function _min(uint256 a, uint256 b) private pure returns (uint256) {
		return a < b ? a : b;
	}

	/// @notice Returns the maximum supply of the HousingSFT token.
	/// @return The maximum supply of the HousingSFT token.
	function getMaxSupply() external view returns (uint256) {
		return projectSFT.getMaxSupply();
	}

	/// @notice Calculates the amount of rent claimable for a given token.
	/// @param attr The attributes of the token.
	/// @return The amount of rent claimable.
	function rentClaimable(
		HousingAttributes memory attr
	) public view returns (uint256) {
		(, uint256 rpsIncrement) = _generateRewards();

		return
			_computeRewardShares(attr, rewardPerShare + rpsIncrement).userValue;
	}
}
