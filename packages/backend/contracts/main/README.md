## SmartHousing Contract Technical Documentation

### Overview

**SmartHousing** is a contract designed to enable the tokenization of real estate for fractional ownership and investment. It is the main contract of the SmartHousing ecosystem and manages housing projects, users, and staking operations. The contract integrates with various modules, including token payments, project funding, and housing staking.

### Contract Interfaces

- **Ownable**: Provides ownership control and permissions.
- **ERC1155Holder**: Allows the contract to receive ERC1155 tokens.
- **UserModule**: Manages user-related functions.

### Contract Variables

- **Addresses**
  - `projectFundingAddress`: Address of the ProjectFunding contract.
  - `coinbaseAddress`: Address of the coinbase.
  - `shtTokenAddress`: Address of the SHT token.
- **Contracts**

  - `hst`: Instance of `HousingStakingToken`.
  - `lkSht`: Instance of `LockedSmartHousingToken` from the ProjectFunding contract.

- **Storage**

  - `distributionStorage`: Storage for distribution-related data.
  - `epochs`: Storage for epoch-related data.

- **Mappings**
  - `permissions`: Maps addresses to their permissions.
  - `_projectsToken`: Enumerable set of project SFT addresses.

### Constructor

```solidity
constructor(address coinbase, address projectFunding)
```

- Initializes the SmartHousing contract with addresses for the coinbase and ProjectFunding.
- Creates instances of `HousingStakingToken` and `LockedSmartHousingToken`.
- Initializes the epochs with a 30-minute interval for testing.

### Functions

#### `createRefIDViaProxy`

```solidity
function createRefIDViaProxy(address userAddr, uint256 referrerId) external onlyProjectFunding returns (uint256)
```

- **Description**: Registers a new user or retrieves the referral ID if the user is already registered.
- **Parameters**:
  - `userAddr`: Address of the user.
  - `referrerId`: Referral ID of the referrer.
- **Returns**: User ID.

#### `setUpSHT`

```solidity
function setUpSHT(ERC20TokenPayment calldata payment) external
```

- **Description**: Sets up the SHT token and distributes funds.
- **Parameters**:
  - `payment`: Token payment details for setting up SHT.
- **Requirements**: Only callable by the coinbase address. The SHT token must not be previously set, and the payment amount must match the expected ecosystem distribution funds.

#### `addProject`

```solidity
function addProject(address projectAddress) external onlyProjectFunding
```

- **Description**: Adds a new project and sets its permissions.
- **Parameters**:
  - `projectAddress`: Address of the new project.

#### `addProjectRent`

```solidity
function addProjectRent(uint256 amount) external onlyHousingProject
```

- **Description**: Adds rent to a project and updates the distribution storage.
- **Parameters**:
  - `amount`: Amount of rent received.

#### `stake`

```solidity
function stake(TokenPayment[] calldata stakingTokens, uint256 epochsLock, uint256 referrerId) external
```

- **Description**: Allows users to stake tokens for rewards.
- **Parameters**:
  - `stakingTokens`: Array of token payments for staking.
  - `epochsLock`: Lock period in epochs.
  - `referrerId`: Referral ID of the referrer.

#### `userCanClaim`

```solidity
function userCanClaim(address user, uint256 tokenNonce) public view returns (bool)
```

- **Description**: Checks if a user can claim rewards.
- **Parameters**:
  - `user`: Address of the user.
  - `tokenNonce`: Nonce of the token.
- **Returns**: `true` if the user can claim rewards, otherwise `false`.

#### `claimRewards`

```solidity
function claimRewards(uint256 hstNonce, uint256 referrerId) external returns (uint256 newHstNonce)
```

- **Description**: Claims rewards and updates token attributes.
- **Parameters**:
  - `hstNonce`: Nonce of the HST token.
  - `referrerId`: Referral ID of the referrer.
- **Returns**: New HST nonce.

#### `projectDets`

```solidity
function projectDets(address project) public view returns (Distribution.ProjectDistributionData memory)
```

- **Description**: Retrieves project distribution details.
- **Parameters**:
  - `project`: Address of the project.
- **Returns**: Project distribution data.

#### `projectsToken`

```solidity
function projectsToken() public view returns (address[] memory)
```

- **Description**: Retrieves the list of project token addresses.
- **Returns**: Array of project token addresses.

### Internal Functions

#### `_setPermissions`

```solidity
function _setPermissions(address addr, Permissions perm) internal
```

- **Description**: Sets permissions for an address.
- **Parameters**:
  - `addr`: Address to set permissions for.
  - `perm`: Permissions to set.

#### `_prepareProjectTokensAndLkShtNonces`

```solidity
function _prepareProjectTokensAndLkShtNonces(TokenPayment[] calldata payments, address lkShtAddress)
    internal view returns (TokenPayment[] memory projectTokens, uint256[] memory lkShtNonces)
```

- **Description**: Prepares project tokens and LkSHT for staking.
- **Parameters**:
  - `payments`: Array of tokens to prepare.
  - `lkShtAddress`: Address of the LkSHT token.
- **Returns**: Project tokens and LkSHT nonces.

#### `_mintHstToken`

```solidity
function _mintHstToken(TokenPayment[] calldata payments, uint256 projectsShareCheckpoint, uint256 shtRewardPerShare, uint256 epochsLock, address lkShtAddress)
    internal returns (HstAttributes memory)
```

- **Description**: Mints an HST token.
- **Parameters**:
  - `payments`: Array of tokens to mint.
  - `projectsShareCheckpoint`: Checkpoint for project shares.
  - `shtRewardPerShare`: Reward per share for SHT.
  - `epochsLock`: Number of epochs to lock.
  - `lkShtAddress`: Address of the LkSHT token.
- **Returns**: Attributes of the new HST token.

### Modifiers

#### `onlyProjectFunding`

- **Description**: Restricts function access to the ProjectFunding address.

#### `onlyHousingProject`

- **Description**: Restricts function access to addresses with the HousingProject permission.
