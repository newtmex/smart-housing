import { expect } from "chai";
import { ethers } from "hardhat";
import { loadFixture } from "@nomicfoundation/hardhat-toolbox/network-helpers";
import { parseEther, ZeroAddress } from "ethers";

describe("SmartHousing", function () {
  async function deployFixtures() {
    const [owner, projectFunder, coinbase, ...otherUsers] = await ethers.getSigners();

    const SmartHousing = await ethers.getContractFactory("SmartHousing");
    const smartHousing = await SmartHousing.deploy(coinbase, projectFunder);

    const housingProject = await ethers.deployContract("HousingProject", [smartHousing]);

    return {
      smartHousing,
      owner,
      projectFunder,
      coinbase,
      otherUsers,
      housingProject,
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
      const { smartHousing, owner, projectFunder, coinbase } = await loadFixture(deployFixtures);

      expect(await smartHousing.owner()).to.equal(owner);
      expect(await smartHousing.projectFundingAddress()).to.equal(projectFunder);
      expect(await smartHousing.coinbaseAddress()).to.equal(coinbase);
    });
  });

  describe("User Registration", function () {
    it("Should register a new user", async function () {
      const { smartHousing, projectFunder, otherUsers } = await loadFixture(deployFixtures);
      const [user] = otherUsers;

      const tx = await smartHousing.connect(projectFunder).createRefIDViaProxy(user, 0);
      await tx.wait();

      const userId = await smartHousing.getUserId(user);
      expect(userId).to.equal(1);

      const referrer = await smartHousing.getReferrer(user);
      expect(referrer.referrerId).to.equal(0);
      expect(referrer.referrerAddress).to.equal(ZeroAddress);
    });

    it("Should register a user with a referrer", async function () {
      const { smartHousing, projectFunder, otherUsers } = await loadFixture(deployFixtures);
      const [referrer, user] = otherUsers;

      await smartHousing.connect(projectFunder).createRefIDViaProxy(referrer, 0);

      const referrerId = await smartHousing.getUserId(referrer);
      await smartHousing.connect(projectFunder).createRefIDViaProxy(user, referrerId);

      const userId = await smartHousing.getUserId(user);
      expect(userId).to.equal(2);

      const referrerInfo = await smartHousing.getReferrer(user);
      expect(referrerInfo.referrerId).to.equal(referrerId);
      expect(referrerInfo.referrerAddress).to.equal(referrer);
    });

    it("Should not allow non-project funder to register user via proxy", async function () {
      const { smartHousing, otherUsers } = await loadFixture(deployFixtures);
      const [user, nonFunder] = otherUsers;

      await expect(smartHousing.connect(nonFunder).createRefIDViaProxy(user, 0)).to.be.revertedWith(
        "Caller is not the project funder",
      );
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
    it("Should add a new project and set permissions", async function () {
      const { smartHousing, projectFunder, otherUsers } = await loadFixture(deployFixtures);
      const [project] = otherUsers;

      await smartHousing.connect(projectFunder).addProject(project);

      const permission = await smartHousing.permissions(project);
      expect(permission).to.equal(1); // Permissions.HOUSING_PROJECT

      const isProjectAdded = (await smartHousing.projectsToken()).includes(project.address);
      expect(isProjectAdded).to.be.true;
    });

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
    //   const { smartHousing, projectFunder, housingProject, setUpSht } = await loadFixture(deployFixtures);

    //   // Add the project
    //   await smartHousing.connect(projectFunder).addProject(housingProject);

    //   // Set up SHT
    //   await setUpSht();

    //   // Add rent
    //   const rentAmount = parseEther("100");
    //   await smartHousing.connect(housingProject).addProjectRent(rentAmount);

    //   // Verify rent addition
    //   const projectData = await smartHousing.projectDets(project);
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
});
