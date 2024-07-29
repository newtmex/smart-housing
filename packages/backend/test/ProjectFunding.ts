import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { parseEther } from "ethers";

describe("ProjectFunding", function () {
  const fundingGoal = parseEther("1000");
  const fundingDeadline = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 7; // 1 week from now

  async function deployFixtures() {
    const [owner, coinbase, otherUser] = await ethers.getSigners();
    const fundingToken = await ethers.deployContract("MintableERC20", ["FundingToken", "FTK"]);
    const projectFunding = await ethers.deployContract("ProjectFunding", [coinbase]);
    const smartHousing = await ethers.deployContract("SmartHousing", [coinbase, projectFunding]);

    return {
      projectFunding,
      fundingToken,
      coinbase,
      otherUser,
      owner,
      fundingGoal,
      fundingDeadline,
      smartHousing,
      initFirstProject: async () => {
        await fundingToken.mint(coinbase, parseEther("1000")); // Mint tokens to the coinbase contract
        await fundingToken.connect(coinbase).approve(projectFunding, parseEther("1000")); // Approve tokens

        return projectFunding.connect(coinbase).initFirstProject(
          {
            token: fundingToken,
            amount: parseEther("1000"),
          },
          smartHousing,
          fundingToken,
          fundingGoal,
          fundingDeadline,
        );
      },
    };
  }

  describe("Deployment", function () {
    it("deploys with correct coinbase address", async () => {
      const { projectFunding, coinbase } = await loadFixture(deployFixtures);
      expect(await projectFunding.coinbase()).to.equal(coinbase.address);
    });
  });

  describe("initFirstProject", function () {
    it("initializes the first project correctly", async () => {
      const { projectFunding, fundingToken, initFirstProject, fundingGoal, fundingDeadline } =
        await loadFixture(deployFixtures);

      await expect(initFirstProject()).to.emit(projectFunding, "ProjectDeployed");

      const projectData = await projectFunding.projects(1);
      expect(projectData.fundingGoal).to.equal(fundingGoal);
      expect(projectData.fundingDeadline).to.equal(fundingDeadline);
      expect(projectData.fundingToken).to.equal(fundingToken);
      expect(projectData.projectAddress).to.be.properAddress;
    });

    it("reverts if called by non-coinbase address", async () => {
      const { projectFunding, otherUser, fundingToken, smartHousing, fundingGoal, fundingDeadline } =
        await loadFixture(deployFixtures);
      await expect(
        projectFunding.connect(otherUser).initFirstProject(
          {
            token: fundingToken,
            amount: parseEther("1000"),
          },
          smartHousing,
          fundingToken,
          fundingGoal,
          fundingDeadline,
        ),
      ).to.be.revertedWith("Caller is not the coinbase");
    });

    it("reverts if project already initialized", async () => {
      const { initFirstProject } = await loadFixture(deployFixtures);
      await initFirstProject();
      await expect(initFirstProject()).to.be.revertedWith("Project already initialized");
    });
  });

  describe("deployProject", function () {
    it("deploys a new project correctly", async () => {
      const { projectFunding, fundingToken, initFirstProject, fundingGoal, fundingDeadline } =
        await loadFixture(deployFixtures);

      await initFirstProject();

      await expect(projectFunding.deployProject(fundingToken, fundingGoal, fundingDeadline)).to.emit(
        projectFunding,
        "ProjectDeployed",
      );

      const projectData = await projectFunding.projects(2);
      expect(projectData.fundingGoal).to.equal(fundingGoal);
      expect(projectData.fundingDeadline).to.equal(fundingDeadline);
      expect(projectData.fundingToken).to.equal(fundingToken);
      expect(projectData.projectAddress).to.be.properAddress;
    });
  });

  describe("fundProject", function () {
    it("allows users to fund a project", async () => {
      const { projectFunding, fundingToken, initFirstProject, otherUser } = await loadFixture(deployFixtures);

      await initFirstProject();

      await fundingToken.mint(otherUser, parseEther("500"));
      await fundingToken.connect(otherUser).approve(projectFunding, parseEther("500"));

      await expect(
        projectFunding.connect(otherUser).fundProject(
          {
            token: fundingToken,
            amount: parseEther("500"),
          },
          1,
          0,
        ),
      ).to.emit(projectFunding, "ProjectFunded");

      const projectData = await projectFunding.projects(1);
      expect(projectData.collectedFunds).to.equal(parseEther("500"));
    });

    it("reverts if funding project with incorrect ID", async () => {
      const { projectFunding, fundingToken, initFirstProject, otherUser } = await loadFixture(deployFixtures);

      await initFirstProject();

      await fundingToken.mint(otherUser, parseEther("500"));
      await fundingToken.connect(otherUser).approve(projectFunding, parseEther("500"));

      await expect(
        projectFunding.connect(otherUser).fundProject(
          {
            token: fundingToken,
            amount: parseEther("500"),
          },
          99,
          0,
        ),
      ).to.be.revertedWith("Invalid project ID");
    });

    it("reverts if project funding period has ended", async () => {
      const { projectFunding, fundingToken, initFirstProject, fundingGoal, otherUser } =
        await loadFixture(deployFixtures);

      await initFirstProject();

      const fundingDeadline = (await time.latest()) + 60 * 60 * 24; // 1 day into the future
      await projectFunding.deployProject(fundingToken, fundingGoal, fundingDeadline);

      await fundingToken.mint(otherUser, parseEther("500"));
      await fundingToken.connect(otherUser).approve(projectFunding, parseEther("500"));

      // Move time past fundingDeadline
      time.increaseTo(fundingDeadline + 1);
      await expect(
        projectFunding.connect(otherUser).fundProject(
          {
            token: fundingToken,
            amount: parseEther("500"),
          },
          2,
          0,
        ),
      ).to.be.revertedWith("Cannot fund project after deadline");
    });
  });
});
