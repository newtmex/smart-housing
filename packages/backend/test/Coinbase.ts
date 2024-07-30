import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";

describe("Coinbase", function () {
  async function deployContractsFixture() {
    const [owner, addr1, addr2, ...addrs] = await ethers.getSigners();

    const fundingToken = await ethers.deployContract("MintableERC20", ["FundingToken", "FTK"]);

    // Deploy SmartHousing contract
    const SmartHousing = await ethers.getContractFactory("SmartHousing");
    const smartHousing = await SmartHousing.deploy(owner, addr1);

    // Deploy Coinbase contract
    const Coinbase = await ethers.getContractFactory("Coinbase");
    const coinbase = await Coinbase.deploy();

    // Deploy ProjectFunding contract
    const ProjectFunding = await ethers.getContractFactory("ProjectFunding");
    const projectFunding = await ProjectFunding.deploy(coinbase);

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
});
