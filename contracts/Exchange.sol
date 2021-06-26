// SPDX-License-Identifier: NONE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Exchange is ERC20, ERC1155Holder {
    using SafeERC20 for IERC20;

    IERC20 public stable;
    IERC1155 public nft;
    uint256 public nftID;

    constructor(
        IERC20 _stable,
        IERC1155 _ERC1155NFT,
        uint256 _nftID
    ) ERC20("NFTPool LP", "NFTLP") {
        require(
            address(_stable) != address(0) &&
                address(_ERC1155NFT) != address(0),
            "Null Address"
        );

        stable = _stable;
        nft = _ERC1155NFT;
        nftID = _nftID;
    }

    function addLiquidity(uint256 nftAmt, uint256 maxStableAmt)
        external
        returns (uint256 lpMinted)
    {
        if (totalSupply() == 0) {
            nft.safeTransferFrom(msg.sender, address(this), nftID, nftAmt, "");
            stable.safeTransferFrom(msg.sender, address(this), maxStableAmt);

            lpMinted = maxStableAmt;
        } else {
            (uint256 nftReserve, uint256 stableReserve) = getReserves();

            uint256 stableAmount = (nftAmt * stableReserve) / nftReserve + 1;
            require(stableAmount <= maxStableAmt, "Insufficient Stable Amount");

            nft.safeTransferFrom(msg.sender, address(this), nftID, nftAmt, "");
            stable.safeTransferFrom(msg.sender, address(this), stableAmount);

            lpMinted = (nftAmt * totalSupply()) / nftReserve;
        }

        _mint(msg.sender, lpMinted);
    }

    function removeLiquidity(uint256 lpAmt)
        external
        returns (uint256 nftAmount, uint256 stableAmount)
    {
        (uint256 nftReserve, uint256 stableReserve) = getReserves();

        nftAmount = (lpAmt * nftReserve) / totalSupply();
        stableAmount = (lpAmt * stableReserve) / totalSupply();

        _burn(msg.sender, lpAmt);

        nft.safeTransferFrom(address(this), msg.sender, nftID, nftAmount, "");
        stable.safeTransferFrom(address(this), msg.sender, stableAmount);
    }

    function nftToStable(uint256 nftAmt)
        public
        returns (uint256 stablesBought)
    {
        stablesBought = getPriceNftToStable(nftAmt);

        nft.safeTransferFrom(msg.sender, address(this), nftID, nftAmt, "");
        stable.safeTransfer(msg.sender, stablesBought);
    }

    function stableToNft(uint256 stableAmt)
        public
        returns (uint256 nftsBought)
    {
        nftsBought = getPriceStableToNft(stableAmt);

        stable.safeTransferFrom(msg.sender, address(this), stableAmt);
        nft.safeTransferFrom(address(this), msg.sender, nftID, nftsBought, "");
    }

    function getReserves()
        public
        view
        returns (uint256 nftReserve, uint256 stableReserve)
    {
        nftReserve = nft.balanceOf(address(this), nftID);
        stableReserve = stable.balanceOf(address(this));
    }

    function getPriceNftToStable(uint256 nftAmt)
        public
        view
        returns (uint256 stablesBought)
    {
        (uint256 nftReserve, uint256 stableReserve) = getReserves();
        stablesBought = price(nftAmt, nftReserve, stableReserve);
    }

    function getPriceStableToNft(uint256 stableAmt)
        public
        view
        returns (uint256 nftsBought)
    {
        (uint256 nftReserve, uint256 stableReserve) = getReserves();
        nftsBought = price(stableAmt, stableReserve, nftReserve);
    }

    function price(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        uint256 inputAmountWithFee = inputAmount * 997;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = inputReserve * 1000 + inputAmountWithFee;

        return numerator / denominator;
    }
}
