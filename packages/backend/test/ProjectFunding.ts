import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { parseEther } from "ethers";
import { deployContractsFixtures } from "./deployContractsFixture";

describe("ProjectFunding", function () {
  const fundingGoal = parseEther("1000");
  const fundingDeadline = Math.floor(Date.now() / 1000) + 60 * 60 * 24 * 7; // 1 week from now

  async function deployFixtures() {
    const {
      projectFunding,
      fundingToken,
      initFirstProject,
      otherUsers: [, otherUser],
      ...fixtures
    } = await loadFixture(deployContractsFixtures);
    const LkSHT = await ethers.getContractAt("LkSHT", await projectFunding.lkSht());

    return {
      ...fixtures,
      otherUser,
      fundingToken,
      projectFunding,
      LkSHT,
      initFirstProject: async () => {
        return initFirstProject({ fundingDeadline, fundingGoal, name: "FirstProject", symbol: "FIRST" });
      },
    };
  }

  describe("Deployment", function () {
    it("deploys with correct coinbase address", async () => {
      const { projectFunding, coinbase } = await loadFixture(deployFixtures);
      expect(await projectFunding.coinbase()).to.equal(coinbase);
    });
  });

  describe("initFirstProject", function () {
    it("initializes the first project correctly", async () => {
      const { projectFunding, fundingToken, initFirstProject } = await loadFixture(deployFixtures);

      await expect(initFirstProject()).to.emit(projectFunding, "ProjectDeployed");

      const projectData = await projectFunding.projects(1);
      expect(projectData.fundingGoal).to.equal(fundingGoal);
      expect(projectData.fundingDeadline).to.equal(fundingDeadline);
      expect(projectData.fundingToken).to.equal(fundingToken);
      expect(projectData.projectAddress).to.be.properAddress;
    });

    it("reverts if called by non-coinbase address", async () => {
      const { projectFunding, otherUser, fundingToken, smartHousing } = await loadFixture(deployFixtures);
      await expect(
        projectFunding.connect(otherUser).initFirstProject(
          {
            token: fundingToken,
            amount: parseEther("1000"),
          },
          "SomeName",
          "TICKER",
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
      const { projectFunding, fundingToken, initFirstProject } = await loadFixture(deployFixtures);

      await initFirstProject();

      await expect(
        projectFunding.deployProject("SomeProject", "SPT", fundingToken, fundingGoal, fundingDeadline),
      ).to.emit(projectFunding, "ProjectDeployed");

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
            nonce: 0,
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
            nonce: 0,
          },
          99,
          0,
        ),
      ).to.be.revertedWith("Invalid project ID");
    });

    it("reverts if project funding period has ended", async () => {
      const { projectFunding, fundingToken, initFirstProject, otherUser } = await loadFixture(deployFixtures);

      await initFirstProject();

      const fundingDeadline = (await time.latest()) + 60 * 60 * 24; // 1 day into the future
      await projectFunding.deployProject("SomeName", "TTTK", fundingToken, fundingGoal, fundingDeadline);

      await fundingToken.mint(otherUser, parseEther("500"));
      await fundingToken.connect(otherUser).approve(projectFunding, parseEther("500"));

      // Move time past fundingDeadline
      await time.increaseTo(fundingDeadline + 1);
      await expect(
        projectFunding.connect(otherUser).fundProject(
          {
            token: fundingToken,
            amount: parseEther("500"),
            nonce: 0,
          },
          2,
          0,
        ),
      ).to.be.revertedWith("Cannot fund project after deadline");
    });
  });

  describe("claimProjectTokens", function () {
    it("allows users to claim tokens from successful projects", async () => {
      const { projectFunding, fundingToken, initFirstProject, LkSHT, otherUser, owner } =
        await loadFixture(deployFixtures);

      await initFirstProject();

      await fundingToken.mint(otherUser, parseEther("500"));
      await fundingToken.connect(otherUser).approve(projectFunding, parseEther("500"));

      await projectFunding.connect(otherUser).fundProject(
        {
          token: fundingToken,
          amount: parseEther("500"),
          nonce: 0,
        },
        1,
        0,
      );

      // Simulate project success
      const { fundingGoal, collectedFunds } = await projectFunding.getProjectData(1);
      const completeFund = fundingGoal - collectedFunds;
      await fundingToken.mint(owner, completeFund);
      await fundingToken.connect(owner).approve(projectFunding, completeFund);
      await projectFunding.connect(owner).fundProject(
        {
          token: fundingToken,
          amount: completeFund,
          nonce: 0,
        },
        1,
        0,
      );
      await time.increaseTo(fundingDeadline + 1);

      await projectFunding.addProjectToEcosystem(1);

      await expect(projectFunding.connect(otherUser).claimProjectTokens(1)).to.emit(
        projectFunding,
        "ProjectTokensClaimed",
      );

      const balance = await LkSHT.balanceOf(otherUser, 1n);
      expect(balance).to.be.gt(0); // Expect some LkSHT balance
    });

    it("reverts if claiming tokens from an unsuccessful project", async () => {
      const { projectFunding, fundingToken, initFirstProject, otherUser } = await loadFixture(deployFixtures);

      await initFirstProject();

      await fundingToken.mint(otherUser, parseEther("500"));
      await fundingToken.connect(otherUser).approve(projectFunding, parseEther("500"));

      await projectFunding.connect(otherUser).fundProject(
        {
          token: fundingToken,
          amount: parseEther("500"),
          nonce: 0,
        },
        1,
        0,
      );

      // Simulate project failure
      await time.increaseTo(fundingDeadline + 1);

      await expect(projectFunding.connect(otherUser).claimProjectTokens(1)).to.be.revertedWith(
        "Project not yet successful",
      );
    });
  });

  describe("whitelist", function () {
    // TODO it("only allows whitelisted addresses to receive LkSHT", async () => {
    //   const { projectFunding, coinbase, otherUser } = await loadFixture(deployFixtures);
    //   await projectFunding.updateWhitelist(otherUser, true);
    //   // Mint some LkSHT for the whitelisted user
    //   await projectFunding._mint(parseEther("1000"), otherUser);
    //   const balance = await projectFunding.balanceOf(otherUser, await projectFunding.LOCKED_SHT_ID());
    //   expect(balance).to.equal(parseEther("1000"));
    //   // Trying to transfer LkSHT to a non-whitelisted address
    //   await expect(
    //     projectFunding
    //       .connect(otherUser)
    //       .safeTransferFrom(otherUser, coinbase, await projectFunding.LOCKED_SHT_ID(), parseEther("1000"), []),
    //   ).to.be.revertedWith("Address not whitelisted");
    // });
  });
});
