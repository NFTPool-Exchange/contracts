// SPDX-License-Identifier: NONE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";

contract NFTPool is ERC20, ERC1155Holder {
    using SafeERC20 for IERC20;

    IERC20 public immutable ERC20Token;
    IERC1155 public immutable ERC1155Token;
    uint256 public immutable ERC1155ID;
    uint256 public constant FEE_MULTIPLIER = 997;

    // --- EIP712 for Permit  ---
    bytes32 public immutable DOMAIN_SEPARATOR;
    // PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)");
    bytes32 public constant PERMIT_TYPEHASH =
        0x6e71edae12b1b97f4d1f60370fef10105fa2faae0126114a169c64845d6126c9;
    mapping(address => uint256) public nonces;

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
                keccak256(bytes("Zapper")),
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
    ) external {
        require(deadline >= block.timestamp, "NFTLP: EXPIRED");
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
            "NFTLP: INVALID_SIGNATURE"
        );
        _approve(owner, spender, value);
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
            emit Mint(msg.sender, _ERC1155Amount, _maxERC20Amount, lpMinted);
        } else {
            (uint256 ERC1155Reserve, uint256 ERC20Reserve) = getReserves();

            uint256 ERC20Amount = (_ERC1155Amount * ERC20Reserve) /
                ERC1155Reserve +
                1;
            require(
                ERC20Amount <= _maxERC20Amount,
                "Insufficient ERC20 Amount"
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
            emit Mint(msg.sender, _ERC1155Amount, ERC20Amount, lpMinted);
        }

        _mint(msg.sender, lpMinted);
    }

    function removeLiquidity(uint256 _lpAmount)
        external
        returns (uint256 ERC1155Amount, uint256 ERC20Amount)
    {
        (uint256 ERC1155Reserve, uint256 ERC20Reserve) = getReserves();

        ERC1155Amount = (_lpAmount * ERC1155Reserve) / totalSupply();
        ERC20Amount = (_lpAmount * ERC20Reserve) / totalSupply();

        _burn(msg.sender, _lpAmount);
        emit Burn(msg.sender, ERC1155Amount, ERC20Amount, _lpAmount);

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

        emit SwapERC1155ToERC20(msg.sender, _ERC1155Amount, ERC20Bought);
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

        emit SwapERC20ToERC1155(msg.sender, _ERC20Amount, ERC1155Bought);
    }

    function getReserves()
        public
        view
        returns (uint256 ERC1155Reserve, uint256 ERC20Reserve)
    {
        ERC1155Reserve = ERC1155Token.balanceOf(address(this), ERC1155ID);
        ERC20Reserve = ERC20Token.balanceOf(address(this));
    }

    // fee deducted in ERC20
    function getPriceERC1155toERC20(uint256 _ERC1155Amount)
        public
        view
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
    function getPriceERC20toERC1155(uint256 _ERC20Amount)
        public
        view
        returns (uint256 ERC1155Bought)
    {
        (uint256 ERC1155Reserve, uint256 ERC20Reserve) = getReserves();
        ERC1155Bought = calculateOutputAmount_InputFee(
            _ERC20Amount,
            ERC20Reserve,
            ERC1155Reserve
        );
    }

    // fee deducted in InputToken
    function calculateOutputAmount_InputFee(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        uint256 inputAmountWithFee = inputAmount * FEE_MULTIPLIER;
        uint256 numerator = inputAmountWithFee * outputReserve;
        uint256 denominator = inputReserve * 1000 + inputAmountWithFee;

        return numerator / denominator;
    }

    // fee deducted in OutputToken
    function calculateOutputAmount_OutputFee(
        uint256 inputAmount,
        uint256 inputReserve,
        uint256 outputReserve
    ) public pure returns (uint256) {
        uint256 numerator = (inputAmount * outputReserve) * FEE_MULTIPLIER;
        uint256 denominator = (inputReserve + inputAmount) * 1000;

        return numerator / denominator;
    }
}
