import "@nomicfoundation/hardhat-toolbox";
import { task } from "hardhat/config";
import { ProjectFunding } from "../typechain-types";
import { parseEther, ZeroAddress } from "ethers";
import { time } from "@nomicfoundation/hardhat-network-helpers";

task("deployProject", "Deploys new Housing Project")
  .addParam("name", "Housing Project's name")
  .addParam("symbol", "The ticker symbol")
  .addParam("fundingGoal", "The amount of native coins needed")
  .setAction(async ({ name, symbol, fundingGoal }, hre) => {
    const { deployer } = await hre.getNamedAccounts();
    const projectFunding = await hre.ethers.getContract<ProjectFunding>("ProjectFunding", deployer);

    const currentBlock = await hre.ethers.provider.getBlockNumber();
    const currentTimestamp = (await hre.ethers.provider.getBlock(currentBlock))!.timestamp;

    await projectFunding.deployProject(
      name,
      symbol,
      ZeroAddress,
      parseEther(fundingGoal),
      currentTimestamp + 10_000_000,
    );
    const projectId = await projectFunding.projectCount();

    // TODO idealy, this is to be done after successful funding, but it will be teadious
    // to simulate this in demo, hence we do this here with contract modificatino also
    await projectFunding.addProjectToEcosystem(projectId);
  });
