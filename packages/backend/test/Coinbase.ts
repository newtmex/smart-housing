import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { token } from "../typechain-types/@openzeppelin/contracts";

describe("Coinbase", function () {
  async function deployContractsFixture() {
    const [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    const FundingToken = await ethers.getContractFactory("MintableERC20");
    const fundingToken = await FundingToken.deploy("FundingToken", "FTK");

    // Deploy Coinbase contract
    const Coinbase = await ethers.getContractFactory("Coinbase");
    const coinbase = await Coinbase.deploy();

    // Deploy ProjectFunding contract
    const ProjectFunding = await ethers.getContractFactory("ProjectFunding");
    const projectFunding = await ProjectFunding.deploy(coinbase);

    // Deploy SmartHousing contract
    const SmartHousing = await ethers.getContractFactory("SmartHousing");
    const smartHousing = await SmartHousing.deploy(coinbase, projectFunding);

    const SHT = await ethers.deployContract("SHT");

    return { coinbase, projectFunding, smartHousing, owner, addr1, addr2, addrs, fundingToken, SHT };
  }

  describe("Deployment", function () {
    it("should set the right initial values", async function () {
      const { coinbase, owner } = await loadFixture(deployContractsFixture);

      expect(await coinbase.owner()).to.equal(owner);
    });
  });

  describe("startICO", function () {
    it("should initialize the first project correctly", async function () {
      const { coinbase, projectFunding, smartHousing, SHT, fundingToken } = await loadFixture(deployContractsFixture);
      const fundingGoal = ethers.parseUnits("1000", 18);
      const fundingDeadline = Math.floor(Date.now() / 1000) + 86400;

      // Start ICO
      await expect(coinbase.startICO(projectFunding, smartHousing, fundingToken, fundingGoal, fundingDeadline)).to.emit(
        projectFunding,
        "ProjectDeployed",
      );

      // Check if the project was initialized correctly
      const projectData = await projectFunding.getProjectData(1);
      expect(projectData.id).to.equal(1);
      expect(projectData.fundingGoal).to.equal(fundingGoal);
      expect(projectData.fundingDeadline).to.equal(fundingDeadline);
      expect(projectData.fundingToken).to.equal(fundingToken);

      expect(await coinbase.balanceOf(projectFunding)).to.equal(await SHT.ICO_FUNDS());
    });

    it("should revert if called by non-owner", async function () {
      const { coinbase, projectFunding, smartHousing, addr1, fundingToken } = await loadFixture(deployContractsFixture);
      const fundingGoal = ethers.parseUnits("1000", 18);
      const fundingDeadline = Math.floor(Date.now() / 1000) + 86400;

      await expect(
        coinbase.connect(addr1).startICO(projectFunding, smartHousing, fundingToken, fundingGoal, fundingDeadline),
      ).to.be.revertedWith("Ownable: caller is not the owner");
    });
  });

  describe("feedSmartHousing", function () {
    it("should dispatch ecosystem funds to SmartHousing contract correctly", async function () {
      const { coinbase, smartHousing, SHT } = await loadFixture(deployContractsFixture);

      const amountToDispatch = await SHT.ECOSYSTEM_DISTRIBUTION_FUNDS();

      // Dispatch ecosystem funds
      await coinbase.feedSmartHousing(smartHousing);

      // Check if the SmartHousing contract has received the SHT
      expect(await coinbase.balanceOf(smartHousing)).to.equal(amountToDispatch);
    });

    it("should revert if not called by the owner", async function () {
      const { coinbase, smartHousing, addr1 } = await loadFixture(deployContractsFixture);

      await expect(coinbase.connect(addr1).feedSmartHousing(smartHousing)).to.be.revertedWith(
        "Ownable: caller is not the owner",
      );
    });

    it("should revert if funds are already dispatched", async function () {
      const { coinbase, smartHousing } = await loadFixture(deployContractsFixture);

      // Dispatch the funds first time
      await coinbase.feedSmartHousing(smartHousing);

      // Try dispatching again
      await expect(coinbase.feedSmartHousing(smartHousing)).to.be.revertedWith("Already dispatched");
    });
  });
});
