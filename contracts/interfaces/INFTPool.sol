// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface INFTPool is IERC20 {
    function ERC20Token() external view returns (IERC20);

    function ERC1155Token() external view returns (IERC1155);

    function ERC1155ID() external view returns (uint256);

    function FEE_MULTIPLIER() external view returns (uint256);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external view returns (bytes32);

    function nonces(address) external view returns (uint256);

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    function addLiquidity(
        uint256 _ERC1155Amount,
        uint256 _maxERC20Amount,
        uint256 _deadline
    ) external returns (uint256 ERC20Amount, uint256 lpMinted);

    function removeLiquidity(
        uint256 _lpAmount,
        uint256 _minERC1155,
        uint256 _minERC20,
        uint256 _deadline
    ) external returns (uint256 ERC1155Amount, uint256 ERC20Amount);

    function swapExactERC1155ToERC20(
        uint256 _ERC1155Amount,
        uint256 _minERC20,
        uint256 _deadline
    ) external returns (uint256 ERC20Bought);

    function swapERC20toERC1155Exact(
        uint256 _maxERC20,
        uint256 _ERC1155Amount,
        uint256 _deadline
    ) external returns (uint256 ERC20Sold);

    function getReserves()
        external
        view
        returns (uint256 ERC1155Reserve, uint256 ERC20Reserve);

    /// fee deducted in ERC20
    function getPriceERC1155toERC20(uint256 _ERC1155Amount)
        external
        view
        returns (uint256 ERC20Bought);

    /// fee deducted in ERC20
    function getPriceERC20toERC1155Exact(uint256 _ERC1155Amount)
        external
        view
        returns (uint256 ERC20Required);

    /// fee deducted in OutputToken
    function calculateOutputAmount_OutputFee(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) external pure returns (uint256);

    /// fee deducted in InputToken
    function calculateInputAmount_InputFee(
        uint256 outputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) external pure returns (uint256 price);
}
