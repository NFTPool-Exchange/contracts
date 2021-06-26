// SPDX-License-Identifier: NONE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract Exchange is ERC20, ERC1155Holder {
    using SafeERC20 for IERC20;

    IERC20 public immutable ERC20Token;
    IERC1155 public immutable ERC1155Token;
    uint256 public immutable ERC1155ID;

    constructor(
        IERC20 _ERC20Token,
        IERC1155 _ERC1155Token,
        uint256 _ERC1155ID
    ) ERC20("NFTPool LP", "NFTLP") {
        require(
            address(_ERC20Token) != address(0) &&
                address(_ERC1155Token) != address(0),
            "Null Address"
        );

        ERC20Token = _ERC20Token;
        ERC1155Token = _ERC1155Token;
        ERC1155ID = _ERC1155ID;
    }

    function addLiquidity(uint256 _ERC1155Amount, uint256 _maxERC20Amount)
        external
        returns (uint256 lpMinted)
    {
        if (totalSupply() == 0) {
            ERC1155Token.safeTransferFrom(
                msg.sender,
                address(this),
                ERC1155ID,
                _ERC1155Amount,
                ""
            );
            ERC20Token.safeTransferFrom(
                msg.sender,
                address(this),
                _maxERC20Amount
            );

            lpMinted = _maxERC20Amount;
        } else {
            (uint256 ERC1155Reserve, uint256 ERC20Reserve) = getReserves();

            uint256 ERC20Amount = (_ERC1155Amount * ERC20Reserve) /
                ERC1155Reserve +
                1;
            require(
                ERC20Amount <= _maxERC20Amount,
                "Insufficient Stable Amount"
            );

            ERC1155Token.safeTransferFrom(
                msg.sender,
                address(this),
                ERC1155ID,
                _ERC1155Amount,
                ""
            );
            ERC20Token.safeTransferFrom(msg.sender, address(this), ERC20Amount);

            lpMinted = (_ERC1155Amount * totalSupply()) / ERC1155Reserve;
        }

        _mint(msg.sender, lpMinted);
    }

    function removeLiquidity(uint256 _lpAmt)
        external
        returns (uint256 ERC1155Amount, uint256 ERC20Amount)
    {
        (uint256 ERC1155Reserve, uint256 ERC20Reserve) = getReserves();

        ERC1155Amount = (_lpAmt * ERC1155Reserve) / totalSupply();
        ERC20Amount = (_lpAmt * ERC20Reserve) / totalSupply();

        _burn(msg.sender, _lpAmt);

        ERC1155Token.safeTransferFrom(
            address(this),
            msg.sender,
            ERC1155ID,
            ERC1155Amount,
            ""
        );
        ERC20Token.safeTransferFrom(address(this), msg.sender, ERC20Amount);
    }

    function ERC1155ToERC20(uint256 _ERC1155Amount)
        public
        returns (uint256 ERC20Bought)
    {
        ERC20Bought = getPriceERC1155toERC20(_ERC1155Amount);

        ERC1155Token.safeTransferFrom(
            msg.sender,
            address(this),
            ERC1155ID,
            _ERC1155Amount,
            ""
        );
        ERC20Token.safeTransfer(msg.sender, ERC20Bought);
    }

    function ERC20toERC1155(uint256 _ERC20Amount)
        public
        returns (uint256 ERC1155Bought)
    {
        ERC1155Bought = getPriceERC20toERC1155(_ERC20Amount);

        ERC20Token.safeTransferFrom(msg.sender, address(this), _ERC20Amount);
        ERC1155Token.safeTransferFrom(
            address(this),
            msg.sender,
            ERC1155ID,
            ERC1155Bought,
            ""
        );
    }

    function getReserves()
        public
        view
        returns (uint256 ERC1155Reserve, uint256 ERC20Reserve)
    {
        ERC1155Reserve = ERC1155Token.balanceOf(address(this), ERC1155ID);
        ERC20Reserve = ERC20Token.balanceOf(address(this));
    }

    function getPriceERC1155toERC20(uint256 _ERC1155Amount)
        public
        view
        returns (uint256 ERC20Bought)
    {
        (uint256 ERC1155Reserve, uint256 ERC20Reserve) = getReserves();
        ERC20Bought = price(_ERC1155Amount, ERC1155Reserve, ERC20Reserve);
    }

    function getPriceERC20toERC1155(uint256 _ERC20Amount)
        public
        view
        returns (uint256 ERC1155Bought)
    {
        (uint256 ERC1155Reserve, uint256 ERC20Reserve) = getReserves();
        ERC1155Bought = price(_ERC20Amount, ERC20Reserve, ERC1155Reserve);
    }

    function price(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        uint256 inputAmountWithFee = inputAmount * 997;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = inputReserve * 1000 + inputAmountWithFee;

        return numerator / denominator;
    }
}
