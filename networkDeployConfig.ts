import { ethers } from "ethers";

interface ChainAddresses {
  [contractName: string]: string;
}

const chainIds = {
  mainnet: 1,
  ropsten: 3,
  rinkeby: 4,
  goerli: 5,
  kovan: 42,
  ganache: 5777,
  hardhat: 7545,
  bscTestnet: 97,
  bscMainnet: 56,
  polygonTestnet: 80001,
  polygonMainnet: 137,
};

export const KovanTestnet: ChainAddresses = {
  keeperRegistryAddress: "0x4Cb093f226983713164A62138C3F718A5b595F73",
};

export const PolygonTestnet: ChainAddresses = {
  keeperRegistryAddress: "0x6179B349067af80D0c171f43E6d767E4A00775Cd",
};

export const chainIdToConfig: {
  [id: number]: { [contractName: string]: string };
} = {
  [chainIds.kovan]: { ...KovanTestnet },
  [chainIds.polygonTestnet]: { ...PolygonTestnet },
};
