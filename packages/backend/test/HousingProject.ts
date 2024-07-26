import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { parseEther, ZeroAddress } from "ethers";

describe("HousingProject", function () {
  // We define a fixture to reuse the same setup in every test.

  const amountRaised = parseEther((5_000_000).toString());
  const name = "Incredible Block";

  async function deployFixtures() {
    const housingProject = await ethers.deployContract("HousingProject", [ZeroAddress, "", amountRaised, name]);

    return { housingProject };
  }

  describe("Deployment", function () {
    it("deploys", async () => {
      const { housingProject } = await loadFixture(deployFixtures);
      expect(await housingProject.name()).to.equal(name);
      expect(await housingProject.amountRaised()).to.equal(amountRaised);
    });
  });
});
