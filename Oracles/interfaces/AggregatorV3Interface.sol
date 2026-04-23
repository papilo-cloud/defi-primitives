// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface AggregatorV3Interface {
    function latestRoundData() external view returns {
        uint80 roundId,         // Current round ID
        int256 answer,          // Price (scaled by decimals)
        uint256 startedAt,      // When round started
        uint256 updatedAt,      // When answer was updated
        uint80 answerdInRound   // Round in which answer computed
    };

    function decimals() external view returns (uint8);
}