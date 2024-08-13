import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { parseEther } from "ethers";
import { deployContractsFixtures } from "./deployContractsFixture";

describe("SmartHousing", function () {
  async function deployFixtures() {
    const { coinbase, smartHousing, ...fixtures } = await loadFixture(deployContractsFixtures);

    const SHT = await ethers.deployContract("SHT");
    return {
      ...fixtures,
      coinbase,
      smartHousing,
      SHT,
      setUpSht: () => coinbase.feedSmartHousing(smartHousing),
    };
  }

  describe("Deployment", function () {
    it("Should set the right owner, project funder, and coinbase", async function () {
      const { smartHousing, owner, projectFunding, coinbase } = await loadFixture(deployFixtures);

      expect(await smartHousing.owner()).to.equal(owner);
      expect(await smartHousing.projectFundingAddress()).to.equal(projectFunding);
      expect(await smartHousing.coinbaseAddress()).to.equal(coinbase);
    });
  });

  describe("SHT Setup", function () {
    it("Should set up SHT correctly if called by coinbase", async function () {
      const { smartHousing, setUpSht, coinbase, SHT } = await loadFixture(deployFixtures);

      await setUpSht();

      // Check if SHT token address is set
      expect(await smartHousing.shtTokenAddress()).to.equal(coinbase);

      // Check if total funds are set in distribution storage
      const { totalFunds } = await smartHousing.distributionStorage();
      expect(totalFunds).to.equal(await SHT.ECOSYSTEM_DISTRIBUTION_FUNDS());
    });

    it("Should revert if not called by coinbase", async function () {
      const { smartHousing, otherUsers, coinbase } = await loadFixture(deployFixtures);
      const [nonCoinbase] = otherUsers;

      await expect(smartHousing.connect(nonCoinbase).setUpSHT({ token: coinbase, amount: 0 })).to.be.revertedWith(
        "Unauthorized",
      );
    });

    it("Should revert if SHT token already set", async function () {
      const { coinbase, setUpSht, SHT } = await loadFixture(deployFixtures);

      await setUpSht();
      await coinbase.mint(coinbase, await SHT.ECOSYSTEM_DISTRIBUTION_FUNDS());

      await expect(setUpSht()).to.be.revertedWith("SHT already set");
    });
  });

  describe("Project Management", function () {
    it("Should not allow non-project funder to add a project", async function () {
      const { smartHousing, otherUsers } = await loadFixture(deployFixtures);
      const [project, nonFunder] = otherUsers;

      await expect(smartHousing.connect(nonFunder).addProject(project)).to.be.revertedWith("Not authorized");
    });
  });

  describe("Rent Management", function () {
    it("Should revert if a non-HousingProject tries to add rent", async function () {
      const { smartHousing, otherUsers } = await loadFixture(deployFixtures);
      const [nonProject] = otherUsers;

      await expect(smartHousing.connect(nonProject).addProjectRent(parseEther("100"))).to.be.revertedWith(
        "Not authorized",
      );
    });
  });

  describe("Staking", function () {
    it("Should revert staking if the epochs lock period is invalid", async function () {
      const { smartHousing, otherUsers, setUpSht, coinbase } = await loadFixture(deployFixtures);
      const [investor] = otherUsers;
      await setUpSht();

      const stakeAmount = parseEther("100");

      await coinbase.connect(investor).approve(await smartHousing.getAddress(), stakeAmount);

      const referrerId = 0n;
      await expect(
        smartHousing
          .connect(investor)
          .stake([{ token: await coinbase.getAddress(), amount: stakeAmount, nonce: 0n }], 120, referrerId),
      ).to.be.revertedWith("Invalid epochs lock period");
    });
  });

  describe("Rewards Claiming", function () {
    async function deployAndStakeFixture() {
      const {
        smartHousing,
        projectFunding,
        otherUsers: [, investor, ...otherUsers],
        setUpSht,
        coinbase,
        ...fixtures
      } = await deployFixtures();

      // Setting up SHT
      await setUpSht();

      // Adding the project
      const fundingToken = await ethers.deployContract("MintableERC20", ["FundingToken", "FTK"]);

      const fundingGoal = parseEther("20");
      await fundingToken.mint(investor, fundingGoal); // Mint tokens to the owner contract
      await fundingToken.connect(investor).approve(projectFunding, fundingGoal); // Approve tokens
      const fundingDeadline = (await time.latest()) + 100_000;

      await coinbase.startICO("Ulo", "ULO", projectFunding, smartHousing, fundingToken, fundingGoal, fundingDeadline);

      await projectFunding.connect(investor).fundProject({ token: fundingToken, nonce: 0, amount: fundingGoal }, 1, 0);
      await projectFunding.addProjectToEcosystem(1);

      await time.increase(100_000);

      await projectFunding.connect(investor).claimProjectTokens(1);
      const lkSHT = await ethers.getContractAt("LkSHT", await projectFunding.lkSht());
      const { tokenAddress } = await projectFunding.projects(1);
      const housingSFT = await ethers.getContractAt("HousingSFT", tokenAddress);

      // Stake tokens for rewards
      const stakeAmount = parseEther("100");

      await lkSHT.connect(investor).setApprovalForAll(smartHousing, true);
      await housingSFT.connect(investor).setApprovalForAll(smartHousing, true);

      const epochsLock = 190;
      await smartHousing.connect(investor).stake(
        [
          { token: lkSHT, nonce: 1n, amount: await lkSHT.balanceOf(investor, 1) },
          { token: housingSFT, nonce: 1n, amount: 1_000_000 },
        ],
        epochsLock,
        0,
      );

      // Simulate time passing
      await time.increase(100_000);

      return {
        ...fixtures,
        smartHousing,
        investor,
        projectFunding,
        stakeAmount,
        otherUsers,
        coinbase,
      };
    }

    it("Should allow users to claim rewards", async function () {
      const { smartHousing, coinbase, investor } = await loadFixture(deployAndStakeFixture);

      // Fast forward time to simulate rewards generation
      await time.increase(3600 * 24 * 30 * 24); // 24 months

      const initialBalance = await coinbase.balanceOf(investor.address);

      // Claim rewards
      await smartHousing.connect(investor).claimRewards(1, 0); // Claim rewards for the first staking (nonce 1)

      const finalBalance = await coinbase.balanceOf(investor.address);
      expect(finalBalance).to.be.gt(initialBalance);

      const userCanClaim = await smartHousing.userCanClaim(investor, 1);
      expect(userCanClaim).to.be.false; // After claiming, the investor should no longer be able to claim for the same stake
    });

    it("Should revert if the investor tries to claim rewards for a non-existent stake", async function () {
      const { smartHousing, investor } = await loadFixture(deployAndStakeFixture);

      // Fast forward time to simulate rewards generation
      await time.increase(3600 * 24 * 30 * 24); // 24 months

      // Try to claim rewards for a non-existent stake index
      await expect(smartHousing.connect(investor).claimRewards(2, 0)).to.be.revertedWith(
        "No HST token balance at nonce",
      );
    });

    it("Should correctly distribute rewards among multiple stakeholders", async function () {
      const { smartHousing, otherUsers, setUpSht, coinbase, fundingToken, projectFunding } =
        await loadFixture(deployFixtures);
      const [user1, user2] = otherUsers;

      // Setting up SHT
      await setUpSht();

      const fundingGoal = parseEther("20");
      const fundingDeadline = (await time.latest()) + 100_000;

      await coinbase.startICO("Ulo", "ULO", projectFunding, smartHousing, fundingToken, fundingGoal, fundingDeadline);
      await projectFunding.addProjectToEcosystem(1);

      // User 1 and User 2 stake tokens
      for (const investor of [user1, user2]) {
        const fundAmount = fundingGoal / 2n;
        await fundingToken.mint(investor, fundAmount);
        await fundingToken.connect(investor).approve(projectFunding, fundAmount);

        await projectFunding.connect(investor).fundProject({ token: fundingToken, nonce: 0, amount: fundAmount }, 1, 0);
      }

      await time.increase(100_000);
      for (const investor of [user1, user2]) {
        await projectFunding.connect(investor).claimProjectTokens(1);
      }

      const { tokenAddress } = await projectFunding.projects(1);
      const housingSFT = await ethers.getContractAt("HousingSFT", tokenAddress);

      // Stake tokens for rewards
      for (const { investor, amt } of [
        { investor: user1, amt: parseEther("100") },
        { investor: user2, amt: parseEther("200") },
      ]) {
        await coinbase.mint(investor, amt);
        await coinbase.connect(investor).approve(smartHousing, amt);

        await housingSFT.connect(investor).setApprovalForAll(smartHousing, true);
        const [{ nonce, amount }] = await housingSFT.sftBalance(investor);

        const epochsLock = 190;
        await smartHousing.connect(investor).stake(
          [
            { token: housingSFT, nonce, amount },
            { token: coinbase, nonce: 0n, amount: amt },
          ],
          epochsLock,
          0,
        );
      }

      // Fast forward time to simulate rewards genration
      await time.increase(3600 * 24 * 30 * 24); // 24 months

      // User 1 claims rewards
      const initialBalance1 = await ethers.provider.getBalance(user1.address);
      await smartHousing.connect(user1).claimRewards(1, 0); // Claim rewards for the first staking (nonce 1)
      const finalBalance1 = await ethers.provider.getBalance(user1.address);

      // User 2 claims rewards
      const initialBalance2 = await ethers.provider.getBalance(user2.address);
      await smartHousing.connect(user2).claimRewards(2, 0); // Claim rewards for the second staking (nonce 2)
      const finalBalance2 = await ethers.provider.getBalance(user2.address);

      // Check that user2 got twice the rewards of user1 (since they staked twice as much)
      const reward1 = finalBalance1 - initialBalance1;
      const reward2 = finalBalance2 - initialBalance2;

      expect(reward2).to.be.closeTo(reward1 * 2n, parseEther("0.1"));
    });

    it("Should revert if a non-staker tries to claim rewards", async function () {
      const {
        smartHousing,
        otherUsers: [, , nonStaker],
      } = await loadFixture(deployAndStakeFixture);

      // Fast forward time to simulate rewards genration
      await time.increase(3600 * 24 * 30 * 24); // 24 months

      // Non-staker tries to claim rewards
      await expect(smartHousing.connect(nonStaker).claimRewards(1, 0)).to.be.revertedWith(
        "No HST token balance at nonce",
      );
    });
  });
});
