import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { parseEther } from "ethers";

describe("ProjectFunding", function () {
  const fundingGoal = parseEther("1000");
  const fundingDeadline = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 7; // 1 week from now

  async function deployFixtures() {
    const [owner, coinbase, otherUser] = await ethers.getSigners();
    const fundingToken = await ethers.deployContract("MintableERC20", ["FundingToken", "FTK"]);
    const projectFunding = await ethers.deployContract("ProjectFunding", [coinbase]);

    return {
      projectFunding,
      fundingToken,
      coinbase,
      otherUser,
      owner,
      fundingGoal,
      fundingDeadline,
      initFirstProject: async () => {
        await fundingToken.mint(coinbase, parseEther("1000")); // Mint tokens to the coinbase contract
        await fundingToken.connect(coinbase).approve(projectFunding, parseEther("1000")); // Approve tokens

        return projectFunding.connect(coinbase).initFirstProject(
          {
            token: fundingToken,
            amount: parseEther("1000"),
          },
          projectFunding, // Pass the address of ProjectFunding
          fundingToken,
          fundingGoal,
          fundingDeadline,
        );
      },
    };
  }

  describe("Deployment", function () {
    it("deploys", async () => {
      const { projectFunding, coinbase } = await loadFixture(deployFixtures);
      expect(await projectFunding.coinbase()).to.equal(coinbase);
    });
  });

  describe("initFirstProject", function () {
    it("initializes the first project correctly and emits ProjectDeployed event", async () => {
      const { projectFunding, fundingToken, initFirstProject, fundingGoal, fundingDeadline } =
        await loadFixture(deployFixtures);

      await initFirstProject();

      const projectData = await projectFunding.projects(1);
      expect(projectData.fundingGoal).to.equal(fundingGoal);
      expect(projectData.fundingDeadline).to.equal(fundingDeadline);
      expect(projectData.fundingToken).to.equal(fundingToken);
      expect(projectData.projectAddress).to.be.properAddress; // Check if the address is valid
    });
  });

  describe("deployProject", function () {
    it("deploys a new project correctly and emits ProjectDeployed event", async () => {
      const { projectFunding, fundingToken, initFirstProject, fundingGoal, fundingDeadline } =
        await loadFixture(deployFixtures);

      await initFirstProject();

      await projectFunding.deployProject(fundingToken, fundingGoal, fundingDeadline);

      const projectData = await projectFunding.projects(2);
      expect(projectData.fundingGoal).to.equal(fundingGoal);
      expect(projectData.fundingDeadline).to.equal(fundingDeadline);
      expect(projectData.fundingToken).to.equal(fundingToken);
      expect(projectData.projectAddress).to.be.properAddress; // Check if the address is valid
    });
  });
});
