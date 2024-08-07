import dotenv from "dotenv";
dotenv.config();

import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { parseEther, ZeroAddress } from "ethers";
import { ethers } from "hardhat";
import { Coinbase, ProjectFunding, SmartHousing } from "../typechain-types";
import { time } from "@nomicfoundation/hardhat-network-helpers";

const deployHousingProject: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();

  const smartHousing = await ethers.getContract<SmartHousing>("SmartHousing", deployer);
  const projectFunding = await ethers.getContract<ProjectFunding>("ProjectFunding", deployer);
  const coinbase = await ethers.getContract<Coinbase>("Coinbase", deployer);

  const fundingToken = await ethers.deployContract("MintableERC20", ["FundingToken", "FTK"], { from: deployer });

  const testers = process.env.TESTERS?.split(",") || [];
  for (const tester of testers) {
    await fundingToken.mint(tester, parseEther("1500"));
  }

  const currentTimestamp = await time.latest();

  await coinbase.startICO(
    "UloAku",
    "AKU",
    projectFunding,
    smartHousing,
    fundingToken,
    parseEther("20"),
    currentTimestamp * 3,
  );

  // Done to have the abi in front end
  await hre.deployments.deploy("HousingProject", {
    from: deployer,
    args: ["", "", ZeroAddress],
  });
  // await hre.deployments.deploy("ERC1155", {
  //   from: deployer,
  //   args: [""],
  // });
  await hre.deployments.deploy("LkSHT", {
    from: deployer,
    args: ["", ""],
  });
  await hre.deployments.deploy("HousingSFT", {
    from: deployer,
    args: ["", ""],
  });

  const signer = await ethers.getSigner(deployer);
  if (hre.network.name == "localhost") {
    // Send network tokens
    await Promise.all(testers.map(tester => signer.sendTransaction({ value: parseEther("99"), to: tester })));
  }
};

export default deployHousingProject;

// Tags are useful if you have multiple deploy files and only want to run one of them.
// e.g. yarn deploy --tags HousingProject
deployHousingProject.tags = ["HousingProject"];
