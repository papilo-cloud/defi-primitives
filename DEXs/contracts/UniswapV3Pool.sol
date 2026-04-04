// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
/**
 * @title Simplified V3 implementation
 */
contract UniswapV3Pool {
    IERC20 public token0;
    IERC20 public token0;

    struct Tick {
        uint128 liquidityGross;     // Total liquidity at this tick
        uint128 liquidityNet;       // Liquidity delta when crossing
        uint256 feeGrowthOutside0;  // Fees outside this tick
        uint256 feeGrowthOutside1;  // Fees outside this tick
        bool initialized;
    }

    struct Position {
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }

    int24 public tick;              // Current tick
    uint160 public sqrtPriceX96;    // Current sqrt price
    uint128 public liquidity;       // Active liquidity

    mapping(int24 => Tick) public ticks;
    mapping(bytes32 => Position) public positions;

    // Add liquidity to specific range
    function mint(
        address recipient,
        int24 tickLower,
        int24 tickUpper,
        uint128 amount
    ) external returns (uint256 amount0, uint256 amount1) {
        require(tickLower < tickUpper, "Invalid range");
        require(amount > 0, "Amount mst be > 0");

        // Calculate token amounts needed
        (amount0, amount1) = _getAmountsForLiquidity(
            sqrtPriceX96,
            tickLower,
            tickUpper,
            amount
        );

        // Update position
        bytes32 positionKey = keccak256(abi.encodePacked(
            recipient,
            tickLower,
            tickUpper
        ));

        Position storage position = positions[positionKey];
        position.liquidity += amount;

        // Update ticks
        _updateTick(tickLower, amount, false);
        _updateTick(tickUpper, amount, true);

        // If current tick is in range, update active liquidity
        if (tick >= tickLower && tick < tickUpper) {
            liquidity += amount;
        }

        // Transfer tokens
        token0.transferFrom(msg.sender, address(this), amount0);
        token1.transferFrom(msg.sender, address(this), amount1);

        return (amount0, amount1);
    }

    function _updateTick(int24 tickIndex, uint128 liquidityDelta, bool upper) private {
        Tick storage tick = ticks[tickIndex];
        tick.liquidityGross += liquidityDelta;

        if (upper) {
            tick.liquidityNet -= int128(liquidityDelta);
        } else {
            tick.liquidityNet += int128(liquidityDelta);
        }
    }
 }