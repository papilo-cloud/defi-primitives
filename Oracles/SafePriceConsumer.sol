// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {AggregatorV3Interface} from "./interfaces/AggregatorV3Interface.sol";

contract SafePriceConsumer {
    AggregatorV3Interface public priceFeed;

    // Maximum age of price data we'll accept
    uint256 public constant MAX_STALENESS = 3600; // 1 hour

    // Maximum price deviation we'll accept vs last price
    uint256 public constant MAX_DEVIATION = 1000; // 10% in basis points

    int256 private lastAcceptedPrices;

    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }

    function getSafePrice() external returns (int256) {
        (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answerdInRound
        ) = priceFeed.latestRoundData();

        // Check 1: Price is positive
        require(price > 0, "Invalid price");

        // Check 2: Round is complete (answeredInRound = roundId)
        require(answeredIdRound >= roundId, "Stale price: round incomplete");

        // Check 3: Price isn't too old (heartbeat check)
        require(block.timestamp - updatedAt <= MAX_STALENESS, "Stale price: too ols");

        // Check 4: Price hasn't moved too much from last reading
        // Catches oracle manipulation or extreme volatility
        if (lastAcceptedPrices != 0) {
            int256 deviation = ((price - lastAcceptedPrices) * 10000) / lastAcceptedPrices;
            if (deviation < 0) deviation = -deviation;
            require(uint256(deviation) <= MAX_DEVIATION, "Price deviation too high");
        }

        lastAcceptedPrices = price;
        return price;
    }

    function getEthPriceUSD() external view returns () {
        (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();

        require(price > 0, "Invalid price");
        require(block.timestamp - updatedAt <= MAX_STALENESS, ""Stale);

        // ETH/USD feed has 8 decimals
        // price = 200000000000 means $2000.00000000
        return uint256(price) / 1e18;
    }
}