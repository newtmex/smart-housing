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

    const currentTimestamp = await time.latest();

    await projectFunding.deployProject(name, symbol, ZeroAddress, parseEther(fundingGoal), currentTimestamp + 100_000);
  });
