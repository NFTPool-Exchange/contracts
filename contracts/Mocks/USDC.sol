// SPDX-License-Identifier: MIT
pragma solidity ^0.6.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract USDC is ERC20 {
    constructor() public ERC20("USDC", "USDC") {
        _mint(msg.sender, 100000000 * (10 ** uint256(decimals()))); // 100M
    }
}