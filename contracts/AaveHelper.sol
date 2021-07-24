// SPDX-License-Identifier: NONE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {INFTPool} from "./interfaces/INFTPool.sol";

interface IAaveLendingPoolAddressesProvider {
    function getLendingPool() external view returns (address);

    function getLendingPoolCore() external view returns (address payable);
}

interface IAaveLendingPoolCore {
    function getReserveATokenAddress(address _reserve)
        external
        view
        returns (address);
}

interface IAaveLendingPool {
    function deposit(
        address _reserve,
        uint256 _amount,
        uint16 _referralCode
    ) external payable;
}

contract AaveHelper is ERC1155Holder {
    using SafeERC20 for IERC20;

    // KOVAN
    IAaveLendingPoolAddressesProvider
        public constant lendingPoolAddressProvider =
        IAaveLendingPoolAddressesProvider(
            0x88757f2f99175387aB4C6a4b3067c77A695b0349
        );
    IERC20 public constant DAI =
        IERC20(0xFf795577d9AC8bD7D90Ee22b6C1703490b6512FD);
    address public aaveLendingPoolCore;
    IERC20 public immutable aDAI;

    constructor() {
        aaveLendingPoolCore = lendingPoolAddressProvider.getLendingPoolCore();
        aDAI = IERC20(
            IAaveLendingPoolCore(aaveLendingPoolCore).getReserveATokenAddress(
                address(DAI)
            )
        );
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
        DAI.safeApprove(aaveLendingPoolCore, 0);
        DAI.safeApprove(aaveLendingPoolCore, _maxERC20Amount);

        IAaveLendingPool(lendingPoolAddressProvider.getLendingPool()).deposit(
            address(DAI),
            _maxERC20Amount,
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
