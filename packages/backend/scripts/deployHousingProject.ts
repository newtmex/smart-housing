import "@nomicfoundation/hardhat-toolbox";
import { task } from "hardhat/config";
import { ProjectFunding } from "../typechain-types";
import { parseEther, ZeroAddress } from "ethers";

task("deployProject", "Deploys new Housing Project")
  .addParam("name", "Housing Project's name")
  .addParam("symbol", "The ticker symbol")
  .addParam("fundingGoal", "The amount of native coins needed")
  .setAction(async ({ name, symbol, fundingGoal }, hre) => {
    const { deployer } = await hre.getNamedAccounts();
    const projectFunding = await hre.ethers.getContract<ProjectFunding>("ProjectFunding", deployer);

    const currentBlock = await hre.ethers.provider.getBlockNumber();
    const currentTimestamp = (await hre.ethers.provider.getBlock(currentBlock))!.timestamp;

    const threeWeeks = 3 * 7 * 24 * 3600;
    await (
      await projectFunding.deployProject(
        name,
        symbol,
        ZeroAddress,
        parseEther(fundingGoal),
        currentTimestamp + threeWeeks,
      )
    ).wait(3);
    const projectId = await projectFunding.projectCount();

    // TODO idealy, this is to be done after successful funding, but it will be teadious
    // to simulate this in demo, hence we do this here with contract modificatino also
    await (await projectFunding.addProjectToEcosystem(projectId)).wait(3);
  });
