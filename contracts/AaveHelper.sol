// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {INFTPool} from "./interfaces/INFTPool.sol";

interface IAToken {
    function POOL() external returns (address);

    function UNDERLYING_ASSET_ADDRESS() external returns (address);
}

interface IAaveLendingPool {
    function deposit(
        address asset,
        uint256 amount,
        address onBehalfOf,
        uint16 referralCode
    ) external;
}

contract AaveHelper is ERC1155Holder {
    using SafeERC20 for IERC20;

    // KOVAN
    IERC20 public constant DAI =
        IERC20(0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD);
    address public aaveLendingPool;
    IERC20 public immutable aDAI;

    constructor(address _aDAI) {
        aDAI = IERC20(_aDAI);
        aaveLendingPool = IAToken(_aDAI).POOL();
    }

    function addLiquidityWithDAI(
        INFTPool nftPool,
        uint256 _ERC1155Amount,
        uint256 _maxERC20Amount,
        uint256 _deadline
    ) external returns (uint256 ERC20Amount, uint256 lpMinted) {
        if (nftPool.totalSupply() == 0) {
            ERC20Amount = _maxERC20Amount;
        } else {
            ERC20Amount = nftPool.getAddLiquidityAmount(_ERC1155Amount);
            require(
                ERC20Amount <= _maxERC20Amount,
                "Helper: Insufficient ERC20 Amount"
            );
        }

        // get required DAI amount from user
        DAI.safeTransferFrom(msg.sender, address(this), ERC20Amount);
        // get ERC1155 from user
        IERC1155 erc1155Token = nftPool.ERC1155Token();
        uint256 erc1155ID = nftPool.ERC1155ID();
        erc1155Token.safeTransferFrom(
            msg.sender,
            address(this),
            erc1155ID,
            _ERC1155Amount,
            ""
        );

        // convert DAI to aDAI
        DAI.safeApprove(aaveLendingPool, 0);
        DAI.safeApprove(aaveLendingPool, ERC20Amount);

        IAaveLendingPool(aaveLendingPool).deposit(
            address(DAI),
            ERC20Amount,
            address(this),
            0
        );

        // addLiquidity to Pool
        aDAI.safeApprove(address(nftPool), 0);
        aDAI.safeApprove(address(nftPool), ERC20Amount);
        erc1155Token.setApprovalForAll(address(nftPool), true);

        (ERC20Amount, lpMinted) = nftPool.addLiquidity(
            _ERC1155Amount,
            ERC20Amount,
            _deadline
        );

        // send LP tokens to user
        nftPool.transfer(msg.sender, lpMinted);
    }
}
