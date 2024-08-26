# Coinbase Contract

## Overview

The `Coinbase` contract is used to manage the initial coin offering (ICO) for housing projects within the SmartHousing ecosystem. It inherits functionality from `Ownable` and `SHTModule`, and is responsible for starting the ICO, approving project funding, and dispatching ecosystem funds.

## Inheritance

- **Ownable**: Provides basic authorization control functions, simplifying the implementation of user permissions.
- **SHTModule**: Includes functionalities related to the SmartHousingToken (SHT), such as token management and payments.

## Constructor

```solidity
constructor() ERC20("SmartHousingToken", "SHT") {
    _mint(address(this), SHT.MAX_SUPPLY);
}
```

- **Functionality:**
  - Initializes the contract with the ERC20 token named "SmartHousingToken" and symbol "SHT".
  - Mints the maximum supply of SHT tokens to the contract's address.

## Functions

### `startICO`

```solidity
function startICO(
    string memory name,
    string memory symbol,
    address projectFundingAddr,
    address smartHousingAddress,
    address fundingToken,
    uint256 fundingGoal,
    uint256 fundingDeadline
) external onlyOwner returns (address)
```

- **Parameters:**
  - `name`: The name of the new housing project.
  - `symbol`: The symbol of the new housing project's token.
  - `projectFundingAddr`: Address of the `ProjectFunding` contract where the ICO funds will be sent.
  - `smartHousingAddress`: Address of the `SmartHousing` contract.
  - `fundingToken`: Address of the ERC20 token used for funding.
  - `fundingGoal`: The funding goal for the new project.
  - `fundingDeadline`: The deadline for the project funding.

- **Returns:**
  - Address of the newly initialized project.

- **Functionality:**
  - Creates an `ERC20TokenPayment` structure with the ICO funds using `_makeSHTPayment`.
  - Approves the `ProjectFunding` contract to spend the ICO funds.
  - Initializes the first housing project through the `ProjectFunding` contract using the provided parameters.

### `feedSmartHousing`

```solidity
function feedSmartHousing(address smartHousingAddr) external onlyOwner
```

- **Parameters:**
  - `smartHousingAddr`: Address of the `SmartHousing` contract.

- **Functionality:**
  - Dispatches ecosystem funds to the `SmartHousing` contract if not already dispatched.
  - Creates an `ERC20TokenPayment` structure with the ecosystem distribution funds using `_makeSHTPayment`.
  - Approves the `SmartHousing` contract to spend the ecosystem funds.
  - Sets up the SHT distribution in the `SmartHousing` contract.

## Internal Functions

### `_makeSHTPayment`

- **Returns:**
  - An `ERC20TokenPayment` structure containing payment details.
- **Functionality:**
  - Creates and returns a payment structure with SHT tokens.

### `_approve`

```solidity
function _approve(address owner, address spender, uint256 amount)
```

- **Parameters:**
  - `owner`: Address of the token owner.
  - `spender`: Address of the spender (contract to approve).
  - `amount`: Amount of tokens to approve.

- **Functionality:**
  - Approves the specified spender to spend the given amount of tokens on behalf of the owner.