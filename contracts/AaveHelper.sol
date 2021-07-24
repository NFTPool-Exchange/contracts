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
        // get DAI from user
        DAI.safeTransferFrom(msg.sender, address(this), _maxERC20Amount);
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
        DAI.safeApprove(aaveLendingPool, _maxERC20Amount);

        IAaveLendingPool(aaveLendingPool).deposit(
            address(DAI),
            _maxERC20Amount,
            address(this),
            0
        );

        // addLiquidity to Pool
        aDAI.safeApprove(address(nftPool), 0);
        aDAI.safeApprove(address(nftPool), _maxERC20Amount);
        erc1155Token.setApprovalForAll(address(nftPool), true);

        (ERC20Amount, lpMinted) = nftPool.addLiquidity(
            _ERC1155Amount,
            _maxERC20Amount,
            _deadline
        );

        // transfer residue back to user
        uint256 residue = _maxERC20Amount - ERC20Amount;
        if (residue > 0) {
            aDAI.safeTransfer(msg.sender, residue);
        }
    }
}
