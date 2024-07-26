import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { ZeroAddress } from "ethers";

describe("SmartHousing", function () {
  async function deployFixtures() {
    const [owner, projectFunder, coinbase, ...otherUsers] = await ethers.getSigners();

    const SmartHousing = await ethers.getContractFactory("SmartHousing");
    const smartHousing = await SmartHousing.deploy(coinbase.address, projectFunder.address);

    return { smartHousing, owner, projectFunder, coinbase, otherUsers };
  }

  describe("Deployment", function () {
    it("Should set the right owner, project funder, and coinbase", async function () {
      const { smartHousing, owner, projectFunder, coinbase } = await loadFixture(deployFixtures);

      expect(await smartHousing.owner()).to.equal(owner.address);
      expect(await smartHousing.projectFundingAddress()).to.equal(projectFunder.address);
      expect(await smartHousing.coinbaseAddress()).to.equal(coinbase.address);
    });
  });

  describe("User Registration", function () {
    it("Should register a new user", async function () {
      const { smartHousing, projectFunder, otherUsers } = await loadFixture(deployFixtures);
      const [user] = otherUsers;

      const tx = await smartHousing.connect(projectFunder).createRefIDViaProxy(user.address, 0);
      await tx.wait();

      const userId = await smartHousing.getUserId(user.address);
      expect(userId).to.equal(1);

      const referrer = await smartHousing.getReferrer(user.address);
      expect(referrer.referrerId).to.equal(0);
      expect(referrer.referrerAddress).to.equal(ZeroAddress);
    });

    it("Should register a user with a referrer", async function () {
      const { smartHousing, projectFunder, otherUsers } = await loadFixture(deployFixtures);
      const [referrer, user] = otherUsers;

      await smartHousing.connect(projectFunder).createRefIDViaProxy(referrer.address, 0);

      const referrerId = await smartHousing.getUserId(referrer.address);
      await smartHousing.connect(projectFunder).createRefIDViaProxy(user.address, referrerId);

      const userId = await smartHousing.getUserId(user.address);
      expect(userId).to.equal(2);

      const referrerInfo = await smartHousing.getReferrer(user.address);
      expect(referrerInfo.referrerId).to.equal(referrerId);
      expect(referrerInfo.referrerAddress).to.equal(referrer.address);
    });

    it("Should not allow non-project funder to register user", async function () {
      const { smartHousing, otherUsers } = await loadFixture(deployFixtures);
      const [user, nonFunder] = otherUsers;

      await expect(smartHousing.connect(nonFunder).createRefIDViaProxy(user.address, 0)).to.be.revertedWith(
        "Caller is not the project funder",
      );
    });
  });
});
