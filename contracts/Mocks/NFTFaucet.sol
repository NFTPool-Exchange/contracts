// SPDX-License-Identifier: NONE
pragma solidity ^0.6.0;

import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155Holder.sol";

contract NFTFaucet is ERC1155Holder {
    IERC1155 public nft;
    uint256 public nftID;
    
    constructor(
        IERC1155 _ERC1155NFT,
        uint256 _nftID
    ) public {
        nft = _ERC1155NFT;
        nftID = _nftID;
    }
    
    function mint() external {
        nft.safeTransferFrom(address(this), msg.sender, nftID, 1, "");
    }
}