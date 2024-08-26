# SmartHousing

## Overview

### Challenges in Nigeria's Real Estate Market

Nigeria faces a significant housing deficit, with a need for 550,000 housing units annually and an estimated cost of N5.5 trillion over the next decade. This shortage presents a challenge for both low-income earners and developers, with high costs and limited access to real estate investments. The traditional real estate market is characterized by:

-   **High Entry Costs:** The large capital required for property investment limits participation to wealthy individuals and institutions.
-   **Limited Liquidity:** Real estate investments are often illiquid, making it difficult for investors to access funds quickly.
-   **Inefficient Development Funding:** Developers struggle with securing timely funding for affordable housing projects.

### SmartHousing Solution

SmartHousing aims to address these challenges through Real World Asset Tokenization, leveraging blockchain technology to:

-   **Enable Fractional Ownership:** By tokenizing properties, SmartHousing allows individuals to own fractions of real estate assets, making it accessible to low-income earners.
-   **Provide Liquidity to Developers:** The platform offers developers immediate access to liquid funds through token sales, facilitating timely and quality completion of projects.
-   **Democratize Real Estate Investment:** By lowering the entry barriers, SmartHousing makes real estate investments more inclusive and accessible.

![Dashboard View](dashboard.png)
_Dashboard View_

![Properties View](properties.png)
_Properties View_

## Key Features

### Tokenization

SmartHousing utilizes blockchain technology to tokenize real estate properties. This process involves:

-   **Fractional Ownership:** Properties are divided into tokens, each representing a share of the property. Investors can buy and trade these tokens, thereby owning a fraction of the property.
-   **Ease of Investment:** Tokenization reduces the capital required for investment, allowing broader participation in real estate.

### Native Tokens

SmartHousing employs a native token, the SmartHousing Token (SHT), which serves multiple purposes:

-   **Utility Token:** Used for transactions within the platform, including buying property tokens and participating in governance.
-   **Staking and Rewards:** Token holders can stake SHT to earn rewards and participate in the platform's governance.

### Staking

-   **Staking Mechanism:** Users can stake their SHT tokens to earn rewards and gain voting power in governance decisions.
-   **Rewards:** Staking rewards are distributed based on the amount and duration of tokens staked.

### Referral System

-   **Referral Rewards:** Users can earn rewards by referring new investors to the platform. The referral system incentivizes the growth of the SmartHousing community.
-   **Tracking and Bonuses:** Referrals are tracked through unique referral codes, and bonuses are awarded based on the investments made by referred users.

## Impact

### Economic Benefits

-   **Increased Accessibility:** By fractionalizing property ownership, SmartHousing opens up real estate investment to a broader audience, including those with lower capital.
-   **Enhanced Liquidity:** The tokenization of real estate provides a more liquid investment option, allowing investors to buy, sell, and trade property tokens easily.
-   **Accelerated Development:** Developers gain quicker access to funding, promoting the timely completion of affordable housing projects.

### Social Benefits

-   **Affordable Housing:** The platform supports the development of affordable housing, addressing the housing shortage in Nigeria.
-   **Community Engagement:** The referral system and staking mechanisms foster a strong, engaged community of investors and stakeholders.

## Architecture

The SmartHousing ecosystem architecture integrates several key components: the `SmartHousingToken`, `ProjectFunding`, `Coinbase`, and `HousingProject` contracts. Here’s a detailed breakdown of how these components interact within the ecosystem.

### 1. SmartHousingToken (SHT) Contract

#### Purpose

The `SmartHousingToken` contract is the native token of the SmartHousing ecosystem. It facilitates transactions, staking, and participation in governance within the platform.

#### Key Functions

-   **mint(address to, uint256 amount):** Issues new SHT tokens to a specified address. This function is used to distribute tokens for various purposes, including rewards and initial allocations.
-   **transfer(address to, uint256 amount):** Transfers SHT tokens between users, enabling liquidity and transactions within the ecosystem.
-   **stake(uint256 amount):** Allows users to stake SHT tokens, earning rewards and gaining voting power in ecosystem governance.

#### Integration

The SHT contract is integral to user interaction, providing the means for investment, rewards, and governance. It interacts with other contracts to facilitate staking rewards and manage token distribution.

### 2. ProjectFunding Contract

#### Purpose

The `ProjectFunding` contract manages the deployment of housing projects, funding processes, and distribution of tokens related to project investments.

#### Key Functions

-   **initFirstProject(ERC20TokenPayment calldata shtPayment, string memory name, string memory symbol, address smartHousingAddress\_, address fundingToken, uint256 fundingGoal, uint256 fundingDeadline):** Initializes the first housing project and sets up the SmartHousing ecosystem.
-   **deployProject(string memory name, string memory symbol, address fundingToken, uint256 fundingGoal, uint256 fundingDeadline):** Deploys additional housing projects.
-   **fundProject(TokenPayment calldata depositPayment, uint256 projectId, uint256 referrerId):** Allows users to fund a specific project, with options for referral rewards.
-   **addProjectToEcosystem(uint256 projectId):** Adds a project to the ecosystem after successful funding.
-   **claimProjectTokens(uint256 projectId):** Allows users to claim tokens based on their investment in a project.

#### Integration

The `ProjectFunding` contract coordinates the deployment of new projects, manages investments, and handles token claims. It interacts with the `HousingProject` contract to manage project details and with the `SmartHousingToken` for token distribution and staking.

### 3. Coinbase Contract

#### Purpose

The `Coinbase` contract is responsible for initializing the ecosystem. It sets up the first project and is typically used to configure the SmartHousing platform.

#### Key Functions

-   **initFirstProject():** This function is usually called by the `Coinbase` address to set up the initial project and configure the `ProjectFunding` contract with necessary parameters.

#### Integration

The `Coinbase` contract interacts with the `ProjectFunding` contract to deploy the initial housing project and configure the ecosystem. It ensures that the first project is correctly initialized before additional projects can be deployed.

### 4. HousingProject Contract

#### Purpose

The `HousingProject` contract manages individual real estate projects. Each project can be deployed, funded, and tokenized through this contract.

#### Key Functions

-   **deployHousingProject(string memory name, string memory symbol, address smartHousingAddress, address coinbase):** Deploys a new housing project, creating a new instance of the project within the ecosystem.
-   **fund(uint256 projectId, address depositor, TokenPayment depositPayment):** Accepts funding for a specific project from users.
-   **mintSFT(uint256 depositAmount, address depositor):** Mints SFT (SmartHousing Tokens) for investors based on their funding amount.

#### Integration

The `HousingProject` contract interacts with the `ProjectFunding` contract for deployment and funding. It also works with the `SmartHousingToken` contract to manage token issuance and with the `ProjectFunding` for project-specific funding details.

### Ecosystem Flow

1. **Initialization:**

    - The `Coinbase` contract initializes the ecosystem by setting up the `ProjectFunding` contract with parameters for the first project.

2. **Project Deployment:**

    - The `ProjectFunding` contract deploys new housing projects using the `HousingProject` contract. It sets project goals, deadlines, and funding tokens.

3. **Funding Projects:**

    - Users fund projects through the `ProjectFunding` contract, which processes payments and updates project details. The `HousingProject` contract manages the funds and mints tokens for investors.

4. **Token Distribution:**

    - The `SmartHousingToken` contract handles the issuance, transfer, and staking of SHT tokens. It integrates with the `ProjectFunding` contract for token distribution related to project investments.

5. **Project Management:**
    - Once funded, projects are added to the ecosystem using the `addProjectToEcosystem` function in the `ProjectFunding` contract. Ongoing management includes token claims and investment tracking.

By integrating these components, the SmartHousing ecosystem provides a comprehensive solution for addressing Nigeria’s housing deficit through blockchain technology, making real estate investment more accessible and efficient.

---

This document outlines the key components and interactions within the SmartHousing ecosystem, providing a detailed understanding of its architecture and functionality. Adjust as necessary based on specific implementation details or updates.

## Deployment Instructions

1. **Set Up Development Environment:**

    - Clone this repo
    - Run `yarn install`.
    - Run `yarn chain` in a seperate terminal.
    - Run `./init.sh localhost && yarn start` in another seperate terminal.
    - Visit [https://localhost:3002](https://localhost:3002) to view the platform

2. **Deploy Contracts:**

    - Edit the [hardhat.config.ts](packages/backend/hardhat.config.ts) file accordingly based on the network
    - Run `yarn deploy --network <NETWORK-NAME>`
    - Run `yarn hardhat feedSmartHousing --network <NETWORK-NAME>`
    - Run `yarn hardhat deployProject --help` to learn how to deploy more housing projects. Remember to add `--network <NETWORK-NAME>` when deploying.

## Media Resources

-   **Website:** [SmartHousing Demo Site](https://smart-housing.vercel.app/)
-   **Pitch deck:** [Download Pitch Deck](https://smart-housing.vercel.app/pitch-deck)
-   **Community:** [Join Our Community](https://t.me/+IXJCZ-EBgeIzZTM0)
-   **Contact:** [Contact Us](https://t.me/newtmex)
