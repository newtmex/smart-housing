# HousingProject Contract

## Overview

The `HousingProject` contract is part of the SmartHousing ecosystem and manages unique real estate projects. It inherits functionality from `RentsModule`, `Ownable`, and `CallsSmartHousing`, and is designed to handle rent payments, distribute rewards, and manage project-specific operations.

## Inheritance

- **RentsModule**: Provides functions for managing rent payments and rewards.
- **Ownable**: Provides basic authorization control functions, simplifying the implementation of user permissions.
- **CallsSmartHousing**: Enables interaction with the main SmartHousing contract.

## State Variables

- `uint256 public maxSupply`: The maximum supply of the HousingSFT token, initialized during contract deployment.
- `uint256 public rewardsReserve`: The reserve of rewards available for distribution.
- `uint256 public rewardPerShare`: The amount of reward per share for the HousingSFT token.
- `uint256 public totalRewardsCollected`: Total rewards collected from rent payments.
- `uint256 public totalRewardsGenerated`: Total rewards generated through the reward calculation process.
- `uint256 public rewardsAPR`: Annual Percentage Rate of rewards, calculated based on collected and generated rewards.
- `uint256 public lastRewardGenerateTimestamp`: Timestamp of the last reward generation.
- `uint256 public endRewardGenerateTimestamp`: Timestamp when the current reward generation period ends.
- `uint256 public facilityManagementFunds`: Funds allocated for facility management.

## Constants

- `uint256 public constant REWARD_PERCENT = 75`: Percentage of rent allocated to rewards.
- `uint256 public constant ECOSYSTEM_PERCENT = 18`: Percentage of rent allocated to ecosystem rewards.
- `uint256 public constant FACILITY_PERCENT = 7`: Percentage of rent allocated to facility management.

## Immutable Variables

- `HousingSFT public immutable projectSFT`: Instance of the HousingSFT token associated with the project.
- `ERC20Burnable public immutable housingToken`: Instance of the ERC20 token used for rent payments and rewards.

## Constructor

```solidity
constructor(
    string memory name,
    string memory symbol,
    address smartHousingAddr,
    address housingTokenAddr
) CallsSmartHousing(smartHousingAddr) {
    projectSFT = new HousingSFT(name, symbol);
    maxSupply = projectSFT.getMaxSupply();
    housingToken = ERC20Burnable(housingTokenAddr);
}
```

- **Parameters:**
  - `name`: The name of the HousingSFT token.
  - `symbol`: The symbol of the HousingSFT token.
  - `smartHousingAddr`: Address of the main SmartHousing contract.
  - `housingTokenAddr`: Address of the ERC20 token used for rent payments.

## Functions

### `receiveRent`

```solidity
function receiveRent(ERC20TokenPayment calldata rentPayment) external
```

- **Parameters:**
  - `rentPayment`: Details of the rent payment including token and amount.
- **Functionality:**
  - Receives rent payments in ERC20 tokens.
  - Validates the payment and token.
  - Calculates rewards and updates attributes:
    - Rent rewards: 75% of the rent amount.
    - Ecosystem rewards: 18% of the rent amount (burned).
    - Facility management funds: 7% of the rent amount.
  - Updates reward generation timestamps and calculations.
  - Notifies the SmartHousing contract of the received rent.

### `_generateRewards`

```solidity
function _generateRewards()
    internal
    view
    returns (uint256 generatedRewards, uint256 rpsIncrement)
```

- **Returns:**
  - `generatedRewards`: Total rewards generated during the elapsed time.
  - `rpsIncrement`: Increment to be added to `rewardPerShare`.
- **Functionality:**
  - Calculates the rewards generated based on the elapsed time since the last generation.
  - Ensures that the total generated rewards do not exceed the collected rewards.

### `claimRentReward`

```solidity
function claimRentReward(
    uint256 nonce
) external
    returns (
        HousingAttributes memory attr,
        rewardshares memory rewardShares,
        uint256 newNonce
    )
```

- **Parameters:**
  - `nonce`: The nonce of the token for which rewards are being claimed.
- **Returns:**
  - `attr`: Updated HousingAttributes of the user.
  - `rewardShares`: Computed reward shares for the user.
  - `newNonce`: New nonce after updating the token.
- **Functionality:**
  - Generates rewards and updates `rewardPerShare`.
  - Calculates user rewards and updates user attributes.
  - Transfers or burns referrer rewards.
  - Updates the HousingSFT token and transfers rewards to the user.

### `_min`

```solidity
function _min(uint256 a, uint256 b) private pure returns (uint256)
```

- **Parameters:**
  - `a`: First value.
  - `b`: Second value.
- **Returns:**
  - Minimum of `a` and `b`.
- **Functionality:**
  - A helper function to determine the minimum of two values.

### `getMaxSupply`

```solidity
function getMaxSupply() external view returns (uint256)
```

- **Returns:**
  - Maximum supply of the HousingSFT token.
- **Functionality:**
  - Retrieves the maximum supply of the HousingSFT token.

### `rentClaimable`

```solidity
function rentClaimable(HousingAttributes memory attr) public view returns (uint256)
```

- **Parameters:**
  - `attr`: The attributes of the token.
- **Returns:**
  - Amount of rent claimable.
- **Functionality:**
  - Calculates the claimable rent based on the user's attributes and current reward settings.
