import { DeployFunction } from "hardhat-deploy/types";
import { HardhatRuntimeEnvironment } from "hardhat/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployer } = await hre.getNamedAccounts();
  const { deploy } = hre.deployments;

  const deployed = await deploy("Survey", {
    from: deployer,
    args: [],
    log: true,
  });

  console.log(`Survey contract: `, deployed.address);
};
export default func;
func.tags = ["Survey"];
