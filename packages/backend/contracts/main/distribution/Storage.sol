// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "../../lib/EpochsAndPeriods.sol";
import "../../housing-project/HousingProject.sol";

library Distribution {
	using EpochsAndPeriods for EpochsAndPeriods.Storage;

	struct Storage {
		uint256 totalFunds;
		uint256 genesisEpoch;
		uint256 projectsTotalReceivedRents;
		mapping(address => ProjectDistributionData) projectDets;
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
		// Update the total received rents across all projects
		self.projectsTotalReceivedRents += amount;

		// Retrieve or initialize project-specific data
		ProjectDistributionData storage projectData = self.projectDets[
			projectAddress
		];

		// If `maxShares` is not set, initialize it with the maximum supply from the HousingProject contract
		if (projectData.maxShares == 0) {
			projectData.maxShares = HousingProject(projectAddress).getMaxSupply();
		}

		// Add the received rent amount to the project's accumulated rents
		projectData.receivedRents += amount;
	}
}
