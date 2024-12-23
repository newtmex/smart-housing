import { ethers } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployProjectFundingContract: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const coinbaseAddress = await (await ethers.getContract("Coinbase", deployer)).getAddress();

  const newLkSHTlib = await ethers.deployContract("NewLkSHT");
  await newLkSHTlib.waitForDeployment();

  const newHousingProjectLib = await ethers.deployContract("NewHousingProject");
  await newHousingProjectLib.waitForDeployment();

  await deploy("ProjectFunding", {
    from: deployer,
    args: [coinbaseAddress],

    libraries: {
      NewLkSHT: await newLkSHTlib.getAddress(),
      NewHousingProject: await newHousingProjectLib.getAddress(),
    },
    log: true,
  });
};

export default deployProjectFundingContract;

deployProjectFundingContract.tags = ["ProjectFunding", "Start-ICO"];
