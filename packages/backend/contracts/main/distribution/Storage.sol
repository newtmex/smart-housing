// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../../lib/EpochsAndPeriods.sol";
import "../../housing-project/HousingProject.sol";
import "../../modules/sht-module/Economics.sol";
import { HstAttributes } from "../HST.sol";

library ProjectStakingRewards {
	using SafeMath for uint256;

	struct Value {
		uint256 toShare;
		uint256 checkpoint;
	}

	function add(Value storage self, uint256 rhs) internal {
		self.toShare = self.toShare.add(rhs);
		self.checkpoint = self.checkpoint.add(rhs);
	}

	function sub(Value storage self, uint256 rhs) internal {
		self.toShare = self.toShare.sub(rhs);
	}
}

library Distribution {
	using SafeMath for uint256;
	using EpochsAndPeriods for EpochsAndPeriods.Storage;
	using Entities for Entities.Value;
	using ProjectStakingRewards for ProjectStakingRewards.Value;

	struct Storage {
		uint256 totalFunds;
		uint256 genesisEpoch;
		uint256 projectsTotalReceivedRents;
		mapping(address => ProjectDistributionData) projectDets;
		mapping(address => address) projectSftToProjectAddress;
		uint256 lastFundsDispatchEpoch;
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
	/// @param epochsAndPeriods The storage struct for epoch and period management.
	function setTotalFunds(
		Storage storage self,
		EpochsAndPeriods.Storage storage epochsAndPeriods,
		uint256 amount
	) internal {
		require(self.totalFunds == 0, "Total funds already set");
		self.totalFunds = amount;
		self.genesisEpoch = epochsAndPeriods.currentEpoch();
	}

	/// @notice Returns the total funds.
	/// @param self The storage struct containing the total funds.
	/// @return The total funds.
	function getTotalFunds(
		Storage storage self
	) internal view returns (uint256) {
		return self.totalFunds;
	}

	/// @notice Returns the genesis epoch when the total funds were set.
	/// @param self The storage struct containing the genesis epoch.
	/// @return The genesis epoch.
	function getGenesisEpoch(
		Storage storage self
	) internal view returns (uint256) {
		return self.genesisEpoch;
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
		self.projectsTotalReceivedRents = self.projectsTotalReceivedRents.add(
			amount
		);

		ProjectDistributionData storage projectData = self.projectDets[
			projectAddress
		];

		if (projectData.maxShares == 0) {
			projectData.maxShares = HousingProject(projectAddress)
				.getMaxSupply();
		}

		projectData.receivedRents = projectData.receivedRents.add(amount);
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

	/// @notice Generates rewards for the epochs that have elapsed.
	/// @param self The storage struct for the `Distribution` contract.
	function generateRewards(
		Storage storage self,
		EpochsAndPeriods.Storage storage epochsAndPeriods
	) internal {
		uint256 currentEpoch = epochsAndPeriods.currentEpoch();
		if (currentEpoch <= self.lastFundsDispatchEpoch) {
			return;
		}

		uint256 toDispatch = Emission.throughEpochRange(
			self.lastFundsDispatchEpoch,
			currentEpoch
		);
		Entities.Value memory entitiesValue = Entities.fromTotalValue(
			toDispatch
		);

		// Take stakers value
		uint256 stakingRewards = entitiesValue.staking;
		entitiesValue.staking = 0;
		self.entityFunds.add(entitiesValue);

		uint256 shtStakersShare = stakingRewards.mul(7).div(10); // 70% to SHT stakers

		uint256 totalShtWeight = self.shtTotalStakeWeight;
		if (totalShtWeight > 0) {
			uint256 rpsIncrease = shtStakersShare
				.mul(DIVISION_SAFETY_CONST)
				.div(totalShtWeight);
			self.shtRewardPerShare = self.shtRewardPerShare.add(rpsIncrease);
		}

		self.shtStakingRewards = self.shtStakingRewards.add(shtStakersShare);
		self.projectsStakingRewards.add(stakingRewards.sub(shtStakersShare));

		self.lastFundsDispatchEpoch = currentEpoch;
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
				shtClaimed = shtClaimed.add(
					computeRewardForPT(
						self,
						attr.projectTokens[i],
						attr.projectsShareCheckpoint,
						ptRewardCheckpoint
					)
				);
			}

			if (self.projectsStakingRewards.toShare < shtClaimed) {
				shtClaimed = self.projectsStakingRewards.toShare;
			}
			self.projectsStakingRewards.toShare = self
				.projectsStakingRewards
				.toShare
				.sub(shtClaimed);
		}

		uint256 shtRPS = self.shtRewardPerShare;
		if (shtRPS > 0 && attr.shtRewardPerShare < shtRPS) {
			uint256 shtReward = shtRPS
				.sub(attr.shtRewardPerShare)
				.mul(attr.stakeWeight)
				.div(DIVISION_SAFETY_CONST);
			if (self.shtStakingRewards < shtReward) {
				shtClaimed = self.shtStakingRewards;
			}
			self.shtStakingRewards = self.shtStakingRewards.sub(shtReward);
			shtClaimed = shtClaimed.add(shtReward);
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

		uint256 shareIncrease = tokenCheckPoint.sub(stakingCheckPoint);
		uint256 projectAllocation = shareIncrease
			.mul(projectData.receivedRents)
			.div(self.projectsTotalReceivedRents);

		reward = projectAllocation.mul(tokenPayment.amount).div(
			projectData.maxShares
		);
	}

	/// @notice Enters staking for the given attributes.
	/// @param self The storage struct for the `Distribution` contract.
	/// @param stakeWeight The stake weight to be added.
	function enterStaking(Storage storage self, uint256 stakeWeight) internal {
		self.shtTotalStakeWeight = self.shtTotalStakeWeight.add(stakeWeight);
	}
}
