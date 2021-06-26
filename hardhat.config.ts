import "hardhat-deploy";
import "hardhat-deploy-ethers";
import "hardhat-abi-exporter";

module.exports = {
  solidity: {
    version: "0.8.6",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
};
