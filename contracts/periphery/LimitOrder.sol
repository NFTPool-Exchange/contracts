// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import {KeeperCompatibleInterface} from "@chainlink/contracts/src/v0.8/KeeperCompatible.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {INFTPool} from "../interfaces/INFTPool.sol";

contract LimitOrder is KeeperCompatibleInterface, ERC1155Holder {
    using SafeERC20 for IERC20;

    struct Order {
        address user;
        INFTPool pool;
        uint256 ERC1155ToBuy;
        uint256 ERC20ToSell;
    }

    address keeperRegistryAddress;

    Order[] public orders;

    constructor(address _keeperRegistryAddress) {
        keeperRegistryAddress = _keeperRegistryAddress;
    }

    modifier onlyKeeper() {
        require(msg.sender == keeperRegistryAddress, "!Keeper");
        _;
    }

    function placeOrder(Order calldata _order) external {
        require(address(_order.pool) != address(0), "Invalid Pool");
        require(
            _order.ERC1155ToBuy != 0 && _order.ERC20ToSell != 0,
            "Invalid Amounts"
        );

        IERC20 erc20 = _order.pool.ERC20Token();
        erc20.safeTransferFrom(msg.sender, address(this), _order.ERC20ToSell);

        orders.push(_order);
    }

    function checkUpkeep(
        bytes calldata /* checkData */
    )
        external
        view
        override
        returns (bool upkeepNeeded, bytes memory performData)
    {
        uint256 ordersToExecCount;
        bool[] memory toExec = new bool[](orders.length);

        for (uint256 i = 0; i < orders.length; i++) {
            uint256 erc20RqdForSwap = orders[i]
                .pool
                .getPriceERC20toERC1155Exact(orders[i].ERC1155ToBuy);

            if (orders[i].ERC20ToSell >= erc20RqdForSwap) {
                toExec[i] = true;
                ordersToExecCount++;
            }
        }

        if (ordersToExecCount > 0) {
            upkeepNeeded = true;

            uint256[] memory ordersToExec = new uint256[](ordersToExecCount);
            uint256 j;
            for (uint256 i = 0; i < orders.length; i++) {
                if (toExec[i]) {
                    ordersToExec[j++] = i;
                }
            }

            performData = abi.encode(ordersToExec);
        }
    }

    function performUpkeep(bytes calldata performData)
        external
        override
        onlyKeeper
    {
        uint256[] memory ordersToExec;
        (ordersToExec) = abi.decode(performData, (uint256[]));

        for (uint256 i = 0; i < ordersToExec.length; i++) {
            _executeOrder(ordersToExec[i]);
        }
    }

    function _executeOrder(uint256 _orderIndex) internal {
        Order memory _order = orders[_orderIndex];

        IERC20 erc20 = _order.pool.ERC20Token();
        erc20.safeApprove(address(_order.pool), _order.ERC20ToSell);

        // swap on NFTPool
        uint256 erc20Sold = _order.pool.swapERC20toERC1155Exact(
            _order.ERC20ToSell,
            _order.ERC1155ToBuy,
            block.timestamp
        );
        // send erc1155 to user
        IERC1155 erc1155 = _order.pool.ERC1155Token();
        erc1155.safeTransferFrom(
            address(this),
            _order.user,
            _order.pool.ERC1155ID(),
            _order.ERC1155ToBuy,
            ""
        );

        // refund extra erc20
        if (erc20Sold < _order.ERC20ToSell) {
            erc20.safeTransfer(_order.user, _order.ERC20ToSell - erc20Sold);
        }

        /// remove order from array
        // replace current executed order with last order in array
        if (orders.length > 1) {
            orders[_orderIndex] = orders[orders.length];
        }
        // remove last order from array
        orders.pop();
    }
}
