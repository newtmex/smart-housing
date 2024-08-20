// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

import "../lib/ProjectStorage.sol";
import "../lib/LkSHTAttributes.sol";

import "../main/Interface.sol";

import "../modules/LockedSmartHousingToken.sol";
import "../modules/sht-module/SHT.sol";

import { HousingSFT } from "../housing-project/HousingSFT.sol";
import { TokenPayment } from "../lib/TokenPayments.sol";
import { NewHousingProject, HousingProject } from "../housing-project/NewHousingProjectLib.sol";

/// @title ProjectFunding
/// @dev Manages and deploys housing projects, handles funding, and distributes tokens.
contract ProjectFunding is Ownable {
	using SafeMath for uint256;
	using ProjectStorage for mapping(uint256 => ProjectStorage.Data);
	using ProjectStorage for ProjectStorage.Data;
	using LkSHTAttributes for LkSHTAttributes.Attributes;

	// State variables
	address public coinbase; // Address authorized to initialize the first project
	address public smartHousingAddress; // Address of the SmartHousing contract
	mapping(uint256 => ProjectStorage.Data) public projects; // Mapping of project ID to ProjectData
	mapping(address => uint256) public projectsId; // Mapping of project address to project ID
	uint256 public projectCount; // Counter for the total number of projects
	mapping(uint256 => mapping(address => uint256)) public usersProjectDeposit; // User deposits per project
	IERC20 public housingToken; // Token used for funding projects
	LkSHT public lkSht; // Instance of the locked SmartHousing Token (LkSHT)

	// Events
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

	/// @param _coinbase Address authorized to initialize the first project
	constructor(address _coinbase) {
		coinbase = _coinbase;
		lkSht = NewLkSHT.create();
	}

	/// @dev Internal function to deploy a new HousingProject contract
	/// @param name Name of the project
	/// @param symbol Symbol of the project
	/// @param fundingToken Address of the ERC20 token used for funding
	/// @param fundingGoal The funding goal for the new project
	/// @param fundingDeadline The deadline for the project funding
	function _deployProject(
		string memory name,
		string memory symbol,
		address fundingToken,
		uint256 fundingGoal,
		uint256 fundingDeadline
	) internal returns (address) {
		HousingProject newProject = NewHousingProject.deployHousingProject(
			name,
			symbol,
			smartHousingAddress,
			coinbase
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

		return projectData.projectAddress;
	}

	/// @dev Initializes the first project
	/// This function must be called by the coinbase address and can only be called once
	/// @param shtPayment Payment details for the Smart Housing Token (SHT)
	/// @param name Name of the first project
	/// @param symbol Symbol of the first project
	/// @param smartHousingAddress_ Address of the Smart Housing contract
	/// @param fundingToken Address of the ERC20 token used for funding
	/// @param fundingGoal The funding goal for the new project
	/// @param fundingDeadline The deadline for the project funding
	function initFirstProject(
		ERC20TokenPayment calldata shtPayment,
		string memory name,
		string memory symbol,
		address smartHousingAddress_,
		address fundingToken,
		uint256 fundingGoal,
		uint256 fundingDeadline
	) external returns (address) {
		require(msg.sender == coinbase, "Caller is not the coinbase");
		require(projectCount == 0, "Project already initialized");

		TokenPayments.receiveERC20(shtPayment);
		housingToken = shtPayment.token;

		smartHousingAddress = smartHousingAddress_;

		return
			_deployProject(
				name,
				symbol,
				fundingToken,
				fundingGoal,
				fundingDeadline
			);
	}

	/// @dev Deploys a new project
	/// This function can be called multiple times to deploy additional projects
	/// @param name Name of the project
	/// @param symbol Symbol of the project
	/// @param fundingToken Address of the ERC20 token used for funding
	/// @param fundingGoal The funding goal for the new project
	/// @param fundingDeadline The deadline for the project funding
	function deployProject(
		string memory name,
		string memory symbol,
		address fundingToken,
		uint256 fundingGoal,
		uint256 fundingDeadline
	) public onlyOwner returns (address) {
		return
			_deployProject(
				name,
				symbol,
				fundingToken,
				fundingGoal,
				fundingDeadline
			);
	}

	/// @dev Allows users to fund a project
	/// @param depositPayment Payment details for the funding
	/// @param projectId ID of the project to fund
	/// @param referrerId ID of the referrer (if applicable)
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
		uint256 totalCollected = projects.fund(
			usersProjectDeposit[projectId],
			projectId,
			depositor,
			depositPayment
		);

		// Set the amount raised in the project SFT
		HousingSFT projectSFT = HousingSFT(
			getProjectData(projectId).tokenAddress
		);
		projectSFT.setAmountRaised(totalCollected);

		emit ProjectFunded(projectId, depositor, depositPayment);
	}

	/// @dev Sets the project once funding is successful
	/// @param projectId ID of the project
	function addProjectToEcosystem(uint256 projectId) external onlyOwner {
		ProjectStorage.Data storage project = projects[projectId];

		ISmartHousing(smartHousingAddress).addProject(project.projectAddress);
	}

	/// @dev Claims project tokens for a given project ID
	/// @param projectId ID of the project to claim tokens from
	function claimProjectTokens(uint256 projectId) external {
		address depositor = msg.sender;

		// Retrieve the project and deposit amount
		(ProjectStorage.Data memory project, uint256 depositAmount) = projects
			.takeDeposit(usersProjectDeposit[projectId], projectId, depositor);

		HousingSFT(project.tokenAddress).mintSFT(depositAmount, depositor);

		// Mint LkSHT tokens if the project ID is 1
		if (project.id == 1) {
			uint256 shtAmount = depositAmount.mul(SHT.ICO_FUNDS).div(
				project.collectedFunds
			);

			lkSht.mint(shtAmount, depositor);
		}

		emit ProjectTokensClaimed(depositor, projectId, depositAmount);
	}

	/// @dev Unlocks SHT tokens by updating the nonce and transferring unlocked tokens to the user
	/// @param nonce Nonce of the LkSHT token to unlock
	/// @return newNonce New nonce for the updated LkSHT token
	function unlockSHT(uint256 nonce) external returns (uint256 newNonce) {
		address caller = msg.sender;

		uint256 lkShtBal = lkSht.balanceOf(caller, nonce);
		require(lkShtBal > 0, "ProjectFunding: Nothing to unlock");

		LkSHTAttributes.Attributes memory attr = lkSht.getAttribute(nonce);
		(
			uint256 totalUnlockedAmount,
			LkSHTAttributes.Attributes memory newAttr
		) = attr.unlockMatured();

		newNonce = lkSht.update(
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

	/// @dev Returns an array of all project IDs and their associated data
	/// @return projectList An array of tuples containing project details
	function allProjects() public view returns (ProjectStorage.Data[] memory) {
		ProjectStorage.Data[] memory projectList = new ProjectStorage.Data[](
			projectCount
		);

		for (uint256 i = 1; i <= projectCount; i++) {
			projectList[i - 1] = projects[i];
		}

		return projectList;
	}

	/// @dev Returns the address of the HousingProject contract for a given project ID
	/// @param projectId ID of the project
	/// @return projectAddress Address of the HousingProject contract
	function getProjectAddress(
		uint256 projectId
	) public view returns (address projectAddress) {
		require(
			projectId > 0 && projectId <= projectCount,
			"Invalid project ID"
		);
		projectAddress = projects[projectId].projectAddress;
	}

	/// @dev Returns detailed information about a project by its ID
	/// @param projectId ID of the project
	/// @return projectData Project data struct
	function getProjectData(
		uint256 projectId
	) public view returns (ProjectStorage.Data memory projectData) {
		require(
			projectId > 0 && projectId <= projectCount,
			"Invalid project ID"
		);
		projectData = projects[projectId];
	}
}
