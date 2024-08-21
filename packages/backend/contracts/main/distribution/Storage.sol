// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../lib/Epochs.sol";
import "../../housing-project/HousingProject.sol";
import "../../modules/sht-module/Economics.sol";
import { HstAttributes } from "../HST.sol";

library ProjectStakingRewards {
	struct Value {
		uint256 toShare;
		uint256 checkpoint;
	}

	function add(Value storage self, uint256 rhs) internal {
		self.toShare += rhs;
		self.checkpoint += rhs;
	}

	function sub(Value storage self, uint256 rhs) internal {
		self.toShare -= rhs;
	}
}

library Distribution {
	using Epochs for Epochs.Storage;
	using Entities for Entities.Value;
	using ProjectStakingRewards for ProjectStakingRewards.Value;

	struct Storage {
		uint256 totalFunds;
		uint256 projectsTotalReceivedRents;
		mapping(address => ProjectDistributionData) projectDets;
		mapping(address => address) projectSftToProjectAddress;
		uint256 lastFundsDispatchTimestamp;
		uint256 shtTotalStakeWeight;
		uint256 shtRewardPerShare;
		uint256 shtStakingRewards;
		ProjectStakingRewards.Value projectsStakingRewards;
		Entities.Value entityFunds;
	}

	struct ProjectDistributionData {
		uint256 maxShares;
		uint256 receivedRents;
	}

	/// @notice Sets the total funds and the genesis epoch. This can only be done once.
	/// @param self The storage struct to set the total funds and genesis epoch.
	/// @param amount The amount of total funds to set.
	function setTotalFunds(Storage storage self, uint256 amount) internal {
		require(self.totalFunds == 0, "Total funds already set");
		self.totalFunds = amount;
		self.lastFundsDispatchTimestamp = block.timestamp;
	}

	/// @notice Returns the total funds.
	/// @param self The storage struct containing the total funds.
	/// @return The total funds.
	function getTotalFunds(
		Storage storage self
	) internal view returns (uint256) {
		return self.totalFunds;
	}

	/// @notice Adds the rent received for a project and updates the total received rents and project-specific data.
	/// @dev This function updates the total amount of rent received across all projects and updates the specific project data.
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

		if (projectData.maxShares == 0) {
			projectData.maxShares = HousingProject(projectAddress)
				.getMaxSupply();
		}

		projectData.receivedRents += amount;
	}

	function addProject(
		Storage storage self,
		address projectAddress,
		address projectSFTaddress,
		uint256 maxShares
	) internal {
		self.projectDets[projectAddress].maxShares = maxShares;
		self.projectSftToProjectAddress[projectSFTaddress] = projectAddress;
	}

	/// @notice Computes the emissions for a specific epoch based on provided timestamps.
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

		if (
			startTimestamp <= latestTimestamp && latestTimestamp <= endTimestamp
		) {
			upperBoundTime = latestTimestamp;
			lowerBoundTime = startTimestamp;
		} else if (
			startTimestamp <= lastTimestamp && lastTimestamp <= endTimestamp
		) {
			upperBoundTime = latestTimestamp <= endTimestamp
				? latestTimestamp
				: endTimestamp;
			lowerBoundTime = lastTimestamp;
		} else {
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

	/// @notice Generates rewards for the epochs that have elapsed since the last dispatch.
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
		entitiesValue.staking = 0; // Reset staking rewards in the entity value.
		self.entityFunds.add(entitiesValue);

		uint256 shtStakersShare = (stakingRewards * 7) / 10; // 70% to SHT stakers.

		uint256 totalShtWeight = self.shtTotalStakeWeight;
		if (totalShtWeight > 0) {
			uint256 rpsIncrease = (shtStakersShare * DIVISION_SAFETY_CONST) /
				totalShtWeight;
			self.shtRewardPerShare += rpsIncrease;
		}

		self.shtStakingRewards += shtStakersShare;
		self.projectsStakingRewards.add(stakingRewards - shtStakersShare);

		// Update the last funds dispatch timestamp to the current timestamp.
		self.lastFundsDispatchTimestamp = currentTimestamp;
	}

	/// @notice Claims rewards for a given attribute.
	/// @param self The storage struct for the `Distribution` contract.
	/// @param attr The attributes struct for which rewards are being claimed.
	/// @return The total amount of rewards claimed.
	function claimRewards(
		Storage storage self,
		HstAttributes memory attr
	) internal returns (uint256, HstAttributes memory) {
		uint256 shtClaimed = 0;

		uint256 ptRewardCheckpoint = self.projectsStakingRewards.checkpoint;
		if (ptRewardCheckpoint > 0) {
			for (uint256 i = 0; i < attr.projectTokens.length; i++) {
				shtClaimed += computeRewardForPT(
					self,
					attr.projectTokens[i],
					attr.projectsShareCheckpoint,
					ptRewardCheckpoint
				);
			}

			if (self.projectsStakingRewards.toShare < shtClaimed) {
				shtClaimed = self.projectsStakingRewards.toShare;
			}
			self.projectsStakingRewards.toShare -= shtClaimed;
		}

		uint256 shtRPS = self.shtRewardPerShare;
		if (shtRPS > 0 && attr.shtRewardPerShare < shtRPS) {
			uint256 shtReward = ((shtRPS - attr.shtRewardPerShare) *
				attr.stakeWeight) / DIVISION_SAFETY_CONST;
			if (self.shtStakingRewards < shtReward) {
				shtClaimed = self.shtStakingRewards;
			}
			self.shtStakingRewards -= (shtReward);
			shtClaimed += (shtReward);
		}

		attr.shtRewardPerShare = shtRPS;
		attr.projectsShareCheckpoint = ptRewardCheckpoint;

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
