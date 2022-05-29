import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { utils } from "ethers";

const aaveHelperABI =
  require("../artifacts/contracts/AaveHelper.sol/AaveHelper.json").abi;

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { ethers, deployments, getNamedAccounts, network } = hre;
  const { deploy } = deployments;

  const { deployer } = await getNamedAccounts();

  if (network.name === "kovan") {
    const nftInstance = await deploy("NFT", {
      from: deployer,
      log: true,
    });

    await deploy("NFTFaucet", {
      args: [nftInstance.address, 10],
      from: deployer,
      log: true,
    });

    const daiInstance = await deploy("DAI", {
      from: deployer,
      log: true,
    });

    // aDAI (check if this address updated from here: https://aave.github.io/aave-addresses/kovan.json
    // const aDAIAddress = "0xdCf0aF9e59C002FA3AA091a46196b37530FD48a8";

    // const aaveHelperInstance = await deploy("AaveHelper", {
    //   args: [aDAIAddress],
    //   from: deployer,
    //   log: true,
    // });

    await deploy("NFTPool", {
      args: [daiInstance.address, nftInstance.address, 10],
      from: deployer,
      log: true,
    });

    await deploy("LimitOrder", {
      args: ["0x4Cb093f226983713164A62138C3F718A5b595F73"],
      from: deployer,
      log: true,
    });
  }
};
export default func;
func.tags = ["NFT", "NFTFaucet", "AaveHelper", "NFTPool"];
