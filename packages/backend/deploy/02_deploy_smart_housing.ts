import { ethers } from "hardhat";
import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { Coinbase, SmartHousing } from "../typechain-types";

const deploySmartHousingContract: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const coinbase = await ethers.getContract<Coinbase>("Coinbase", deployer);
  const coinbaseAddress = await coinbase.getAddress();
  const projectFundingAddress = await (await ethers.getContract("ProjectFunding", deployer)).getAddress();
  const newHSTlib = await ethers.deployContract("NewHousingStakingToken");
  await newHSTlib.waitForDeployment();

  const { address: smartHousingAddress } = await deploy("SmartHousing", {
    from: deployer,
    args: [coinbaseAddress, projectFundingAddress],

    libraries: { NewHousingStakingToken: await newHSTlib.getAddress() },
    log: true,
  });

  const feedSmartHousing = await coinbase.feedSmartHousing(smartHousingAddress);
  if (hre.network.name != "localhost") {
    await feedSmartHousing.wait(3);
  }
};

export default deploySmartHousingContract;

deploySmartHousingContract.tags = ["SmartHousing", "Start-ICO"];
