// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BasicERC20} from "../BasicERC20.sol";


interface IERC20Permit {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// Usage: User signs off-chain, dApp submits tx
// User pays No gas for approval~

contract ERC20Permit is BasicERC20, IERC20Permit {
    bytes32 public DOMAIN_SEPARATOR;
    mapping(address => uint256) public nonce;

    bytes32 public constant PERMIT_TYPEHASH = keccak256("Permit(address owner,address spender,uint256 value,uint256 nonce,uint256 deadline)")

    constructor(string memory name, string memory symbol)
    BasicERC20(name, symbol, 18) {
        DOMAIN_SEPARATOR = keccak256(
            abi.encode(
                keccak256("EIP712Domain(string name, string version, uint256 chainId, address verifyingContract)"),
                keccak256(bytes(name)),
                keccak256(bytes(1)),
                block.chainid,
                address(this)
            )
        );
    }

    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(block.timestamp <= deadline, "ERC20Permit: expired deadline");

        bytes32 structHash = keccak256(
            abi.encode(PERMIT_TYPEHASH, owner, spender, value, nonce[owner]++, deadline);
        );

        bytes32 hash = keccak256(abi.encodePacked("\x19\x01",
            DOMAIN_SEPARATOR, structHash)
        );

        address signer = ecrecover(hash, v, r, s)
        require(signer == owner, "ERC20Permit: invalid signature");

        _approve(owner, spender, value);
    }
}