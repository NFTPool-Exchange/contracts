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
            (uint256 nft_reserve, uint256 stable_reserve) = getReserves();

            uint256 stable_amount = (nftAmt * stable_reserve) / nft_reserve + 1;
            require(
                stable_amount <= maxStableAmt,
                "Insufficient Stable Amount"
            );

            nft.safeTransferFrom(msg.sender, address(this), nftID, nftAmt, "");
            stable.safeTransferFrom(msg.sender, address(this), stable_amount);

            lpMinted = (nftAmt * totalSupply()) / nft_reserve;
        }

        _mint(msg.sender, lpMinted);
    }

    function removeLiquidity(uint256 lpAmt)
        external
        returns (uint256 nft_amount, uint256 stable_amount)
    {
        (uint256 nft_reserve, uint256 stable_reserve) = getReserves();

        nft_amount = (lpAmt * nft_reserve) / totalSupply();
        stable_amount = (lpAmt * stable_reserve) / totalSupply();

        _burn(msg.sender, lpAmt);

        nft.safeTransferFrom(address(this), msg.sender, nftID, nft_amount, "");
        stable.safeTransferFrom(address(this), msg.sender, stable_amount);
    }

    function nftToStable(uint256 nftAmt)
        public
        returns (uint256 stables_bought)
    {
        nft.safeTransferFrom(msg.sender, address(this), nftID, nftAmt, "");

        stables_bought = getPriceNftToStable(nftAmt);

        stable.safeTransfer(msg.sender, stables_bought);
    }

    function stableToNft(uint256 stableAmt)
        public
        returns (uint256 nfts_bought)
    {
        stable.safeTransferFrom(msg.sender, address(this), stableAmt);

        nfts_bought = getPriceStableToNft(stableAmt);

        nft.safeTransferFrom(address(this), msg.sender, nftID, nfts_bought, "");
    }

    function getReserves()
        public
        view
        returns (uint256 nft_reserve, uint256 stable_reserve)
    {
        nft_reserve = nft.balanceOf(address(this), nftID);
        stable_reserve = stable.balanceOf(address(this));
    }

    function getPriceNftToStable(uint256 nftAmt)
        public
        view
        returns (uint256 stables_bought)
    {
        (uint256 nft_reserve, uint256 stable_reserve) = getReserves();
        stables_bought = price(nftAmt, nft_reserve, stable_reserve);
    }

    function getPriceStableToNft(uint256 stableAmt)
        public
        view
        returns (uint256 nfts_bought)
    {
        (uint256 nft_reserve, uint256 stable_reserve) = getReserves();
        nfts_bought = price(stableAmt, stable_reserve, nft_reserve);
    }

    function price(
        uint256 input_amount,
        uint256 input_reserve,
        uint256 output_reserve
    ) public pure returns (uint256) {
        uint256 input_amount_with_fee = input_amount * 997;
        uint256 numerator = input_amount_with_fee * output_reserve;
        uint256 denominator = input_reserve * 1000 + input_amount_with_fee;

        return numerator / denominator;
    }
}
