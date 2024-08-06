import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const deployCoinbaseContract: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  await deploy("Coinbase", { from: deployer });
};

export default deployCoinbaseContract;

deployCoinbaseContract.tags = ["Coinbase", "Start-ICO"];
