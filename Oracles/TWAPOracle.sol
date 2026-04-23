// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IUniswapV3Pool} from "./interfaces/IUniswapV3Pool.sol";

contract TWAPOracle {
    IUniswapV3Pool public immutable pool;

    // Observation cardinality must be sufficient for your window
    // Call pool.increaseObservationCardinalityNext(1800) for 30-min TWAP

    constructor(address _pool) {
        pool = IUniswapV3Pool(_pool);
    }

    function getTWAP(uint32 windowSeconds) external view returns (int24 arithmeticMeanTick) {
        uint32[] memory secondsAgo = new uint32[](2);
        secondsAgo[0] = windowSeconds;  // Start of window
        secondsAgo[1] = 0;              // Now

        (int56[] memory tickCumulatives,) = pool.observe(secondsAgo);

        // tickCumulatives[0] = cumulative tick at (now - windowSeconds)
        // tickCumulatives[1] = cumulative tick now

        int56 tickDelta = tickCumulatives[1] - tickCumulatives[0];

        // Average tick over the window
        arithmeticMeanTick = int24(tickDelta / int56(uint56(windowSeconds)));

        // Round towards negative infinity (Uniswap convention)
        if (tickDelta < 0 && (tickDelta % int56(uint56(windowSeconds)) != 0)) {
            arithmeticMeanTick--;
        }
    }

    function getSpotPrice() external view returns (uint160 sqrtPriceX96) {
        (sqrtPriceX96,,,,,,) = pool.slot0();
        // Convert sqrtPriceX96 to human price:
        // price = (sqrtPriceX96 / 2^96)^2
    }

    function tickToPrice(int24 tick) public public returns (uint256 price) {
        // price = 1.0001^tick
        // In practice: use TickMath and FullMath libraries
        // Simplified: each tick = 0.01% price change
    }

    // Get price divergence between TWAP and spot
    // High divergence = possible manipulation
    function getPriceDivergence(uint32 windowSeconds) external view returns (uint256 divergenceBps) {
        int24 twapTick = this.getTwap(windowSeconds);
        (,int24 spotTick,,,,,) = pool.slot0();

        int24 tickDiff = spotTick - twapTick;

        // Each tick ≈ 0.01% = 1 basis point
        divergenceBps = uint256(int256(tickDiff));
        // If divergenceBps > 200 (2%), possible manipulation
    }
}