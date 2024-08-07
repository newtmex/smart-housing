// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./TokenPayments.sol";

library ProjectStorage {
	using SafeMath for uint256;
	using TokenPayments for ERC20TokenPayment;
	using ProjectStorage for Data;

	enum Status {
		FundingPeriod,
		Successful,
		Failed
	}

	struct Data {
		uint256 id; // Unique identifier for the project
		address tokenAddress;
		address projectAddress; // Address of the deployed HousingProject contract
		uint256 fundingGoal; // Target funding amount for the project
		uint256 fundingDeadline; // Deadline timestamp for the project funding
		address fundingToken; // Address of the ERC20 token used for funding
		uint256 collectedFunds; // Amount of funds collected for the project
	}

	function status(Data storage self) internal view returns (Status) {
		if (self.collectedFunds >= self.fundingGoal) {
			return Status.Successful;
		} else if (block.timestamp < self.fundingDeadline) {
			return Status.FundingPeriod;
		} else {
			return Status.Failed;
		}
	}

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
		require(fundingToken != address(0), "Invalid token provided");

		uint256 newId = projectCount.add(1);

		Data memory newProjectData = Data({
			id: newId,
			projectAddress: projectAddress,
			fundingGoal: fundingGoal,
			fundingDeadline: fundingDeadline,
			fundingToken: fundingToken,
			collectedFunds: 0,
			tokenAddress: tokenAddress 
		});

		projects[newId] = newProjectData;
		projectsId[newProjectData.projectAddress] = newProjectData.id;

		return newProjectData;
	}

	function fund(
		mapping(uint256 => Data) storage projects,
		mapping(address => uint256) storage usersDeposit,
		uint256 projectId,
		address depositor,
		ERC20TokenPayment calldata payment
	) internal {
		require(payment.amount > 0, "Invalid funding amount");

		Data storage project = projects[projectId];

		require(
			project.status() == Status.FundingPeriod,
			"Cannot fund project after deadline"
		);
		require(
			address(payment.token) == project.fundingToken,
			"Wrong token payment"
		);
		payment.accept();

		project.collectedFunds = project.collectedFunds.add(payment.amount);
		usersDeposit[depositor] = usersDeposit[depositor].add(payment.amount);
	}

	/**
	 * @dev Retrieves and updates the user's deposit for a specific project.
	 * @param projectId The ID of the project to retrieve the deposit for.
	 * @param depositor The address of the depositor.
	 * @return (ProjectStorage.Data, uint256) The project data and deposit amount.
	 */
	function takeDeposit(
		mapping(uint256 => Data) storage projects,
		mapping(address => uint256) storage usersDeposit,
		uint256 projectId,
		address depositor
	) internal returns (ProjectStorage.Data memory, uint256) {
		ProjectStorage.Data storage project = projects[projectId];
		require(project.id != 0, "Invalid project ID");
		require(
			project.status() == Status.Successful,
			"Project not yet successful"
		);

		uint256 depositAmount = usersDeposit[depositor];
		require(depositAmount > 0, "No deposit found");

		// Update the deposit amount to zero
		usersDeposit[depositor] = 0;

		return (project, depositAmount);
	}
}
