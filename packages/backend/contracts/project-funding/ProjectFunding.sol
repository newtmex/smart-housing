// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "../lib/ProjectStorage.sol";
import "../lib/LkSHTAttributes.sol";

import "../main/Interface.sol";

import "../housing-project/HousingProject.sol";
import "../modules/LockedSmartHousingToken.sol";
import "../modules/sht-module/SHT.sol";

import { TokenPayment } from "../lib/TokenPayments.sol";

/**
 * @title ProjectFunding
 * @dev This contract is used for initializing and deploying housing projects.
 * It allows the deployment of a new housing project and manages project data.
 */
contract ProjectFunding is Ownable {
	using SafeMath for uint256;
	using ProjectStorage for mapping(uint256 => ProjectStorage.Data);
	using ProjectStorage for ProjectStorage.Data;
	using LkSHTAttributes for LkSHTAttributes.Attributes;

	address public coinbase; // Address authorized to initialize the first project
	address public smartHousingAddress; // Address of the SmartHousing contract

	mapping(uint256 => ProjectStorage.Data) public projects; // Mapping of project ID to ProjectData
	mapping(address => uint256) public projectsId; // Mapping of project address to project ID
	uint256 public projectCount; // Counter for the total number of projects

	mapping(uint256 => mapping(address => uint256)) public usersProjectDeposit;

	IERC20 public housingToken; // Token used for funding projects
	LkSHT public lkSht; // The locked version

	/**
	 * @dev Emitted when a new project is deployed.
	 * @param projectAddress Address of the newly deployed HousingProject contract.
	 */
	event ProjectDeployed(address indexed projectAddress);
	event ProjectFunded(
		uint256 indexed projectId,
		address indexed depositor,
		TokenPayment payment
	);
	event ProjectTokensClaimed(
		address indexed depositor,
		uint256 projectId,
		uint256 amount
	);

	/**
	 * @param _coinbase Address authorized to initialize the first project.
	 */
	constructor(address _coinbase) {
		coinbase = _coinbase;
		lkSht = NewLkSHT.create();
	}

	/**
	 * @dev Internal function to deploy a new HousingProject contract.
	 * @param fundingToken Address of the ERC20 token used for funding.
	 * @param fundingGoal The funding goal for the new project.
	 * @param fundingDeadline The deadline for the project funding.
	 */
	function _deployProject(
		string memory name,
		string memory symbol,
		address fundingToken,
		uint256 fundingGoal,
		uint256 fundingDeadline
	) internal {
		HousingProject newProject = new HousingProject(
			name,
			symbol,
			smartHousingAddress
		);
		ProjectStorage.Data memory projectData = projects.createNew(
			projectsId,
			projectCount,
			fundingGoal,
			fundingDeadline,
			fundingToken,
			address(newProject),
			address(newProject.projectSFT())
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
		string memory name,
		string memory symbol,
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

		_deployProject(
			name,
			symbol,
			fundingToken,
			fundingGoal,
			fundingDeadline
		);
	}

	/**
	 * @dev Deploys a new project.
	 * This function can be called multiple times to deploy additional projects.
	 * @param fundingToken Address of the ERC20 token used for funding.
	 * @param fundingGoal The funding goal for the new project.
	 * @param fundingDeadline The deadline for the project funding.
	 */
	function deployProject(
		string memory name,
		string memory symbol,
		address fundingToken,
		uint256 fundingGoal,
		uint256 fundingDeadline
	) public onlyOwner {
		_deployProject(
			name,
			symbol,
			fundingToken,
			fundingGoal,
			fundingDeadline
		);
	}

	function fundProject(
		TokenPayment calldata depositPayment,
		uint256 projectId,
		uint256 referrerId
	) external payable {
		require(
			projectId > 0 && projectId <= projectCount,
			"Invalid project ID"
		);

		address depositor = msg.sender;

		// Register user with referrer (if needed)
		ISmartHousing(smartHousingAddress).createRefIDViaProxy(
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

	function setProjectToken(uint256 projectId) external onlyOwner {
		ProjectStorage.Data storage project = projects[projectId];
		require(
			project.status() == ProjectStorage.Status.Successful,
			"Project Funding not yet successful"
		);

		ISmartHousing(smartHousingAddress).addProject(project.projectAddress);

		address tokenAddress = HousingProject(project.projectAddress)
			.setTokenDetails(project.collectedFunds, smartHousingAddress);

		project.tokenAddress = tokenAddress;
	}

	/**
	 * @dev Claims project tokens for a given project ID.
	 * @param projectId The ID of the project to claim tokens from.
	 */
	function claimProjectTokens(uint256 projectId) external {
		address depositor = msg.sender;

		// Retrieve the project and deposit amount
		(ProjectStorage.Data memory project, uint256 depositAmount) = projects
			.takeDeposit(usersProjectDeposit[projectId], projectId, depositor);

		HousingSFT(project.tokenAddress).mintSFT(
			depositAmount,
			depositor,
			project.collectedFunds
		);

		// Mint LkSHT tokens if the project ID is 1
		if (project.id == 1) {
			uint256 shtAmount = depositAmount.mul(SHT.ICO_FUNDS).div(
				project.collectedFunds
			);

			lkSht.mint(shtAmount, depositor);
		}

		emit ProjectTokensClaimed(depositor, projectId, depositAmount);
	}

	function unlockSHT(uint256 nonce) external {
		address caller = msg.sender;

		uint256 lkShtBal = lkSht.balanceOf(caller, nonce);
		require(lkShtBal > 0, "ProjectFunding: Nothing to unlock");

		LkSHTAttributes.Attributes memory attr = abi.decode(
			lkSht.getRawTokenAttributes(nonce),
			(LkSHTAttributes.Attributes)
		);
		(
			uint256 totalUnlockedAmount,
			LkSHTAttributes.Attributes memory newAttr
		) = attr.unlockMatured();

		lkSht.update(
			caller,
			nonce,
			lkShtBal.sub(totalUnlockedAmount),
			abi.encode(newAttr)
		);

		// Transfer the total unlocked SHT tokens to the user's address
		if (totalUnlockedAmount > 0) {
			housingToken.transfer(caller, totalUnlockedAmount);
		}
	}

	/**
	 * @dev Returns an array of all project IDs and their associated data.
	 * @return projectList An array of tuples containing project details.
	 */
	function allProjects() public view returns (ProjectStorage.Data[] memory) {
		ProjectStorage.Data[] memory projectList = new ProjectStorage.Data[](
			projectCount
		);

		for (uint256 i = 1; i <= projectCount; i++) {
			projectList[i - 1] = projects[i];
		}

		return projectList;
	}

	/**
	 * @dev Returns the address of the HousingProject contract for a given project ID.
	 * @param projectId The ID of the project.
	 * @return projectAddress The address of the HousingProject contract.
	 */
	function getProjectAddress(
		uint256 projectId
	) external view returns (address projectAddress) {
		ProjectStorage.Data storage project = projects[projectId];
		return project.projectAddress;
	}

	/**
	 * @dev Returns the details of a project by its ID.
	 * @param projectId The ID of the project.
	 * @return id The project ID.
	 * @return fundingGoal The funding goal of the project.
	 * @return fundingDeadline The deadline for the project funding.
	 * @return fundingToken The address of the ERC20 token used for funding.
	 * @return projectAddress The address of the HousingProject contract.
	 * @return status The funding status of the project.
	 * @return collectedFunds The amount of funds collected.
	 */
	function getProjectData(
		uint256 projectId
	)
		external
		view
		returns (
			uint256 id,
			uint256 fundingGoal,
			uint256 fundingDeadline,
			address fundingToken,
			address projectAddress,
			uint8 status,
			uint256 collectedFunds
		)
	{
		ProjectStorage.Data storage project = projects[projectId];
		return (
			project.id,
			project.fundingGoal,
			project.fundingDeadline,
			project.fundingToken,
			project.projectAddress,
			uint8(project.status()),
			project.collectedFunds
		);
	}
}
