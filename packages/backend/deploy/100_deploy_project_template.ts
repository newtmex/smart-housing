import dotenv from "dotenv";
dotenv.config();

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { parseEther, ZeroAddress } from "ethers";
import { ethers } from "hardhat";
import { Coinbase, ProjectFunding, SmartHousing } from "../typechain-types";

const deployHousingProject: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();

  const smartHousing = await ethers.getContract<SmartHousing>("SmartHousing", deployer);
  const projectFunding = await ethers.getContract<ProjectFunding>("ProjectFunding", deployer);
  const coinbase = await ethers.getContract<Coinbase>("Coinbase", deployer);

  const currentBlock = await ethers.provider.getBlockNumber();
  const currentTimestamp = (await ethers.provider.getBlock(currentBlock))!.timestamp;

  const threeWeeks = 3 * 7 * 24 * 3600;
  console.log("starting ICO");
  const startICO = await coinbase.startICO(
    "UloAku",
    "AKU",
    projectFunding,
    smartHousing,
    ZeroAddress,
    parseEther("2.005"),
    currentTimestamp + threeWeeks,
  );
  if (hre.network.name != "localhost") {
    await startICO.wait(3);
  }
  // TODO idealy, this is to be done after successful funding, but it will be teadious
  // to simulate this in demo, hence we do this here with contract modificatino also
  console.log("adding project to ecosystem");
  const addProjectToEcosystem = await projectFunding.addProjectToEcosystem(1n);
  if (hre.network.name != "localhost") {
    await addProjectToEcosystem.wait(3);
  }

  // Done to have the abis in front end

  await hre.deployments.deploy("HousingProject", {
    from: deployer,
    args: ["", "", ZeroAddress, ZeroAddress],
    log: true,
  });
  await hre.deployments.deploy("HousingStakingToken", {
    from: deployer,
    log: true,
  });
  await hre.deployments.deploy("LkSHT", {
    from: deployer,
    args: ["", ""],
    log: true,
  });
  await hre.deployments.deploy("HousingSFT", {
    from: deployer,
    args: ["", ""],
    log: true,
  });

  if (hre.network.name == "localhost") {
    // Send network tokens
    const signer = await ethers.getSigner(deployer);
    const testers = process.env.TESTERS?.split(",") || [];
    await Promise.all(testers.map(tester => signer.sendTransaction({ value: parseEther("99"), to: tester })));
  }
};

export default deployHousingProject;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags HousingProject
deployHousingProject.tags = ["HousingProject"];
