import { ethers } from "hardhat";
import { AddressLike, BigNumberish } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { HousingProject } from "../typechain-types";
import { expect } from "chai";

async function deployContractsFixtures() {
  // Retrieve signers
  const [owner, ...otherUsers] = await ethers.getSigners();

  const FundingToken = await ethers.getContractFactory("MintableERC20");
  const fundingToken = await FundingToken.deploy("FundingToken", "FTK");

  // Deploy Coinbase contract
  const Coinbase = await ethers.getContractFactory("CoinbaseMock");
  const coinbase = await Coinbase.deploy();
  // Deploy ProjectFunding contract
  const newLkSHTlib = await ethers.deployContract("NewLkSHT");
  const newHousingProjectlib = await ethers.deployContract("NewHousingProject");
  const projectFunding = await ethers.deployContract("ProjectFunding", [coinbase], {
    libraries: {
      NewLkSHT: await newLkSHTlib.getAddress(),
      NewHousingProject: await newHousingProjectlib.getAddress(),
    },
  });

  // Deploy SmartHousing contract
  const newHSTlib = await ethers.deployContract("NewHousingStakingToken");
  const smartHousing = await ethers.deployContract("SmartHousing", [coinbase, projectFunding], {
    libraries: { NewHousingStakingToken: await newHSTlib.getAddress() },
  });

  // Helper function to get HousingSFT contract instance
  const getHousingSFT = async (project: HousingProject) => {
    const sftAddr = await project.projectSFT();

    return ethers.getContractAt("HousingSFT", sftAddr);
  };

  // Return the deployed contracts and other relevant fixtures
  return {
    owner,
    coinbase,
    projectFunding,
    otherUsers,
    smartHousing,
    newHSTlib,
    newLkSHTlib,
    fundingToken,
    getHousingSFT,
    checkHousingTokenAttr: async ({
      expectedMintedAmt,
      user,
      expectedRPS,
      nonce,
      housingProject,
    }: {
      expectedMintedAmt: bigint;
      user: HardhatEthersSigner;
      expectedRPS: bigint;
      nonce: bigint;
      housingProject: HousingProject;
    }) => {
      const housingSFT = await getHousingSFT(housingProject);
      const { rewardsPerShare, tokenWeight, originalOwner } = await housingSFT.getUserSFT(user, nonce);
      expect(rewardsPerShare).to.equal(expectedRPS);
      expect(tokenWeight).to.equal(expectedMintedAmt);
      expect(originalOwner).to.equal(user.address);
    },
    initFirstProject: ({
      fundingDeadline,
      fundingGoal,
      smartHousing_ = smartHousing,
      fundingToken_ = fundingToken,
      projectFunding_ = projectFunding,
      name,
      symbol,
    }: {
      fundingGoal: BigNumberish;
      fundingDeadline: BigNumberish;
      smartHousing_?: AddressLike;
      fundingToken_?: AddressLike;
      projectFunding_?: AddressLike;
      name: string;
      symbol: string;
    }) => coinbase.startICO(name, symbol, projectFunding_, smartHousing_, fundingToken_, fundingGoal, fundingDeadline),
  };
}

export { deployContractsFixtures };
