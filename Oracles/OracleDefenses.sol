// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";
import {IUniswapV3Pool} from "./interfaces/IUniswapV3Pool.sol";
import {MultiWindowTWAP} from "./MultiWindowTWAP.sol";

contract OracleDefenses {
    AggregatorV3Interface public chainlink;
    MultiWindowTWAP public twap;
    IUniswapV3Pool public pool;

    // Circuit breaker state
    bool public circuitBreakerTripped;
    uint256 public circuitBreakerTrippedAt;
    uint256 public constant CIRCUIT_BREAKER_DURATION = 1 hours;
    uint256 public constant MAX_CHAINLINK_TWAP_DIVERGENCE = 500; // 5%
    uint256 public constant MAX_PRICE_CHANGE_PER_BLOCK_BPS = 300; // 3%

    int256 private lastBlockPrice;
    uint256 private lastBlockNumber;

    event CircuitBreakerTripped(string reason, uint256 timestamp);

    // ─── Primary price function with all defenses ─────────────────────────

    function getSecurePrice() external returns (uint256) {
        // Defense 1: Circuit breaker
        if (circuitBreakerTripped) {
            require(
                block.timestamp > circuitBreakerTrippedAt + CIRCUIT_BREAKER_DURATION,
                "Circuit breaker active"
            );
            circuitBreakerTripped = false;  // Auto-reset after duration
        }

        // Defense 2: Staleness check on Chainlink
        (uint80 roundId, int256 price,, uint256 updatedAt, uint80 answerdInRound) = chainlink.latestRoundData();

        require(price > 0, "Invalid price");
        require(answerdInRound >= roundId, "Stale round");
        require(block.timestamp - updatedAt < 3600, "Stale: >1hr" );

        // Defense 3: Cross-validate with TWAP
        int24 twapTick = twap.getTWAPTick(1800); // 30-min TWAP
        // Convert to price for comparison...
        uint256 twapPrice = _tickToPrice(twapTick);
        uint256 clPrice = uint256(price) / 1e18;    // Chainlink has 8 decimals

        uint256 divergence = _absDivergenceBps(clPrice, twapPrice);

        if (divergence > MAX_CHAINLINK_TWAP_DIVERGENCE) {
            _tripCircuitBreaker("Chainlink/TWAP divergence");
            revert("Price feeds diverged -- possible manipulation");
        }

        // Defense 4: Per-block price change limit
        if (lastBlockNumber == block.number - 1) {
            uint256 blockChange = _absDivergenceBps(
                uint256(price),
                uint256(lastBlockPrice)
            );
            if (blockChange > MAX_PRICE_CHANGE_PER_BLOCK_BPS) {
                _tripCircuitBreaker("Excessive per-block change");
                revert("Price changed too fast");
            }
        }

        lastBlockPrice = price;
        lastBlockNumber = block.number

        // Return the more conservative (lower) of the two prices
        // For collateral valuation: use lower price (safer for protocol)
        return clPrice < twapPrice ? clPrice : twapPrice;
    }

    function _tripCircuitBreaker(string memory reason) internal {
        circuitBreakerTripped = true;
        circuitBreakerTrippedAt = block.timestamp;
        emit CircuitBreakerTripped(reason, block.timestamp);
    }

    function _absDivergenceBps(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a > b) return (a - b) * 10000 / b;
        return (b - a) * 10000 / a;
    }

    // Emergency: governance can manually trip circuit breaker
    function emergencePause(string memory reason) external onlyGovernance {
        _tripCircuitBreaker(reason);
    }
}