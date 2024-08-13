import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture, time } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { BigNumberish, parseEther } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { deployContractsFixtures } from "./deployContractsFixture";

describe("HousingProject", function () {
  const name = "Incredible Block";
  const symbol = "ICRB";

  describe("HousingProject from ProjectFunding", function () {
    async function housingProjectFixtures() {
      const { otherUsers, initFirstProject, getHousingSFT, projectFunding, coinbase, ...fixtures } =
        await loadFixture(deployContractsFixtures);

      const fundingGoal = parseEther("20");
      const fundingDeadline = (await time.latest()) + 100_000;

      await initFirstProject({ fundingDeadline, fundingGoal, name, symbol });
      const { projectAddress } = await projectFunding.getProjectData(1);
      const housingProject = await ethers.getContractAt("HousingProject", projectAddress);

      const housingSFT = await getHousingSFT(housingProject);

      await projectFunding.addProjectToEcosystem(1);

      return {
        ...fixtures,
        fundingDeadline,
        fundingGoal,
        otherUsers,
        housingSFT,
        housingProject,
        coinbase,
        projectFunding,
        MAX_SUPPLY: await housingSFT.MAX_SUPPLY(),
        checkHousingTokenAttr: async ({
          expectedMintedAmt,
          user,
          expectedRPS,
          nonce,
        }: {
          expectedMintedAmt: bigint;
          user: HardhatEthersSigner;
          expectedRPS: bigint;
          nonce: bigint;
        }) => {
          const housingSFT = await getHousingSFT(housingProject);
          const { rewardsPerShare, tokenWeight, originalOwner } = await housingSFT.getUserSFT(user, nonce);
          expect(rewardsPerShare).to.equal(expectedRPS);
          expect(tokenWeight).to.equal(expectedMintedAmt);
          expect(originalOwner).to.equal(user.address);
        },
      };
    }

    describe("Deployment", function () {
      it("should deploy intial HousingProject contract with correct parameters", async () => {
        const { initFirstProject, getHousingSFT, projectFunding } = await loadFixture(deployContractsFixtures);

        const fundingGoal = parseEther("20");
        const fundingDeadline = (await time.latest()) + 100_000;

        await initFirstProject({ fundingDeadline, fundingGoal, name, symbol });
        const { projectAddress } = await projectFunding.getProjectData(1);

        const housingProject = await ethers.getContractAt("HousingProject", projectAddress);

        const housingSFT = await getHousingSFT(housingProject);

        expect(await housingSFT.name()).to.equal(name);
        expect(await housingSFT.amountRaised()).to.equal(0);
        expect(await housingSFT.totalSupply()).to.equal(0);
      });

      it("should deploy subsequent HousingProject contract with correct parameters", async () => {
        const { getHousingSFT, projectFunding, fundingToken } = await loadFixture(deployContractsFixtures);

        const fundingGoal = parseEther("20");
        const fundingDeadline = (await time.latest()) + 100_000;

        await projectFunding.deployProject(name, symbol, fundingToken, fundingGoal, fundingDeadline);
        const { projectAddress } = await projectFunding.getProjectData(1);
        const housingProject = await ethers.getContractAt("HousingProject", projectAddress);

        const housingSFT = await getHousingSFT(housingProject);

        expect(await housingSFT.name()).to.equal(name);
        expect(await housingSFT.amountRaised()).to.equal(0);
        expect(await housingSFT.totalSupply()).to.equal(0);
      });
    });

    describe("receiveRent", function () {
      it("should receive rent, calculate, and distribute rewards", async function () {
        const {
          housingProject,
          coinbase,
          otherUsers: [rentPayer],
        } = await loadFixture(housingProjectFixtures);

        // Mint tokens to rent payer
        const rentAmount = ethers.parseUnits("500", 18);
        await coinbase.mint(rentPayer, rentAmount);
        await coinbase.connect(rentPayer).approve(housingProject, rentAmount);

        // Capture initial state
        const initialRewardsReserve = await housingProject.rewardsReserve();
        const initialFacilityManagementFunds = await housingProject.facilityManagementFunds();
        const initialTotalSupply = await coinbase.totalSupply();

        // Receive rent
        await housingProject.connect(rentPayer).receiveRent({ amount: rentAmount, token: coinbase });

        // Calculate expected values
        const rentReward = (rentAmount * 75n) / 100n;
        const facilityReward = (rentAmount * 7n) / 100n;
        const ecosystemReward = (rentAmount * 18n) / 100n;

        // Verify storage parameter updates
        expect(await housingProject.rewardsReserve()).to.equal(initialRewardsReserve + rentReward);
        expect(await housingProject.facilityManagementFunds()).to.equal(
          initialFacilityManagementFunds + facilityReward,
        );
        expect(await housingProject.rewardPerShare()).to.gt(0);

        // Verify ecosystem reward was burned
        expect(await coinbase.totalSupply()).to.equal(initialTotalSupply - ecosystemReward);
      });

      it("should revert if rent amount is insufficient", async function () {
        const {
          housingProject,
          coinbase,
          otherUsers: [rentPayer],
        } = await loadFixture(housingProjectFixtures);

        // Mint a small amount of tokens to rent payer
        const rentAmount = ethers.parseUnits("0", 18);
        await coinbase.mint(rentPayer, rentAmount);
        await coinbase.connect(rentPayer).approve(housingProject, rentAmount);

        // Attempt to receive rent with insufficient amount
        await expect(
          housingProject.connect(rentPayer).receiveRent({ amount: rentAmount, token: coinbase }),
        ).to.be.revertedWith("RentsModule: Insufficient amount");
      });

      it("should revert if rent payment token is invalid", async function () {
        const {
          housingProject,
          otherUsers: [rentPayer],
        } = await loadFixture(housingProjectFixtures);

        // Mint tokens of a different token (invalid token)
        const invalidToken = await ethers.getContractFactory("MintableERC20");
        const invalidERC20Token = await invalidToken.deploy("InvalidToken", "ITK");
        await invalidERC20Token.mint(rentPayer, ethers.parseUnits("500", 18));
        await invalidERC20Token.connect(rentPayer).approve(housingProject, ethers.parseUnits("500", 18));

        // Attempt to receive rent with an invalid token
        await expect(
          housingProject
            .connect(rentPayer)
            .receiveRent({ amount: ethers.parseUnits("500", 18), token: invalidERC20Token }),
        ).to.be.revertedWith("RentsModule: Invalid token");
      });
    });

    describe("claimRentReward", function () {
      async function claimRentRewardFixtures() {
        const {
          housingProject,
          otherUsers: [, tenant, investor],
          coinbase,
          projectFunding,
          fundingToken,
          fundingGoal,
          ...fixtures
        } = await loadFixture(housingProjectFixtures);

        // Fund project and get project SFT
        const investment = fundingGoal;
        await fundingToken.mint(investor, investment);
        await fundingToken.connect(investor).approve(projectFunding, investment);

        await projectFunding.connect(investor).fundProject(
          {
            token: fundingToken,
            amount: investment,
            nonce: 0,
          },
          1,
          0,
        );

        /**
         * Pays rent for tenant
         *  */
        const payRent = async (rent: BigNumberish) => {
          await coinbase.mint(tenant, rent);
          await coinbase.connect(tenant).approve(housingProject, rent);
          await housingProject.connect(tenant).receiveRent({ token: coinbase, amount: rent });
        };

        return { ...fixtures, payRent, projectFunding, investor, coinbase, housingProject };
      }
      it("should allow users to claim rent rewards after minting and receiving rent", async () => {
        const {
          housingSFT,
          housingProject,
          coinbase,
          payRent,
          fundingDeadline,
          investor,
          projectFunding,
          checkHousingTokenAttr,
        } = await loadFixture(claimRentRewardFixtures);

        await time.increaseTo(fundingDeadline + 1);
        await projectFunding.connect(investor).claimProjectTokens(1);

        await payRent(parseEther("20"));

        let investorSFTNonce = 1n;

        await checkHousingTokenAttr({
          user: investor,
          expectedMintedAmt: 1_000_000n,
          expectedRPS: 0n,
          nonce: investorSFTNonce,
        });

        // Capture initial state
        const initialRewardsReserve = await housingProject.rewardsReserve();
        const initialCoinbaseBalance = await coinbase.balanceOf(investor);

        // Claim rent reward
        await housingProject.connect(investor).claimRentReward(investorSFTNonce);
        investorSFTNonce += 1n;

        // Verify rewards reserve is decremented
        expect(await housingProject.rewardsReserve()).to.be.below(initialRewardsReserve);

        // Verify the investor's token attributes have been updated
        await checkHousingTokenAttr({
          user: investor,
          expectedMintedAmt: 1_000_000n,
          expectedRPS: await housingProject.rewardPerShare(),
          nonce: investorSFTNonce,
        });

        // Verify the investor's balance has increased
        expect(await coinbase.balanceOf(investor)).to.be.above(initialCoinbaseBalance);

        // Verify nonce update
        expect(await housingSFT.hasSFT(investor, investorSFTNonce)).to.equal(true);
      });

      describe("rentClaimable", function () {
        it("should correctly calculate claimable rent rewards", async function () {
          const { housingProject, investor, projectFunding, housingSFT, payRent } =
            await loadFixture(claimRentRewardFixtures);

          const rentAmount = ethers.parseUnits("500", 18);

          await payRent(rentAmount);

          // Claiming SFT after rent was paid
          await projectFunding.connect(investor).claimProjectTokens(1);
          const { rewardsPerShare, originalOwner, tokenWeight } = await housingSFT.getUserSFT(investor, 1);

          // Check claimable rent rewards
          const claimableRent = await housingProject.rentClaimable({ rewardsPerShare, tokenWeight, originalOwner });

          // 70%
          const investorsShare = (rentAmount * 75n) / 100n;
          // Referrer gets 0.3% as there bonus
          const expectedClaimableRent = (investorsShare * 99_70n) / 100_00n;

          expect(claimableRent).to.equal(expectedClaimableRent);
        });
      });
    });
  });
});
