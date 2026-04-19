// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MiniAuction {
    struct Auction {
        uint256 collateralAmount;   // ETH being sold
        uint256 debtAmount;         // DAI needed to close
        uint256 startPrice;         // High initial price
        uint256 startTime;          // When auction started
    }

    mapping(uint256 => Auction) public auctions;

    function currentPrice(uint256 auctionId) public view returns (uint256) {
        Auction memory a = auctions[auctionId];
        uint256 elapsed = block.timestamp - a.startTime;

        // Price decays linearly (or exponentially) over time
        // Incentivises liquidators to act quickly
        return a.startPrice - (priceDecayRate * elapsed);
    }

    function bid(uint256 auctionId) external {
        uint256 price = currentPrice(auctionId);
        Auction memory a = auctions[auctionId];
        uint256 daiRequired = a.collateralAmount * price;

        dai.transferFrom(msg.sender, address(this), daiRequired);
        dai.transfer(msg.sender, a.collateralAmount);
    }
}