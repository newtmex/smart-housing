// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "../../lib/Epochs.sol";
import "../../housing-project/HousingProject.sol";
import "../../modules/sht-module/Economics.sol";

import { HstAttributes } from "../HST.sol";

library ProjectStakingRewards {
	/// @notice Structure to track staking rewards.
	/// @param toShare The amount available for distribution.
	/// @param checkpoint The checkpoint to track distributed rewards.
	struct Value {
		uint256 toShare;
		uint256 checkpoint;
	}

	/// @notice Adds a specified value to staking rewards.
	/// @param self The storage struct containing staking rewards.
	/// @param rhs The value to add to staking rewards.
	function add(Value storage self, uint256 rhs) internal {
		self.toShare += rhs;
		self.checkpoint += rhs;
	}

	/// @notice Subtracts a specified value from staking rewards.
	/// @param self The storage struct containing staking rewards.
	/// @param rhs The value to subtract from staking rewards.
	function sub(Value storage self, uint256 rhs) internal {
		self.toShare -= rhs;
	}
}

/// @title Distribution Library for SmartHousing Contract
/// @notice This library manages the distribution of staking rewards and project rent across housing projects within the SmartHousing ecosystem.
/// @dev The library handles the allocation of received rents to specific housing projects, computes staking rewards, and allows users to claim their rewards.
library Distribution {
	using Epochs for Epochs.Storage;
	using Entities for Entities.Value;
	using ProjectStakingRewards for ProjectStakingRewards.Value;

	struct Storage {
		uint256 totalFunds; // Total funds available for distribution
		uint256 projectsTotalReceivedRents; // Total rents received across all projects
		mapping(address => ProjectDistributionData) projectDets; // Project-specific distribution data
		mapping(address => address) projectSftToProjectAddress; // Mapping of project SFT to project addresses
		uint256 lastFundsDispatchTimestamp; // Timestamp of the last fund distribution
		uint256 shtTotalStakeWeight; // Total weight of all staked SHT tokens
		uint256 shtRewardPerShare; // Reward per share for SHT stakers
		uint256 shtStakingRewards; // Total rewards allocated for SHT staking
		ProjectStakingRewards.Value projectsStakingRewards; // Accumulated staking rewards for projects
		Entities.Value entityFunds; // Funds allocated to entities
	}

	struct ProjectDistributionData {
		uint256 maxShares; // Maximum supply of shares for the project
		uint256 receivedRents; // Total rents received for the project
	}

	/// @notice Sets the total funds for distribution and the genesis epoch. Can only be called once.
	/// @param self The storage struct to set the total funds and genesis epoch.
	/// @param amount The amount of total funds to set.
	function setTotalFunds(Storage storage self, uint256 amount) internal {
		require(self.totalFunds == 0, "Total funds already set");
		self.totalFunds = amount;
		self.lastFundsDispatchTimestamp = block.timestamp;
	}

	/// @notice Returns the total funds available for distribution.
	/// @param self The storage struct containing the total funds.
	/// @return The total funds.
	function getTotalFunds(
		Storage storage self
	) internal view returns (uint256) {
		return self.totalFunds;
	}

	/// @notice Adds rent received for a specific project and updates the total received rents and project-specific data.
	/// @dev Updates the total amount of rent received across all projects and updates the specific project data.
	/// If the `maxShares` for the project has not been set, it retrieves and sets it from the `HousingProject` contract.
	/// @param self The storage struct for the `Distribution` contract where project and rent data is stored.
	/// @param projectAddress The address of the project whose rent is being added.
	/// @param amount The amount of rent received to be added to the project and total received rents.
	function addProjectRent(
		Storage storage self,
		address projectAddress,
		uint256 amount
	) internal {
		self.projectsTotalReceivedRents += amount;

		ProjectDistributionData storage projectData = self.projectDets[
			projectAddress
		];

		// If the maxShares for the project hasn't been set, retrieve and set it from the HousingProject contract.
		if (projectData.maxShares == 0) {
			projectData.maxShares = HousingProject(projectAddress)
				.getMaxSupply();
		}

		projectData.receivedRents += amount;
	}

	/// @notice Adds a new project to the distribution system.
	/// @param self The storage struct for the `Distribution` contract.
	/// @param projectAddress The address of the new project.
	/// @param projectSFTaddress The address of the project's SFT token.
	/// @param maxShares The maximum shares for the project.
	function addProject(
		Storage storage self,
		address projectAddress,
		address projectSFTaddress,
		uint256 maxShares
	) internal {
		self.projectDets[projectAddress].maxShares = maxShares;
		self.projectSftToProjectAddress[projectSFTaddress] = projectAddress;
	}

	/// @notice Computes emissions for a specific epoch based on provided timestamps.
	/// @param epochs The storage struct containing epoch information.
	/// @param epoch The epoch for which to compute emissions.
	/// @param lastTimestamp The timestamp of the last reward generation.
	/// @param latestTimestamp The current timestamp.
	/// @return The computed emissions for the specified time range within the epoch.
	function _computeEdgeEmissions(
		Epochs.Storage memory epochs,
		uint256 epoch,
		uint256 lastTimestamp,
		uint256 latestTimestamp
	) private pure returns (uint256) {
		(uint256 startTimestamp, uint256 endTimestamp) = epochs
			.epochEdgeTimestamps(epoch);

		// Determine the bounds for emission calculation.
		uint256 upperBoundTime;
		uint256 lowerBoundTime;

		// Case 1: The latest timestamp is within the epoch.
		if (
			startTimestamp <= latestTimestamp && latestTimestamp <= endTimestamp
		) {
			upperBoundTime = latestTimestamp;
			lowerBoundTime = startTimestamp;
		}
		// Case 2: The last timestamp is within the epoch.
		else if (
			startTimestamp <= lastTimestamp && lastTimestamp <= endTimestamp
		) {
			upperBoundTime = latestTimestamp <= endTimestamp
				? latestTimestamp
				: endTimestamp;
			lowerBoundTime = lastTimestamp;
		}
		// Case 3: Invalid timestamps.
		else {
			revert("Router._computeEdgeEmissions: Invalid timestamps");
		}

		// Calculate emissions based on the time range.
		return
			Emission.throughTimeRange(
				epoch,
				upperBoundTime - lowerBoundTime,
				epochs.epochLength
			);
	}

	/// @notice Generates rewards for the elapsed epochs since the last funds dispatch.
	/// @dev The rewards are computed per second for precision and distributed across the system.
	/// @param self The storage struct for the `Distribution` contract.
	/// @param epochs The storage struct containing epoch information.
	function generateRewards(
		Storage storage self,
		Epochs.Storage storage epochs
	) internal {
		uint256 currentTimestamp = block.timestamp;
		uint256 lastTimestamp = self.lastFundsDispatchTimestamp;

		// Return early if no time has passed since the last dispatch.
		if (currentTimestamp <= lastTimestamp) {
			return;
		}

		uint256 lastGenerateEpoch = epochs.computeEpoch(lastTimestamp);
		uint256 toDispatch = _computeEdgeEmissions(
			epochs,
			lastGenerateEpoch,
			lastTimestamp,
			currentTimestamp
		);

		uint256 currentEpoch = epochs.currentEpoch();
		if (currentEpoch > lastGenerateEpoch) {
			uint256 intermediateEpochs = currentEpoch - lastGenerateEpoch - 1;

			// Include rewards for all intermediate epochs.
			if (intermediateEpochs > 1) {
				toDispatch += Emission.throughEpochRange(
					lastGenerateEpoch,
					lastGenerateEpoch + intermediateEpochs
				);
			}

			toDispatch += _computeEdgeEmissions(
				epochs,
				currentEpoch,
				lastTimestamp,
				currentTimestamp
			);
		}

		// Convert the total dispatched value into entity-specific funds.
		Entities.Value memory entitiesValue = Entities.fromTotalValue(
			toDispatch
		);

		// Allocate staking rewards and update entity funds.
		uint256 stakingRewards = entitiesValue.staking;
		entitiesValue.staking = 0;
		self.entityFunds.add(entitiesValue);

		// Calculate and distribute the share for SHT stakers.
		uint256 shtStakersShare = (stakingRewards * 7) / 10;

		uint256 totalShtWeight = self.shtTotalStakeWeight;
		if (totalShtWeight > 0) {
			// Increase reward per share based on the stakers' share.
			uint256 rpsIncrease = (shtStakersShare * DIVISION_SAFETY_CONST) /
				totalShtWeight;
			self.shtRewardPerShare += rpsIncrease;
		}

		self.shtStakingRewards += shtStakersShare;
		self.projectsStakingRewards.add(stakingRewards - shtStakersShare);

		// Update the last funds dispatch timestamp to the current timestamp.
		self.lastFundsDispatchTimestamp = currentTimestamp;
	}

	/// @notice Claims staking rewards for SHT holders based on their stake and updates their rewards balance.
	/// @param self The storage struct for the `Distribution` contract.
	/// @param attr The attributes struct for which rewards are being claimed.
	/// @return The total amount of rewards claimed and the updated attributes struct.
	function claimRewards(
		Storage storage self,
		HstAttributes memory attr
	) internal returns (uint256, HstAttributes memory) {
		uint256 shtClaimed = 0;

		// Retrieve the checkpoint value for project token staking rewards.
		uint256 ptRewardCheckpoint = self.projectsStakingRewards.checkpoint;

		// If there are project staking rewards available, calculate the rewards for each project token.
		if (ptRewardCheckpoint > 0) {
			// Iterate through each project token associated with the user.
			for (uint256 i = 0; i < attr.projectTokens.length; i++) {
				// Compute the reward for the project token based on the user's share and the current checkpoint.
				shtClaimed += computeRewardForPT(
					self,
					attr.projectTokens[i],
					attr.projectsShareCheckpoint,
					ptRewardCheckpoint
				);
			}

			// Ensure that the claimed rewards do not exceed the available staking rewards for the projects.
			if (self.projectsStakingRewards.toShare < shtClaimed) {
				shtClaimed = self.projectsStakingRewards.toShare;
			}

			// Deduct the claimed rewards from the total available project staking rewards.
			self.projectsStakingRewards.toShare -= shtClaimed;
		}

		// Retrieve the current reward per share for SHT stakers.
		uint256 shtRPS = self.shtRewardPerShare;

		// If the current reward per share is greater than the last recorded reward per share for the user, calculate the additional rewards.
		if (shtRPS > 0 && attr.shtRewardPerShare < shtRPS) {
			uint256 shtReward = ((shtRPS - attr.shtRewardPerShare) *
				attr.stakeWeight) / DIVISION_SAFETY_CONST;

			// Ensure that the reward calculated does not exceed the available SHT staking rewards.
			if (self.shtStakingRewards < shtReward) {
				shtClaimed = self.shtStakingRewards;
			}

			// Deduct the claimed SHT rewards from the total available SHT staking rewards.
			self.shtStakingRewards -= shtReward;

			// Add the SHT rewards to the total claimed rewards.
			shtClaimed += shtReward;
		}

		// Update the user's attributes with the latest reward per share and project share checkpoint values.
		attr.shtRewardPerShare = shtRPS;
		attr.projectsShareCheckpoint = ptRewardCheckpoint;

		// Return the total claimed rewards and the updated attributes.
		return (shtClaimed, attr);
	}

	/// @notice Computes the reward for a given PT (Housing Project Token).
	/// @param self The storage struct for the `Distribution` contract.
	/// @param tokenPayment The token payment of the housing project.
	/// @param stakingCheckPoint The previous checkpoint value.
	/// @param tokenCheckPoint The new checkpoint value.
	/// @return reward The computed reward for the given PT.
	function computeRewardForPT(
		Storage storage self,
		TokenPayment memory tokenPayment,
		uint256 stakingCheckPoint,
		uint256 tokenCheckPoint
	) internal view returns (uint256 reward) {
		if (
			stakingCheckPoint >= tokenCheckPoint ||
			self.projectsTotalReceivedRents == 0
		) {
			return 0;
		}

		address projectAddress = self.projectSftToProjectAddress[
			tokenPayment.token
		];
		require(
			projectAddress != address(0),
			"Project Address for token not set"
		);

		ProjectDistributionData storage projectData = self.projectDets[
			projectAddress
		];
		require(
			tokenPayment.amount <= projectData.maxShares,
			"Project token amount too large"
		);

		uint256 shareIncrease = tokenCheckPoint - (stakingCheckPoint);
		uint256 projectAllocation = (shareIncrease *
			(projectData.receivedRents)) / (self.projectsTotalReceivedRents);

		reward =
			(projectAllocation * (tokenPayment.amount)) /
			(projectData.maxShares);
	}

	/// @notice Enters staking for the given attributes.
	/// @param self The storage struct for the `Distribution` contract.
	/// @param stakeWeight The stake weight to be added.
	function enterStaking(Storage storage self, uint256 stakeWeight) internal {
		self.shtTotalStakeWeight += (stakeWeight);
	}
}
