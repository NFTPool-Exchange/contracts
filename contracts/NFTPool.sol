// SPDX-License-Identifier: GPL-2.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import "./interfaces/INFTPool.sol";

contract NFTPool is INFTPool, ERC20, ERC1155Holder {
    using SafeERC20 for IERC20;

    IERC20 public immutable override ERC20Token;
    IERC1155 public immutable override ERC1155Token;
    uint256 public immutable override ERC1155ID;
    uint256 public constant override FEE_MULTIPLIER = 997;

    // --- EIP712 for Permit  ---
    bytes32 public immutable override DOMAIN_SEPARATOR;
    // PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant override PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint256) public override nonces;

    event Mint(
        address indexed sender,
        uint256 ERC1155Amount,
        uint256 ERC20Amount,
        uint256 lpAmount
    );
    event Burn(
        address indexed sender,
        uint256 ERC1155Amount,
        uint256 ERC20Amount,
        uint256 lpAmount
    );
    event SwapERC1155ToERC20(
        address indexed sender,
        uint256 ERC1155AmountIn,
        uint256 ERC20AmountOut
    );
    event SwapERC20ToERC1155(
        address indexed sender,
        uint256 ERC20AmountIn,
        uint256 ERC1155AmountOut
    );

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

        uint256 chainId;
        assembly {
            chainId := chainid()
        }
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256(
                    "EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)"
                ),
                keccak256(bytes("NFTPool")),
                keccak256(bytes("1")),
                chainId,
                address(this)
            )
        );
    }

    // --- Approve by permit signature ---
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override {
        require(deadline >= block.timestamp, "NFTP: EXPIRED");
        bytes32 digest = keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR,
                keccak256(
                    abi.encode(
                        PERMIT_TYPEHASH,
                        owner,
                        spender,
                        value,
                        nonces[owner]++,
                        deadline
                    )
                )
            )
        );
        address recoveredAddress = ecrecover(digest, v, r, s);
        require(
            recoveredAddress != address(0) && recoveredAddress == owner,
            "NFTP: INVALID_SIGNATURE"
        );
        _approve(owner, spender, value);
    }

    function addLiquidity(
        uint256 _ERC1155Amount,
        uint256 _maxERC20Amount,
        uint256 _deadline
    ) external override returns (uint256 ERC20Amount, uint256 lpMinted) {
        require(_deadline >= block.timestamp, "NFTP: EXPIRED");

        if (totalSupply() == 0) {
            ERC20Amount = _maxERC20Amount;

            ERC1155Token.safeTransferFrom(
                msg.sender,
                address(this),
                ERC1155ID,
                _ERC1155Amount,
                ""
            );
            ERC20Token.safeTransferFrom(msg.sender, address(this), ERC20Amount);

            lpMinted = _maxERC20Amount;
            emit Mint(msg.sender, _ERC1155Amount, _maxERC20Amount, lpMinted);
        } else {
            bool rounded;
            uint256 ERC1155Reserve;
            (ERC20Amount, rounded, ERC1155Reserve) = _getAddLiquidityAmount(
                _ERC1155Amount
            );
            require(
                ERC20Amount <= _maxERC20Amount,
                "NFTP: Insufficient ERC20 Amount"
            );

            ERC1155Token.safeTransferFrom(
                msg.sender,
                address(this),
                ERC1155ID,
                _ERC1155Amount,
                ""
            );
            ERC20Token.safeTransferFrom(msg.sender, address(this), ERC20Amount);

            // Proportion of the liquidity pool to give to current liquidity provider
            // If rounding error occured, round down to favor previous liquidity providers
            // See https://github.com/0xsequence/niftyswap/issues/19
            lpMinted =
                ((_ERC1155Amount - (rounded ? 1 : 0)) * totalSupply()) /
                ERC1155Reserve;
            emit Mint(msg.sender, _ERC1155Amount, ERC20Amount, lpMinted);
        }

        _mint(msg.sender, lpMinted);
    }

    function removeLiquidity(
        uint256 _lpAmount,
        uint256 _minERC1155,
        uint256 _minERC20,
        uint256 _deadline
    ) external override returns (uint256 ERC1155Amount, uint256 ERC20Amount) {
        require(_deadline >= block.timestamp, "NFTP: EXPIRED");

        (ERC1155Amount, ERC20Amount) = getRemoveLiquidityAmounts(_lpAmount);
        require(
            ERC1155Amount >= _minERC1155,
            "NFTP: Insufficient ERC1155 Amount"
        );
        require(ERC20Amount >= _minERC20, "NFTP: Insufficient ERC20 Amount");

        _burn(msg.sender, _lpAmount);
        emit Burn(msg.sender, ERC1155Amount, ERC20Amount, _lpAmount);

        ERC1155Token.safeTransferFrom(
            address(this),
            msg.sender,
            ERC1155ID,
            ERC1155Amount,
            ""
        );
        ERC20Token.safeTransfer(msg.sender, ERC20Amount);
    }

    function getAddLiquidityAmount(uint256 _ERC1155Amount)
        external
        view
        override
        returns (uint256 ERC20Amount)
    {
        (ERC20Amount, , ) = _getAddLiquidityAmount(_ERC1155Amount);
    }

    function getRemoveLiquidityAmounts(uint256 _lpAmount)
        public
        view
        override
        returns (uint256 ERC1155Amount, uint256 ERC20Amount)
    {
        (uint256 ERC1155Reserve, uint256 ERC20Reserve) = getReserves();

        ERC1155Amount = (_lpAmount * ERC1155Reserve) / totalSupply();
        ERC20Amount = (_lpAmount * ERC20Reserve) / totalSupply();
    }

    function _getAddLiquidityAmount(uint256 _ERC1155Amount)
        internal
        view
        returns (
            uint256 ERC20Amount,
            bool rounded,
            uint256 ERC1155Reserve
        )
    {
        uint256 ERC20Reserve;
        (ERC1155Reserve, ERC20Reserve) = getReserves();

        (ERC20Amount, rounded) = divRound(
            _ERC1155Amount * ERC20Reserve,
            ERC1155Reserve
        );
    }

    function swapExactERC1155ToERC20(
        uint256 _ERC1155Amount,
        uint256 _minERC20,
        uint256 _deadline
    ) public override returns (uint256 ERC20Bought) {
        require(_deadline >= block.timestamp, "NFTP: EXPIRED");

        ERC20Bought = getPriceERC1155toERC20(_ERC1155Amount);
        require(ERC20Bought >= _minERC20, "NFTP: Slippage");

        ERC1155Token.safeTransferFrom(
            msg.sender,
            address(this),
            ERC1155ID,
            _ERC1155Amount,
            ""
        );
        ERC20Token.safeTransfer(msg.sender, ERC20Bought);

        emit SwapERC1155ToERC20(msg.sender, _ERC1155Amount, ERC20Bought);
    }

    function swapERC20toERC1155Exact(
        uint256 _maxERC20,
        uint256 _ERC1155Amount,
        uint256 _deadline
    ) public override returns (uint256 ERC20Sold) {
        require(_deadline >= block.timestamp, "NFTP: EXPIRED");
        require(_ERC1155Amount > 0, "NFTP: Zero NFTs Requested");

        ERC20Sold = getPriceERC20toERC1155Exact(_ERC1155Amount);
        require(ERC20Sold <= _maxERC20, "NFTP: Slippage");

        ERC20Token.safeTransferFrom(msg.sender, address(this), ERC20Sold);
        ERC1155Token.safeTransferFrom(
            address(this),
            msg.sender,
            ERC1155ID,
            _ERC1155Amount,
            ""
        );

        emit SwapERC20ToERC1155(msg.sender, ERC20Sold, _ERC1155Amount);
    }

    function getReserves()
        public
        view
        override
        returns (uint256 ERC1155Reserve, uint256 ERC20Reserve)
    {
        ERC1155Reserve = ERC1155Token.balanceOf(address(this), ERC1155ID);
        ERC20Reserve = ERC20Token.balanceOf(address(this));
    }

    // fee deducted in ERC20
    function getPriceERC1155toERC20(uint256 _ERC1155Amount)
        public
        view
        override
        returns (uint256 ERC20Bought)
    {
        (uint256 ERC1155Reserve, uint256 ERC20Reserve) = getReserves();
        ERC20Bought = calculateOutputAmount_OutputFee(
            _ERC1155Amount,
            ERC1155Reserve,
            ERC20Reserve
        );
    }

    // fee deducted in ERC20
    function getPriceERC20toERC1155Exact(uint256 _ERC1155Amount)
        public
        view
        override
        returns (uint256 ERC20Required)
    {
        (uint256 ERC1155Reserve, uint256 ERC20Reserve) = getReserves();
        ERC20Required = calculateInputAmount_InputFee(
            _ERC1155Amount,
            ERC20Reserve,
            ERC1155Reserve
        );
    }

    // fee deducted in OutputToken
    function calculateOutputAmount_OutputFee(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure override returns (uint256) {
        uint256 numerator = (inputAmount * outputReserve) * FEE_MULTIPLIER;
        uint256 denominator = (inputReserve + inputAmount) * 1000;

        return numerator / denominator; // rounding error will favour NFTPool
    }

    // fee deducted in InputToken
    function calculateInputAmount_InputFee(
        uint256 outputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure override returns (uint256 price) {
        uint256 numerator = (inputReserve * outputAmount) * 1000;
        uint256 denominator = (outputReserve - outputAmount) * FEE_MULTIPLIER;

        (price, ) = divRound(numerator, denominator);
    }

    /**
     * @notice Divides two numbers and add 1 if there is a rounding error
     * @param a Numerator
     * @param b Denominator
     */
    function divRound(uint256 a, uint256 b)
        internal
        pure
        returns (uint256, bool)
    {
        return a % b == 0 ? (a / b, false) : ((a / b) + 1, true);
    }
}
