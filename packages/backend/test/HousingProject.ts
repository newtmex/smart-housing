import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { BigNumberish, parseEther, ZeroAddress } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";

describe("HousingProject", function () {
  const amountRaised = parseEther((50_000_000).toString());
  const name = "Incredible Block";
  const uri = "https://awesome.address.money/api/tokens/{projectName}/{tokenId}.json";

  async function deployFixtures() {
    const [owner, projectFunding, ...otherUsers] = await ethers.getSigners();
    const sht = await ethers.deployContract("MintableERC20", ["SmartHousingToken", "SHT"]);
    const smartHousing = await ethers.deployContract("SmartHousing", [ZeroAddress, projectFunding]);

    const housingProject = await ethers.deployContract("HousingProject", [smartHousing]);
    await housingProject.setTokenDetails(name, uri, amountRaised, sht);
    await smartHousing.connect(projectFunding).addProject(housingProject);

    return {
      housingProject,
      otherUsers,
      owner,
      sht,
      MAX_SUPPLY: await housingProject.MAX_SUPPLY(),
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
        const { rewardsPerShare, tokenWeight, originalOwner } = await housingProject.getUserSFT(user, nonce);
        expect(rewardsPerShare).to.equal(expectedRPS);
        expect(tokenWeight).to.equal(expectedMintedAmt);
        expect(originalOwner).to.equal(user.address);
      },
    };
  }

  describe("Deployment", function () {
    it("deploys", async () => {
      const { housingProject, owner } = await loadFixture(deployFixtures);
      expect(await housingProject.name()).to.equal(name);
      expect(await housingProject.amountRaised()).to.equal(amountRaised);
      expect(await housingProject.totalSupply()).to.equal(0);
      expect(await housingProject.balanceOf(owner, 1)).to.equal(0);
    });
  });

  describe("mintSFT", async () => {
    it("mints housing SFT for depositor", async () => {
      const {
        housingProject,
        otherUsers: [someUser],
        MAX_SUPPLY,
        checkHousingTokenAttr,
      } = await loadFixture(deployFixtures);

      // This guy is a whale, bought $5,000,000 worth of this project in IPO
      const depositAmount = amountRaised / 10n; //10%
      const expectedMintedAmt = MAX_SUPPLY / 10n;

      await housingProject.mintSFT(depositAmount, someUser);

      expect(await housingProject.balanceOf(someUser, 1)).to.equal(expectedMintedAmt);

      await checkHousingTokenAttr({
        user: someUser,
        expectedMintedAmt,
        expectedRPS: 0n,
        nonce: 1n,
      });

      // Minting more than allowed should throw an error
      await expect(housingProject.mintSFT(amountRaised + 1n, someUser)).to.be.revertedWith(
        "HousingSFT: Max supply exceeded",
      );
    });
  });

  describe("claimRentReward", function () {
    it("can claim rent rewards after minting and receiving rent", async () => {
      const {
        housingProject,
        otherUsers: [, tenant, investor],
        sht,
        checkHousingTokenAttr,
      } = await loadFixture(deployFixtures);

      await housingProject.mintSFT(amountRaised / 100_000n, investor);

      // Pays rent for tenant
      const payRent = async (rent: BigNumberish) => {
        await sht.mint(tenant, rent);
        await sht.connect(tenant).approve(housingProject, rent);
        await housingProject.connect(tenant).receiveRent({ token: sht, amount: rent });
      };
      await payRent(parseEther("20"));

      await checkHousingTokenAttr({
        user: investor,
        expectedMintedAmt: 10n,
        expectedRPS: 0n,
        nonce: 1n,
      });

      await housingProject.connect(investor).claimRentReward(1n);

      // Investor receives rent shares
      expect(await sht.balanceOf(investor)).to.equal(140010000000000);
      // Investor's token RPS increasses, gets 10 units of project
      await checkHousingTokenAttr({
        user: investor,
        expectedMintedAmt: 10n,
        expectedRPS: 15000000000000000000000000000000n,
        nonce: 1n,
      });

      // Claiming again without new rent does nothing
      await housingProject.connect(investor).claimRentReward(1n);
      await checkHousingTokenAttr({
        user: investor,
        expectedMintedAmt: 10n,
        expectedRPS: 15000000000000000000000000000000n,
        nonce: 1n,
      });

      // Claiming again with new rent
      await payRent(parseEther("0.005"));

      await housingProject.connect(investor).claimRentReward(1n);
      // Investor receives rent shares
      expect(await sht.balanceOf(investor)).to.equal(140045002500000);
      // Investor's token RPS increasses, gets 10 units of project
      await checkHousingTokenAttr({
        user: investor,
        expectedMintedAmt: 10n,
        expectedRPS: 15003750000000000000000000000000n,
        nonce: 1n,
      });
    });
  });
});
