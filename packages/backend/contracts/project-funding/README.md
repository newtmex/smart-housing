# ProjectFunding Contract

## Overview

The `ProjectFunding` contract is designed to manage and deploy housing projects, handle project funding, and distribute tokens within the SmartHousing ecosystem. It allows for project initialization, funding, and token management, as well as integration with other components of the ecosystem.

## Inheritance

- **Ownable**: Provides basic access control functions, where the contract owner has exclusive privileges to certain functions.

## Dependencies

- **SafeMath**: Provides arithmetic operations with overflow checks.
- **IERC20**: Interface for ERC20 tokens.
- **IERC1155**: Interface for ERC1155 tokens.
- **ProjectStorage**: Custom library for managing project data.
- **LkSHTAttributes**: Custom library for handling attributes of locked SmartHousing tokens.
- **TokenPayment**: Custom library for handling token payments.
- **NewHousingProject**: Library for deploying new housing projects.
- **HousingSFT**: Custom ERC1155 token for housing projects.
- **LockedSmartHousingToken**: Custom implementation of locked SmartHousing tokens (LkSHT).
- **SHT**: SmartHousing Token specifications.

## State Variables

- **coinbase**: Address authorized to initialize the first project.
- **smartHousingAddress**: Address of the SmartHousing contract.
- **projects**: Mapping of project ID to `ProjectStorage.Data` structure.
- **projectsId**: Mapping of project address to project ID.
- **projectCount**: Counter for the total number of projects.
- **usersProjectDeposit**: Mapping of user deposits per project.
- **housingToken**: Token used for funding projects (ERC20).
- **lkSht**: Instance of the locked SmartHousing Token (LkSHT).

## Events

- **ProjectDeployed**: Emitted when a new project is deployed.
- **ProjectFunded**: Emitted when a project is funded.
- **ProjectTokensClaimed**: Emitted when tokens are claimed for a project.

## Constructor

```solidity
constructor(address _coinbase) {
    coinbase = _coinbase;
    lkSht = NewLkSHT.create();
}
```

- **Parameters:**
  - `_coinbase`: Address authorized to initialize the first project.
- **Functionality:**
  - Initializes the `coinbase` address.
  - Creates an instance of the `LkSHT` contract.

## Functions

### `_deployProject`

```solidity
function _deployProject(
    string memory name,
    string memory symbol,
    address fundingToken,
    uint256 fundingGoal,
    uint256 fundingDeadline
) internal returns (address)
```

- **Parameters:**
  - `name`: Name of the project.
  - `symbol`: Symbol of the project.
  - `fundingToken`: Address of the ERC20 token used for funding.
  - `fundingGoal`: Funding goal for the new project.
  - `fundingDeadline`: Deadline for the project funding.
- **Returns:**
  - Address of the deployed project.
- **Functionality:**
  - Deploys a new `HousingProject` contract.
  - Creates a new `ProjectStorage.Data` entry for the project.
  - Updates `projectCount`.
  - Emits `ProjectDeployed` event.

### `initFirstProject`

```solidity
function initFirstProject(
    ERC20TokenPayment calldata shtPayment,
    string memory name,
    string memory symbol,
    address smartHousingAddress_,
    address fundingToken,
    uint256 fundingGoal,
    uint256 fundingDeadline
) external returns (address)
```

- **Parameters:**
  - `shtPayment`: Payment details for the SmartHousing Token (SHT).
  - `name`: Name of the first project.
  - `symbol`: Symbol of the first project.
  - `smartHousingAddress_`: Address of the SmartHousing contract.
  - `fundingToken`: Address of the ERC20 token used for funding.
  - `fundingGoal`: Funding goal for the new project.
  - `fundingDeadline`: Deadline for the project funding.
- **Returns:**
  - Address of the deployed project.
- **Functionality:**
  - Ensures that only the `coinbase` can call this function and that it can only be called once.
  - Receives ERC20 payment and sets the `housingToken`.
  - Sets the `smartHousingAddress`.
  - Deploys the first project using `_deployProject`.

### `deployProject`

```solidity
function deployProject(
    string memory name,
    string memory symbol,
    address fundingToken,
    uint256 fundingGoal,
    uint256 fundingDeadline
) public onlyOwner returns (address)
```

- **Parameters:**
  - `name`: Name of the project.
  - `symbol`: Symbol of the project.
  - `fundingToken`: Address of the ERC20 token used for funding.
  - `fundingGoal`: Funding goal for the new project.
  - `fundingDeadline`: Deadline for the project funding.
- **Returns:**
  - Address of the deployed project.
- **Functionality:**
  - Allows the contract owner to deploy new projects.
  - Uses `_deployProject` to create the new project.

### `fundProject`

```solidity
function fundProject(
    TokenPayment calldata depositPayment,
    uint256 projectId,
    uint256 referrerId
) external payable
```

- **Parameters:**
  - `depositPayment`: Payment details for the funding.
  - `projectId`: ID of the project to fund.
  - `referrerId`: ID of the referrer (if applicable).
- **Functionality:**
  - Validates the `projectId`.
  - Registers the user with a referrer via the SmartHousing contract.
  - Updates project funding and records the deposit.
  - Sets the amount raised in the project’s SFT.
  - Emits `ProjectFunded` event.

### `addProjectToEcosystem`

```solidity
function addProjectToEcosystem(uint256 projectId) external onlyOwner
```

- **Parameters:**
  - `projectId`: ID of the project to add.
- **Functionality:**
  - Adds the project to the SmartHousing ecosystem.
  - Uses the SmartHousing contract to add the project.

### `claimProjectTokens`

```solidity
function claimProjectTokens(uint256 projectId) external
```

- **Parameters:**
  - `projectId`: ID of the project to claim tokens from.
- **Functionality:**
  - Retrieves the deposit amount for the project.
  - Mints SFT tokens for the depositor.
  - Mints LkSHT tokens if the project ID is 1.
  - Emits `ProjectTokensClaimed` event.

### `unlockSHT`

```solidity
function unlockSHT(uint256 nonce) external returns (uint256 newNonce)
```

- **Parameters:**
  - `nonce`: Nonce of the LkSHT token to unlock.
- **Returns:**
  - `newNonce`: Updated nonce for the LkSHT token.
- **Functionality:**
  - Checks the balance of LkSHT tokens for the caller.
  - Unlocks matured SHT tokens.
  - Updates the LkSHT token with new attributes and nonce.
  - Transfers unlocked SHT tokens to the user.

### `allProjects`

```solidity
function allProjects() public view returns (ProjectStorage.Data[] memory)
```

- **Returns:**
  - An array of `ProjectStorage.Data` structs representing all projects.
- **Functionality:**
  - Returns an array of all project details.

### `getProjectAddress`

```solidity
function getProjectAddress(uint256 projectId) public view returns (address projectAddress)
```

- **Parameters:**
  - `projectId`: ID of the project.
- **Returns:**
  - Address of the HousingProject contract for the given project ID.
- **Functionality:**
  - Validates the `projectId`.
  - Returns the address of the project.

### `getProjectData`

```solidity
function getProjectData(uint256 projectId) public view returns (ProjectStorage.Data memory projectData)
```

- **Parameters:**
  - `projectId`: ID of the project.
- **Returns:**
  - `projectData`: Data struct containing detailed information about the project.
- **Functionality:**
  - Validates the `projectId`.
  - Returns detailed information about the project.

