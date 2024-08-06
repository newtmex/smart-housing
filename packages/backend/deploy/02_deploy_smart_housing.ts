import { ethers } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deploySmartHousingContract: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const coinbaseAddress = await (await ethers.getContract("Coinbase", deployer)).getAddress();
  const projectFundingAddress = await (await ethers.getContract("ProjectFunding", deployer)).getAddress();
  const newHSTlib = await ethers.deployContract("NewHousingStakingToken");

  await deploy("SmartHousing", {
    from: deployer,
    args: [coinbaseAddress, projectFundingAddress],

    libraries: { NewHousingStakingToken: await newHSTlib.getAddress() },
  });
};

export default deploySmartHousingContract;

deploySmartHousingContract.tags = ["SmartHousing", "Start-ICO"];
