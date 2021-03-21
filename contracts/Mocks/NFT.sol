// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract NFT is ERC1155 {
    constructor() public ERC1155("") {
        _mint(msg.sender, 10, 10000, "");
    }
}