// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "../housing-project/HousingProject.sol";
import "../main/SmartHousing.sol";
import "../lib/ProjectStorage.sol";

/**
 * @title ProjectFunding
 * @dev This contract is used for initializing and deploying housing projects.
 * It allows the deployment of a new housing project and manages project data.
 */
contract ProjectFunding is Ownable {
	using SafeMath for uint256;
	using ProjectStorage for mapping(uint256 => ProjectStorage.Data);

	address public coinbase; // Address authorized to initialize the first project
	address public smartHousingAddress; // Address of the SmartHousing contract

	mapping(uint256 => ProjectStorage.Data) public projects; // Mapping of project ID to ProjectData
	mapping(address => uint256) public projectsId; // Mapping of project address to project ID
	uint256 public projectCount; // Counter for the total number of projects

	mapping(uint256 => mapping(address => uint256)) public usersProjectDeposit;

	IERC20 public housingToken; // Token used for funding projects

	/**
	 * @dev Emitted when a new project is deployed.
	 * @param projectAddress Address of the newly deployed HousingProject contract.
	 */
	event ProjectDeployed(address indexed projectAddress);
	event ProjectFunded(
		uint256 indexed projectId,
		address indexed depositor,
		ERC20TokenPayment payment
	);

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
		HousingProject newProject = new HousingProject(smartHousingAddress);
		ProjectStorage.Data memory projectData = projects.createNew(
			projectsId,
			projectCount,
			fundingGoal,
			fundingDeadline,
			fundingToken,
			address(newProject)
		);
		projectCount = projectData.id;

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

	function fundProject(
		ERC20TokenPayment calldata depositPayment,
		uint256 projectId,
		uint256 referrerId
	) external payable {
		require(
			projectId > 0 && projectId <= projectCount,
			"Invalid project ID"
		);

		address depositor = msg.sender;

		// Register user with referrer (if needed)
		SmartHousing(smartHousingAddress).createRefIDViaProxy(
			depositor,
			referrerId
		);

		// Update project funding
		projects.fund(
			usersProjectDeposit[projectId],
			projectId,
			depositor,
			depositPayment
		);

		emit ProjectFunded(projectId, depositor, depositPayment);
	}
}
