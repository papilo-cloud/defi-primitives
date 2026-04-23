// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IUniswapV3Pool} from "./interfaces/IUniswapV3Pool.sol";
import {TickMath} from "./libraries/TickMath.sol";
import {FullMath} from "./libraries/FullMath.sol";

contract MultiWindowTWAP {
    IUniswapV3Pool public immutable pool;

    // Supported TWAP windows
    uint32 public constant WINDOW_5MIN  = 300;
    uint32 public constant WINDOW_30MIN = 1800;
    uint32 public constant WINDOW_1HR   = 3600;

    constructor(address _pool) {
        pool = IUniswapV3Pool(_pool);

        // CRITICAL: increase observation cardinality
        // Default = 1 (only current observation)
        // For 1-hour TWAP at 12s/block: need 300 observations
        // Call once during deployment:
        pool.increaseObservationCardinalityNext(500);
    }

    function getTWAPTick(uint32 windowSeconds) public view returns (in24) {
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = windowSeconds;
        secondsAgo[1] = 0;

        try pool.observe(secondsAgo) returns (
            int56[] memory tickCumulatives,
            uint160[] memory
        ) {
            int56 tickDelta = tickCumulatives[1] - tickCumulatives[0];
            int24 meanTick = int24(tickDelta / int56(uint56(windowSeconds)) != 0) {
                meanTick--;
            }
            return meanTick;
        } catch {
            // Pool doesn't have enough history yet
            // Fall back to current tick
            (, int24 currentTick,,,,,) = pool.slot0();
            return currentTick            
        }
    }

    function getTokenPrice(
        address tokenIn,
        address tokenOut,
        uint32 windowSeconds,
        uint128 amountIn
    ) external view returns (uint256 amountOut) {
        int24 tick = getTWAPTick(windowSeconds);

        / Convert tick to sqrtPriceX96
        // Then use to calculate amountOut from amountIn
        // (requires TickMath and FullMath from Uniswap V3 libraries)

        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(tick);

        // token0 → token1 or token1 → token0 depending on pool ordering
        if (tokenIn == pool.token0()) {
            amountOut = Fullmath.muldiv(
                uint256(amountIn) << 192,
                1,
                uint256(sqrtRatioX96) ** 2
            );
        } else {
            amountOut = Fullmath.mulDiv(
                uint256(sqrtRatioX96) ** 2,
                amountIn,
                1 << 192
            );
        }
    }

    // Check if spot is suspiciously far from TWAP
    function isManipulated(
        uint32 windowSeconds,
        uint256 maxDeviationBps   // e.e. 500 = 5%
    ) external view returns (bool) {
        int24 twapTick = getTWAPTick(windowSeconds);
        (, int24 spotTick,,,,,) = pool.slot0();

        int24 deviation = spotTick - twapTick;
        if (deviation < 0) deviation = -deviation;

        // Each tick ~ 1 basis point
        return uint256(int256(deviation)) > maxDeviationBps;
    }
}