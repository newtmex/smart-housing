// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./TokenPayments.sol";
import { HousingSFT } from "../housing-project/HousingSFT.sol";

/// @title ProjectStorage
/// @dev Library for managing project data, funding, and deposit retrieval.
library ProjectStorage {
	using SafeMath for uint256;
	using TokenPayments for TokenPayment;
	using ProjectStorage for Data;

	// Enum representing the status of a project
	enum Status {
		FundingPeriod, // Project is currently in the funding period
		Successful, // Project has met its funding goal
		Failed // Project has failed to meet its funding goal
	}

	// Struct to hold project data
	struct Data {
		uint256 id; // Unique identifier for the project
		address tokenAddress; // Address of the token associated with the project
		address projectAddress; // Address of the deployed HousingProject contract
		uint256 fundingGoal; // Target funding amount for the project
		uint256 fundingDeadline; // Deadline timestamp for the project funding
		address fundingToken; // Address of the ERC20 token used for funding
		uint256 collectedFunds; // Amount of funds collected for the project
		uint256 minDeposit; // Least amount of funding to receive
	}

	// View Functions

	/// @dev Returns the current status of the project based on collected funds and deadline.
	/// @param self The memory struct containing project data.
	/// @return The status of the project.
	function status(Data memory self) internal view returns (Status) {
		if (self.collectedFunds >= self.fundingGoal) {
			return Status.Successful;
		} else if (block.timestamp < self.fundingDeadline) {
			return Status.FundingPeriod;
		} else {
			return Status.Failed;
		}
	}

	// Initialization Functions

	/// @dev Creates and initializes a new project.
	/// @param projects The mapping of project IDs to project data.
	/// @param projectsId The mapping of project addresses to project IDs.
	/// @param projectCount The current number of projects.
	/// @param fundingGoal The target funding amount.
	/// @param fundingDeadline The deadline for funding.
	/// @param fundingToken The address of the ERC20 token used for funding.
	/// @param projectAddress The address of the HousingProject contract.
	/// @param tokenAddress The address of the token associated with the project.
	/// @return newProjectData The newly created project data.
	function createNew(
		mapping(uint256 => Data) storage projects,
		mapping(address => uint256) storage projectsId,
		uint256 projectCount,
		uint256 fundingGoal,
		uint256 fundingDeadline,
		address fundingToken,
		address projectAddress,
		address tokenAddress
	) internal returns (Data memory) {
		require(fundingGoal > 0, "Funding goal must be more than 0");
		require(
			fundingDeadline > block.timestamp,
			"Deadline can't be in the past"
		);

		uint256 newId = projectCount.add(1);

		uint256 tokenMaxSupply = HousingSFT(tokenAddress).getMaxSupply();

		Data memory newProjectData = Data({
			id: newId,
			projectAddress: projectAddress,
			fundingGoal: fundingGoal,
			fundingDeadline: fundingDeadline,
			fundingToken: fundingToken,
			collectedFunds: 0,
			tokenAddress: tokenAddress,
			minDeposit: fundingGoal / tokenMaxSupply
		});

		projects[newId] = newProjectData;
		projectsId[newProjectData.projectAddress] = newProjectData.id;

		return newProjectData;
	}

	// Funding Functions

	/// @dev Funds a project with tokens.
	/// @param projects The mapping of project IDs to project data.
	/// @param usersDeposit The mapping of depositor addresses to their deposit amounts.
	/// @param projectId The ID of the project to fund.
	/// @param depositor The address of the person funding the project.
	/// @param payment The details of the token payment.
	function fund(
		mapping(uint256 => Data) storage projects,
		mapping(address => uint256) storage usersDeposit,
		uint256 projectId,
		address depositor,
		TokenPayment calldata payment
	) internal returns (uint256) {
		Data storage project = projects[projectId];

		require(
			payment.amount >= project.minDeposit &&
				payment.amount <= project.fundingGoal,
			"Invalid funding amount"
		);

		require(
			project.status() == Status.FundingPeriod,
			"Cannot fund project after deadline"
		);
		require(
			address(payment.token) == project.fundingToken,
			"Wrong token payment"
		);

		payment.receiveToken();

		project.collectedFunds = project.collectedFunds.add(payment.amount);
		usersDeposit[depositor] = usersDeposit[depositor].add(payment.amount);

		return project.collectedFunds;
	}

	// Deposit Functions

	/// @dev Retrieves and updates the user's deposit for a specific project.
	/// @param projects The mapping of project IDs to project data.
	/// @param usersDeposit The mapping of depositor addresses to their deposit amounts.
	/// @param projectId The ID of the project to retrieve the deposit for.
	/// @param depositor The address of the depositor.
	/// @return project The project data.
	/// @return depositAmount The amount of deposit for the user.
	function takeDeposit(
		mapping(uint256 => Data) storage projects,
		mapping(address => uint256) storage usersDeposit,
		uint256 projectId,
		address depositor
	) internal returns (Data memory project, uint256 depositAmount) {
		project = projects[projectId];
		require(project.id != 0, "Invalid project ID");
		require(
			project.status() == Status.Successful,
			"Project not yet successful"
		);

		depositAmount = usersDeposit[depositor];
		require(depositAmount > 0, "No deposit found");

		// Update the deposit amount to zero
		usersDeposit[depositor] = 0;
	}
}
