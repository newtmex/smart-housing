// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../housing-project/HousingProject.sol";

/**
 * @title ProjectFunding
 * @dev This contract is used for initializing and deploying housing projects.
 * It allows the deployment of a new housing project and manages project data.
 */
contract ProjectFunding is Ownable {
	using SafeMath for uint256;

	struct ProjectData {
		uint256 id; // Unique identifier for the project
		address projectAddress; // Address of the deployed HousingProject contract
		uint256 fundingGoal; // Target funding amount for the project
		uint256 fundingDeadline; // Deadline timestamp for the project funding
		address fundingToken; // Address of the ERC20 token used for funding
		uint256 collectedFunds; // Amount of funds collected for the project
	}

	address public coinbase; // Address authorized to initialize the first project
	address public smartHousingAddress; // Address of the SmartHousing contract

	mapping(uint256 => ProjectData) public projects; // Mapping of project ID to ProjectData
	mapping(address => uint256) public projectsId; // Mapping of project address to project ID
	uint256 public projectCount; // Counter for the total number of projects

	IERC20 public housingToken; // Token used for funding projects

	/**
	 * @dev Emitted when a new project is deployed.
	 * @param projectAddress Address of the newly deployed HousingProject contract.
	 */
	event ProjectDeployed(address indexed projectAddress);

	/**
	 * @param _coinbase Address authorized to initialize the first project.
	 */
	constructor(address _coinbase) {
		coinbase = _coinbase;
	}

	/**
	 * @dev Internal function to deploy a new HousingProject contract.
	 * @param fundingToken Address of the ERC20 token used for funding.
	 * @param fundingGoal The funding goal for the new project.
	 * @param fundingDeadline The deadline for the project funding.
	 */
	function _deployProject(
		address fundingToken,
		uint256 fundingGoal,
		uint256 fundingDeadline
	) internal {
		require(
			block.timestamp < fundingDeadline,
			"Funding deadline has passed"
		);

		projectCount = projectCount.add(1);
		HousingProject newProject = new HousingProject(smartHousingAddress);

		ProjectData memory projectData = ProjectData({
			id: projectCount,
			projectAddress: address(newProject),
			fundingGoal: fundingGoal,
			fundingDeadline: fundingDeadline,
			fundingToken: fundingToken,
			collectedFunds: 0
		});

		projects[projectCount] = projectData;
		projectsId[projectData.projectAddress] = projectData.id;

		emit ProjectDeployed(projectData.projectAddress);
	}

	/**
	 * @dev Initializes the first project.
	 * This function must be called by the coinbase address and can only be called once.
	 * It sets up the token and deploys the first project.
	 * @param shtPayment Payment details for the Smart Housing Token (SHT).
	 * @param smartHousingAddress_ Address of the Smart Housing contract.
	 * @param fundingToken Address of the ERC20 token used for funding.
	 * @param fundingGoal The funding goal for the new project.
	 * @param fundingDeadline The deadline for the project funding.
	 */
	function initFirstProject(
		ERC20TokenPayment calldata shtPayment,
		address smartHousingAddress_,
		address fundingToken,
		uint256 fundingGoal,
		uint256 fundingDeadline
	) external {
		require(msg.sender == coinbase, "Caller is not the coinbase");
		require(projectCount == 0, "Project already initialized");

		TokenPayments.receiveERC20(shtPayment);
		housingToken = shtPayment.token;

		smartHousingAddress = smartHousingAddress_;

		_deployProject(fundingToken, fundingGoal, fundingDeadline);
	}

	/**
	 * @dev Deploys a new project.
	 * This function can be called multiple times to deploy additional projects.
	 * @param fundingToken Address of the ERC20 token used for funding.
	 * @param fundingGoal The funding goal for the new project.
	 * @param fundingDeadline The deadline for the project funding.
	 */
	function deployProject(
		address fundingToken,
		uint256 fundingGoal,
		uint256 fundingDeadline
	) public onlyOwner {
		_deployProject(fundingToken, fundingGoal, fundingDeadline);
	}
}
