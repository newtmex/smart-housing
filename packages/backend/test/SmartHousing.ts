import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { parseEther } from "ethers";

describe("SmartHousing", function () {
  async function deployFixtures() {
    const [owner, ...otherUsers] = await ethers.getSigners();
    const coinbase = owner;

    const newLkSHTlib = await ethers.deployContract("NewLkSHT");
    const newHousingProjectib = await ethers.deployContract("NewHousingProject");
    const projectFunding = await ethers.deployContract("ProjectFunding", [coinbase], {
      libraries: {
        NewLkSHT: await newLkSHTlib.getAddress(),
        NewHousingProject: await newHousingProjectib.getAddress(),
      },
    });

    const newHSTlib = await ethers.deployContract("NewHousingStakingToken");
    const smartHousing = await ethers.deployContract("SmartHousing", [coinbase, projectFunding], {
      libraries: { NewHousingStakingToken: await newHSTlib.getAddress() },
    });

    return {
      smartHousing,
      owner,
      projectFunding,
      coinbase,
      otherUsers,
      setUpSht: async () => {
        const SHT = await ethers.deployContract("SHT");
        const SmartToken = await ethers.getContractFactory("MintableERC20");
        const sht = await SmartToken.connect(coinbase).deploy("SmartToken", "SHT");
        await sht.mint(coinbase, await SHT.MAX_SUPPLY());

        // Prepare the payment
        const payment = {
          token: sht,
          amount: await SHT.ECOSYSTEM_DISTRIBUTION_FUNDS(),
        };

        await payment.token.connect(coinbase).approve(smartHousing, payment.amount);

        // Set up SHT
        await (await smartHousing.connect(coinbase).setUpSHT(payment)).wait();

        return { sht, payment };
      },
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
      const { smartHousing, setUpSht } = await loadFixture(deployFixtures);

      const { payment } = await setUpSht();

      // Check if SHT token address is set
      expect(await smartHousing.shtTokenAddress()).to.equal(await payment.token.getAddress());

      // Check if total funds are set in distribution storage
      const [totalFunds] = await smartHousing.distributionStorage();
      expect(totalFunds).to.equal(payment.amount);
    });

    it("Should revert if not called by coinbase", async function () {
      const { smartHousing, otherUsers, coinbase } = await loadFixture(deployFixtures);
      const [nonCoinbase] = otherUsers;

      await expect(smartHousing.connect(nonCoinbase).setUpSHT({ token: coinbase, amount: 0 })).to.be.revertedWith(
        "Caller is not the coinbase address",
      );
    });

    it("Should revert if SHT token already set", async function () {
      const { smartHousing, coinbase, setUpSht } = await loadFixture(deployFixtures);

      const { payment } = await setUpSht();

      await expect(smartHousing.connect(coinbase).setUpSHT(payment)).to.be.revertedWith("SHT token already set");
    });

    it("Should revert if incorrect amount of SHT is sent", async function () {
      const { smartHousing, coinbase } = await loadFixture(deployFixtures);

      await expect(smartHousing.connect(coinbase).setUpSHT({ token: coinbase, amount: 0 })).to.be.revertedWith(
        "Must send all ecosystem funds",
      );

      await expect(
        smartHousing.connect(coinbase).setUpSHT({ token: coinbase, amount: parseEther("1500") }),
      ).to.be.revertedWith("Must send all ecosystem funds");
    });
  });

  describe("Project Management", function () {
    it("Should not allow non-project funder to add a project", async function () {
      const { smartHousing, otherUsers } = await loadFixture(deployFixtures);
      const [project, nonFunder] = otherUsers;

      await expect(smartHousing.connect(nonFunder).addProject(project)).to.be.revertedWith(
        "Caller is not the project funder",
      );
    });
  });

  describe("Rent Management", function () {
    // TODO we need way to make housingProject call addProjectRent
    // it("Should add rent to a project and update distribution storage", async function () {
    //   const { smartHousing, projectFunding, housingProject, setUpSht } = await loadFixture(deployFixtures);

    //   // Add the project
    //   await smartHousing.connect(projectFunding).addProject(housingProject);

    //   // Set up SHT
    //   await setUpSht();

    //   // Add rent
    //   const rentAmount = parseEther("100");
    //   await smartHousing.connect(housingProject).addProjectRent(rentAmount);

    //   // Verify rent addition
    //   const projectData = await smartHousing.projectDets(housingProject);
    //   expect(projectData.receivedRents).to.equal(rentAmount);
    // });

    it("Should revert if a non-HousingProject tries to add rent", async function () {
      const { smartHousing, otherUsers } = await loadFixture(deployFixtures);
      const [nonProject] = otherUsers;

      await expect(smartHousing.connect(nonProject).addProjectRent(parseEther("100"))).to.be.revertedWith(
        "Caller is not an accepted housing project",
      );
    });
  });

  describe("Staking", function () {
    it("Should allow users to stake tokens", async function () {
      const { smartHousing, otherUsers, setUpSht } = await loadFixture(deployFixtures);
      const [user] = otherUsers;
      const { sht } = await setUpSht();

      const stakeAmount = parseEther("100");

      await sht.connect(user).approve(await smartHousing.getAddress(), stakeAmount);

      const referrerId = 1;
      await smartHousing.connect(user).stake([{ token: sht, amount: stakeAmount, nonce: 0n }], 24, referrerId);

      // Verify the staking
      const userId = await smartHousing.getUserId(user);
      expect(userId).to.equal(2);

      const userCanClaim = await smartHousing.userCanClaim(user, 1);
      expect(userCanClaim).to.be.true;
    });

    it("Should revert staking if the epochs lock period is invalid", async function () {
      const { smartHousing, otherUsers, setUpSht } = await loadFixture(deployFixtures);
      const [user] = otherUsers;
      const { sht } = await setUpSht();

      const stakeAmount = parseEther("100");

      await sht.connect(user).approve(await smartHousing.getAddress(), stakeAmount);

      const referrerId = 0n;
      await expect(
        smartHousing
          .connect(user)
          .stake([{ token: await sht.getAddress(), amount: stakeAmount, nonce: 0n }], 120, referrerId),
      ).to.be.revertedWith("Invalid epochs lock period");
    });
  });

  describe("Rewards Claiming", function () {
    async function deployAndStakeFixture() {
      const { smartHousing, projectFunding, otherUsers, owner, setUpSht } = await deployFixtures();

      // Setting up SHT
      const { sht } = await setUpSht();

      // Adding the project
      const fundingToken = await ethers.deployContract("MintableERC20", ["FundingToken", "FTK"]);

      await fundingToken.mint(owner, parseEther("100000")); // Mint tokens to the owner contract
      await fundingToken.connect(owner).approve(projectFunding, parseEther("100000")); // Approve tokens
      const fundingGoal = parseEther("20");
      const fundingDeadline = (await time.latest()) + 100_000;

      await projectFunding.initFirstProject(
        {
          token: fundingToken,
          amount: parseEther("1000"),
        },
        "Ulo",
        "ULO",
        smartHousing,
        fundingToken,
        fundingGoal,
        fundingDeadline,
      );

      await projectFunding.fundProject({ token: fundingToken, nonce: 0, amount: fundingGoal }, 1, 0);
      await projectFunding.setProjectToken(1);

      await time.increase(100_000);

      await projectFunding.claimProjectTokens(1);
      const lkSHT = await ethers.getContractAt("LkSHT", await projectFunding.lkSht());
      const { tokenAddress } = await projectFunding.projects(1);
      const housingToken = await ethers.getContractAt("HousingSFT", tokenAddress);

      // Stake tokens for rewards
      const stakeAmount = parseEther("100");

      await lkSHT.setApprovalForAll(smartHousing, true);
      await housingToken.setApprovalForAll(smartHousing, true);

      const epochsLock = 190;
      await smartHousing.stake(
        [
          { token: lkSHT, nonce: 1n, amount: await lkSHT.balanceOf(owner, 1) },
          { token: housingToken, nonce: 1n, amount: 1_000_000 },
        ],
        epochsLock,
        0,
      );

      // Simulate time passing
      await time.increase(100_000);

      return { smartHousing, user: owner, sht, stakeAmount, otherUsers };
    }

    it("Should allow users to claim rewards", async function () {
      const { smartHousing, user, sht } = await loadFixture(deployAndStakeFixture);

      // Fast forward time to simulate lock period completion
      await ethers.provider.send("evm_increaseTime", [3600 * 24 * 30 * 24]); // 24 months
      await ethers.provider.send("evm_mine", []);

      const initialBalance = await sht.balanceOf(user.address);

      // Claim rewards
      await smartHousing.connect(user).claimRewards(1, 0); // Claim rewards for the first staking (nonce 1)

      const finalBalance = await sht.balanceOf(user.address);
      expect(finalBalance).to.be.gt(initialBalance);

      const userCanClaim = await smartHousing.userCanClaim(user, 1);
      expect(userCanClaim).to.be.false; // After claiming, the user should no longer be able to claim for the same stake
    });

    it("Should revert if trying to claim rewards before lock period ends", async function () {
      const { smartHousing, user } = await loadFixture(deployAndStakeFixture);

      // Try to claim rewards before lock period ends
      await expect(smartHousing.connect(user).claimRewards(1, 0)).to.be.revertedWith(
        "Cannot claim rewards before lock period ends",
      );
    });

    it("Should revert if the user tries to claim rewards for a non-existent stake", async function () {
      const { smartHousing, user } = await loadFixture(deployAndStakeFixture);

      // Fast forward time to simulate lock period completion
      await ethers.provider.send("evm_increaseTime", [3600 * 24 * 30 * 24]); // 24 months
      await ethers.provider.send("evm_mine", []);

      // Try to claim rewards for a non-existent stake index
      await expect(smartHousing.connect(user).claimRewards(2, 0)).to.be.revertedWith("Stake does not exist");
    });

    it("Should correctly distribute rewards among multiple stakeholders", async function () {
      const { smartHousing, otherUsers, setUpSht } = await loadFixture(deployFixtures);
      const [user1, user2] = otherUsers;

      // Setting up SHT
      const { sht } = await setUpSht();

      // User 1 and User 2 stake tokens
      const stakeAmount1 = parseEther("100");
      const stakeAmount2 = parseEther("200");

      await sht.connect(user1).approve(await smartHousing.getAddress(), stakeAmount1);
      await sht.connect(user2).approve(await smartHousing.getAddress(), stakeAmount2);

      await smartHousing.connect(user1).stake([{ token: sht, nonce: 0n, amount: stakeAmount1 }], 24, 1);
      await smartHousing.connect(user2).stake([{ token: sht, nonce: 0n, amount: stakeAmount2 }], 24, 1);

      // Simulate some rent being added
      const rentAmount = parseEther("300");
      await smartHousing.connect(user1).addProjectRent(rentAmount); // Assuming user1 is the project funder

      // Fast forward time to simulate lock period completion
      await ethers.provider.send("evm_increaseTime", [3600 * 24 * 30 * 24]); // 24 months
      await ethers.provider.send("evm_mine", []);

      // User 1 claims rewards
      const initialBalance1 = await ethers.provider.getBalance(user1.address);
      await smartHousing.connect(user1).claimRewards(1, 0); // Claim rewards for the first staking (nonce 1)
      const finalBalance1 = await ethers.provider.getBalance(user1.address);

      // User 2 claims rewards
      const initialBalance2 = await ethers.provider.getBalance(user2.address);
      await smartHousing.connect(user2).claimRewards(2, 0); // Claim rewards for the second staking (index 2)
      const finalBalance2 = await ethers.provider.getBalance(user2.address);

      // Check that user2 got twice the rewards of user1 (since they staked twice as much)
      const reward1 = finalBalance1 - initialBalance1;
      const reward2 = finalBalance2 - initialBalance2;

      expect(reward2).to.be.closeTo(reward1 * 2n, parseEther("0.1"));
    });

    it("Should revert if a non-staker tries to claim rewards", async function () {
      const { smartHousing, otherUsers } = await loadFixture(deployAndStakeFixture);
      const [nonStaker] = otherUsers.slice(2);

      // Fast forward time to simulate lock period completion
      await ethers.provider.send("evm_increaseTime", [3600 * 24 * 30 * 24]); // 24 months
      await ethers.provider.send("evm_mine", []);

      // Non-staker tries to claim rewards
      await expect(smartHousing.connect(nonStaker).claimRewards(1, 0)).to.be.revertedWith(
        "Caller does not own the hst token",
      );
    });
  });
});
