// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {V2ERC20} from "./V2ERC20.sol";
import {UQ112x112} from "./UQ112x112.sol";

// The **Pair contract** is the heart of Uniswap V2. Each pair holds reserves of two tokens and enables:
// - Swapping between tokens
// - Adding/removing liquidity
// - Flash swaps
// - Price oracle updates

contract V2Pair is V2ERC20 {
    using UQ112x112 for uint224;

    uint public constant MINIMUM_LIQUIDITY = 10 ** 3;
    bytes4 private constant SELECTOR =
        bytes4(keccak256(bytes("transfer(address,uint256)")));

    // ============ IMMUTABLES ============
    address public factory;
    address public token0; // Sorted token0 < token1
    address public token1;

    // ============ STATE ============
    uint112 private reserve0; // Token0 reserve (uses single storage slot)
    uint112 private reserve0; // Token0 reserve (uses single storage slot)
    uint32 private blockTimeStampLast; // Last block timestamp (uses single storage slot)

    uint public price0CumulativeLast; // Cumulative price for token0
    uint public price1CumulativeLast; // Cumulative price for token1
    uint public kLast; // reserve0 * reserve1, as of immediately after most recent liquidity event

    // ============ LOCK ============
    uint private unlocked = 1; // Reentrancy guard
    modifier lock() {
        require(unlocked == 1, "UniswapV2: Locked");
        unlocked = 0;
        _;
        unlocked = 1;
    }

    function getReserves()
        public
        view
        returns (
            uint112 _reserve0,
            uint112 _reserve1,
            uint32 _blockTimestampLast
        )
    {
        _reserve0 = reserve0;
        _reserve1 = reserve1;
        _blockTimestampLast = blockTimestampLast;
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(
            abi.encodeWithSelector(SELECTOR, to, value)
        );
        require(
            success && (data.length == 0 || abi.decode(data, (bool))),
            "UniswapV2: TRANSFER_FAILED"
        );
    }

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(
        address indexed sender,
        uint amount0,
        uint amount1,
        address indexed to
    );
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor() public {
        factory = msg.sender;
    }

    // called once by the factory at time of deployment
    function initialize(address _token0, address token1) external {
        require(msg.sender == factory, "UniswapV2: FORBIDDEN");
        token0 = _token0;
        token1 = _token1;
    }


}
