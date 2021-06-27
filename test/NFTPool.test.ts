import { ethers, waffle } from "hardhat";
import { parseEther } from "@ethersproject/units";
import { AddressZero, MaxUint256, HashZero } from "@ethersproject/constants";
import { SignerWithAddress } from "@nomiclabs/hardhat-ethers/signers";
import { BigNumber } from "ethers";
import { solidity } from "ethereum-waffle";
import chai from "chai";

chai.use(solidity);
const { expect } = chai;
const { deployContract } = waffle;

import NFTPoolArtifact from "../artifacts/contracts/NFTPool.sol/NFTPool.json";
import DAIArtifact from "../artifacts/contracts/Mocks/DAI.sol/DAI.json";
import NFTArtifact from "../artifacts/contracts/Mocks/NFT.sol/NFT.json";
import { NFTPool } from "../typechain/NFTPool";
import { DAI } from "../typechain/DAI";
import { NFT } from "../typechain/NFT";

const toDecimal = (amount: BigNumber, decimals = 18) => {
  const divisor = BigNumber.from("10").pow(BigNumber.from(decimals));
  const beforeDec = BigNumber.from(amount).div(divisor).toString();
  var afterDec = BigNumber.from(amount).mod(divisor).toString();

  if (afterDec.length < decimals && afterDec != "0") {
    // pad with extra zeroes
    const pad = Array(decimals + 1).join("0");
    afterDec = (pad + afterDec).slice(-decimals);
  }

  return beforeDec + "." + afterDec;
};

describe("NFTPool", () => {
  let nftPool: NFTPool;
  let dai: DAI;
  let nft: NFT;
  const nftID = 10;

  let deployer: SignerWithAddress;
  let lpProvider0: SignerWithAddress;
  let lpProvider1: SignerWithAddress;
  let swapper0: SignerWithAddress;
  let swapper1: SignerWithAddress;

  before(async () => {
    [deployer, lpProvider0, lpProvider1, swapper0, swapper1] =
      await ethers.getSigners();
  });

  const reset = async () => {
    dai = (await deployContract(deployer, DAIArtifact)) as DAI;
    nft = (await deployContract(deployer, NFTArtifact)) as NFT;
    nftPool = (await deployContract(deployer, NFTPoolArtifact, [
      dai.address,
      nft.address,
      nftID,
    ])) as NFTPool;

    // transfer DAI to other signers
    await dai
      .connect(deployer)
      .transfer(lpProvider0.address, parseEther("1000000")); // 1M DAI
    await dai
      .connect(deployer)
      .transfer(lpProvider1.address, parseEther("1000000")); // 1M DAI
    await dai
      .connect(deployer)
      .transfer(swapper0.address, parseEther("1000000")); // 1M DAI
    await dai
      .connect(deployer)
      .transfer(swapper1.address, parseEther("1000000")); // 1M DAI

    // transfer NFT to other signers
    await nft
      .connect(deployer)
      .safeTransferFrom(
        deployer.address,
        lpProvider0.address,
        nftID,
        1000,
        HashZero
      );
    await nft
      .connect(deployer)
      .safeTransferFrom(
        deployer.address,
        lpProvider1.address,
        nftID,
        1000,
        HashZero
      );
    await nft
      .connect(deployer)
      .safeTransferFrom(
        deployer.address,
        swapper0.address,
        nftID,
        1000,
        HashZero
      );
    await nft
      .connect(deployer)
      .safeTransferFrom(
        deployer.address,
        swapper1.address,
        nftID,
        1000,
        HashZero
      );
  };

  describe("addLiquidity", () => {
    before(async () => {
      await reset();
    });

    it("should Add Liquidity to the Pool by lpProvider0", async () => {
      const user = lpProvider0;
      const ERC1155Amount = 500;
      const ERC20Amount = parseEther("500000"); // so price of 1 NFT = 1000 DAI
      const expectedLiquidity = ERC20Amount;

      // approve tokens
      await dai.connect(user).approve(nftPool.address, ERC20Amount);
      await nft.connect(user).setApprovalForAll(nftPool.address, true);

      const preDAIBalance = await dai.balanceOf(user.address);
      const preNFTBalance = await nft.balanceOf(user.address, nftID);
      // add liquity
      await expect(
        nftPool
          .connect(user)
          .addLiquidity(ERC1155Amount, ERC20Amount, MaxUint256)
      )
        .to.emit(nftPool, "Mint")
        .withArgs(user.address, ERC1155Amount, ERC20Amount, expectedLiquidity);

      const postDAIBalance = await dai.balanceOf(user.address);
      const postNFTBalance = await nft.balanceOf(user.address, nftID);

      const lpReceived = await nftPool.balanceOf(user.address);

      expect(lpReceived).to.eq(expectedLiquidity);
      expect(preDAIBalance.sub(postDAIBalance)).to.eq(ERC20Amount);
      expect(preNFTBalance.sub(postNFTBalance)).to.eq(ERC1155Amount);
    });

    it("should Add Liquidity to the Pool by lpProvider1", async () => {
      const user = lpProvider1;
      const ERC1155Amount = 500;
      const expectedERC20Amount = parseEther("500000"); // as price of 1 NFT = 1000 DAI
      const expectedLiquidity = parseEther("500000");

      // approve tokens
      await dai.connect(user).approve(nftPool.address, MaxUint256);
      await nft.connect(user).setApprovalForAll(nftPool.address, true);

      const preDAIBalance = await dai.balanceOf(user.address);
      const preNFTBalance = await nft.balanceOf(user.address, nftID);
      // add liquity
      await expect(
        nftPool
          .connect(user)
          .addLiquidity(ERC1155Amount, MaxUint256, MaxUint256)
      )
        .to.emit(nftPool, "Mint")
        .withArgs(
          user.address,
          ERC1155Amount,
          expectedERC20Amount,
          expectedLiquidity
        );

      const postDAIBalance = await dai.balanceOf(user.address);
      const postNFTBalance = await nft.balanceOf(user.address, nftID);

      const lpReceived = await nftPool.balanceOf(user.address);

      expect(lpReceived).to.eq(expectedLiquidity);
      expect(preDAIBalance.sub(postDAIBalance)).to.eq(expectedERC20Amount);
      expect(preNFTBalance.sub(postNFTBalance)).to.eq(ERC1155Amount);
    });
  });

  describe("removeLiquidity", () => {
    const ERC1155Amount = 500;
    const ERC20Amount = parseEther("500000");
    let lpBalance: BigNumber;

    beforeEach(async () => {
      await reset();

      const user = lpProvider0;

      await dai.connect(user).approve(nftPool.address, ERC20Amount);
      await nft.connect(user).setApprovalForAll(nftPool.address, true);

      // add liquity
      await nftPool
        .connect(user)
        .addLiquidity(ERC1155Amount, ERC20Amount, MaxUint256);

      lpBalance = await nftPool.balanceOf(user.address);
    });

    it("should Remove Liquidity from the Pool", async () => {
      const user = lpProvider0;
      const expectedERC1155Amount = 500;
      const expectedERC20Amount = parseEther("500000");

      const preLpBalance = await nftPool.balanceOf(user.address);
      const preDAIBalance = await dai.balanceOf(user.address);
      const preNFTBalance = await nft.balanceOf(user.address, nftID);

      await expect(
        nftPool.connect(user).removeLiquidity(lpBalance, 0, 0, MaxUint256)
      )
        .to.emit(nftPool, "Burn")
        .withArgs(
          user.address,
          expectedERC1155Amount,
          expectedERC20Amount,
          lpBalance
        );

      const postLpBalance = await nftPool.balanceOf(user.address);
      const postDAIBalance = await dai.balanceOf(user.address);
      const postNFTBalance = await nft.balanceOf(user.address, nftID);

      expect(preLpBalance.sub(postLpBalance)).to.eq(lpBalance);
      expect(postDAIBalance.sub(preDAIBalance)).to.eq(expectedERC20Amount);
      expect(postNFTBalance.sub(preNFTBalance)).to.eq(ERC1155Amount);
    });
  });

  describe("SwapExactERC1155ToERC20", () => {
    before(async () => {
      await reset();

      const user = lpProvider0;
      const ERC1155Amount = 500;
      const ERC20Amount = parseEther("500000");

      await dai.connect(user).approve(nftPool.address, ERC20Amount);
      await nft.connect(user).setApprovalForAll(nftPool.address, true);

      // add liquity
      await nftPool
        .connect(user)
        .addLiquidity(ERC1155Amount, ERC20Amount, MaxUint256);
    });

    it("should swap NFT to DAI by swapper0", async () => {
      const user = swapper0;
      const ERC1155AmountToSwap = 2;
      const expectedDAIReceived = parseEther("1986.055776892430278884");

      await nft.connect(user).setApprovalForAll(nftPool.address, true);

      const preNFTBalance = await nft.balanceOf(user.address, nftID);
      const preDAIBalance = await dai.balanceOf(user.address);

      await expect(
        nftPool
          .connect(user)
          .SwapExactERC1155ToERC20(ERC1155AmountToSwap, 0, MaxUint256)
      )
        .to.emit(nftPool, "SwapERC1155ToERC20")
        .withArgs(user.address, ERC1155AmountToSwap, expectedDAIReceived);

      const postNFTBalance = await nft.balanceOf(user.address, nftID);
      const postDAIBalance = await dai.balanceOf(user.address);

      console.log("NFT Spent: ", preNFTBalance.sub(postNFTBalance).toString());
      console.log("DAI Bought: ", toDecimal(postDAIBalance.sub(preDAIBalance)));

      expect(preNFTBalance.sub(postNFTBalance)).to.eq(ERC1155AmountToSwap);
      expect(postDAIBalance.sub(preDAIBalance)).to.eq(expectedDAIReceived);
    });
  });

  describe("SwapERC20toERC1155Exact", () => {
    beforeEach(async () => {
      await reset();

      const user = lpProvider0;
      const ERC1155Amount = 500;
      const ERC20Amount = parseEther("500000");

      await dai.connect(user).approve(nftPool.address, ERC20Amount);
      await nft.connect(user).setApprovalForAll(nftPool.address, true);

      // add liquity
      await nftPool
        .connect(user)
        .addLiquidity(ERC1155Amount, ERC20Amount, MaxUint256);
    });

    it("should swap DAI to NFT by swapper0", async () => {
      const user = swapper0;
      const maxERC20AmountToSwap = parseEther("1500");
      const ERC1155AmountToBuy = 1;
      const expectedDAIToSwap = parseEther("1005.019065211667065325");

      await dai.connect(user).approve(nftPool.address, maxERC20AmountToSwap);

      const preNFTBalance = await nft.balanceOf(user.address, nftID);
      const preDAIBalance = await dai.balanceOf(user.address);

      await expect(
        nftPool
          .connect(user)
          .SwapERC20toERC1155Exact(
            maxERC20AmountToSwap,
            ERC1155AmountToBuy,
            MaxUint256
          )
      )
        .to.emit(nftPool, "SwapERC20ToERC1155")
        .withArgs(user.address, expectedDAIToSwap, ERC1155AmountToBuy);

      const postNFTBalance = await nft.balanceOf(user.address, nftID);
      const postDAIBalance = await dai.balanceOf(user.address);

      console.log("DAI Spent: ", toDecimal(preDAIBalance.sub(postDAIBalance)));
      console.log("NFT Bought: ", postNFTBalance.sub(preNFTBalance).toString());

      expect(postNFTBalance.sub(preNFTBalance)).to.eq(ERC1155AmountToBuy);
      expect(preDAIBalance.sub(postDAIBalance)).to.eq(expectedDAIToSwap);
    });

    it("should Revert if 0 NFT input for Exchange", async () => {
      const user = swapper0;
      const ERC20AmountToSwap = parseEther("100");

      await dai.connect(user).approve(nftPool.address, MaxUint256);

      // Without this check, the user's DAI was getting spent,
      // and they didn't even receive any NFT in return!
      await expect(
        nftPool
          .connect(user)
          .SwapERC20toERC1155Exact(ERC20AmountToSwap, 0, MaxUint256)
      ).to.revertedWith("NFTP: Zero NFTs Requested");
    });
  });
});
