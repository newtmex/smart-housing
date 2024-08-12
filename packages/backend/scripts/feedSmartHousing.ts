import "@nomicfoundation/hardhat-toolbox";
import { task } from "hardhat/config";
import { Coinbase, SmartHousing } from "../typechain-types";

task("feedSmartHousing", "Send all needed tokens from coinbase to smart housing").setAction(async (_, hre) => {
  const { deployer } = await hre.getNamedAccounts();
  const coinbase = await hre.ethers.getContract<Coinbase>("Coinbase", deployer);
  const smartHousing = await hre.ethers.getContract<SmartHousing>("SmartHousing", deployer);

  await coinbase.feedSmartHousing(await smartHousing.getAddress());
});
