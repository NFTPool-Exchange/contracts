pragma solidity ^0.6.0;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";

contract Exchange is ERC20 {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    IERC20 public stable;
    IERC1155 public nft;
    uint256 public nftID;

    constructor(
        IERC20 _stable,
        IERC1155 _ERC1155NFT,
        uint256 _nftID
    ) public ERC20("NFPE LP", "NFLP") {
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
        returns (uint256 lp_minted)
    {
        uint256 nft_reserve = nft.balanceOf(address(this), nftID);
        uint256 stable_reserve = stable.balanceOf(address(this));

        uint256 stable_amount =
            (nftAmt.mul(stable_reserve).div(nft_reserve)).add(1);
        require(stable_amount <= maxStableAmt, "Insufficient Stable Provided");

        nft.safeTransferFrom(msg.sender, address(this), nftID, nftAmt, "");
        stable.safeTransferFrom(msg.sender, address(this), stable_amount);

        lp_minted = nftAmt.mul(totalSupply()).div(nft_reserve);
        _mint(msg.sender, lp_minted);
    }

    function removeLiquidity(uint256 lpAmt)
        external
        returns (uint256, uint256)
    {
        uint256 nft_reserve = nft.balanceOf(address(this), nftID);
        uint256 stable_reserve = stable.balanceOf(address(this));

        uint256 nft_amount = lpAmt.mul(nft_reserve).div(totalSupply());
        uint256 stable_amount = lpAmt.mul(stable_reserve).div(totalSupply());

        _burn(msg.sender, lpAmt);

        nft.safeTransferFrom(address(this), msg.sender, nftID, nft_amount, "");
        stable.safeTransferFrom(address(this), msg.sender, stable_amount);
    }

    function nftToStable(uint256 nftAmt)
        public
        returns (uint256 stables_bought)
    {
        uint256 nft_reserve = nft.balanceOf(address(this), nftID);
        uint256 stable_reserve = stable.balanceOf(address(this));

        nft.safeTransferFrom(msg.sender, address(this), nftID, nftAmt, "");

        stables_bought = price(nftAmt, nft_reserve, stable_reserve);

        stable.safeTransferFrom(address(this), msg.sender, stables_bought);
    }

    function stableToNft(uint256 stableAmt)
        public
        returns (uint256 nfts_bought)
    {
        uint256 nft_reserve = nft.balanceOf(address(this), nftID);
        uint256 stable_reserve = stable.balanceOf(address(this));

        stable.safeTransferFrom(msg.sender, address(this), stableAmt);

        nfts_bought = price(stableAmt, stable_reserve, nft_reserve);

        nft.safeTransferFrom(address(this), msg.sender, nftID, nfts_bought, "");
    }

    function price(
        uint256 input_amount,
        uint256 input_reserve,
        uint256 output_reserve
    ) public pure returns (uint256) {
        uint256 input_amount_with_fee = input_amount.mul(997);
        uint256 numerator = input_amount_with_fee.mul(output_reserve);
        uint256 denominator =
            input_reserve.mul(1000).add(input_amount_with_fee);

        return numerator / denominator;
    }
}
