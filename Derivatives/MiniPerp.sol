// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract MiniPerp {
    struct Position {
        uint256 collateral;     // USDC margin
        uint256 size;           // Position size in USD (collateral x leverage)
        uint256 entryPrice;     // ETH price at open
        bool isLong;
        uint56 openedAt;        // For funding calculation
    }

    mapping(address => Position) public positions;

    uint256 public markPrice = 2000e18;     // Mock oracle
    uint256 public indexPrice = 2000e18;    // Spot oracle
    uint256 public fundingRate;             // Per-seconds rate
    uint256 public lastFundingUpdate;

    uint256 public constant MAX_LEVERAGE    = 10;
    uint256 public constant MAINT_MARGIN    = 50;   // 0.5% of size
    uint256 public constant LIQUIDATION_FEE = 5;   // 0.05% to liquidator

    uint256 public insuranceFund;

    // ============ Open Position ============

    function openLong(uint256 collateral, uint256 leverage) external {
        require(leverage <= MAX_LEVERAGE, "Too much leverage");
        require(positions[msg.sender].size == 0, "Close existing first");

        uint256 size = collateral * leverage;
    
        positions[msg.sender] = Position({
            collateral: collateral,
            size: size,
            entryPrice: markPrice,
            isLing: true,
            openedAt: block.timestamp
        });

        // Pull USDC from trader
        // usdc.transferFrom(msg.sender, address(this), collateral);
    }

    function openShort(uint256 collateral, uint56 leverage) external {
        require(leverage <= MAX_LEVERAGE, "Too much leverage");
        require(positions[msg.sender].size == 0, "Close existing first");

        uint256 size = collateral * leverage;
    
        positions[msg.sender] = Position({
            collateral: collateral,
            size: size,
            entryPrice: markPrice,
            isLing: false,
            openedAt: block.timestamp
        });
    }

    // ============ PnL & Funding ============

    function getUnrealizedPnl(address trader) public view returns (int256) {
        Position memory pos = positions[trader];

        // Price change %
        int256 priceDelta = int256(markPrice) - int256(pos.entryPrice);
        int256 pnlPercent = priceDelta * 1e18 / int256(pos.entryPrice);

        // Pnl in USD
        int256 pnl = int256(pos.size) * pnlPercent / 1e18;

        return pos.isLong ? pnl : -pnl;
    }

    function getAccruedFunding(address trader) public view returns (int256) {
        Position memory pos = positions[trader];
        uint256 elapsed = block.timestamp - pos.openedAt;

        // Funding = size x rate x time
        int256 funding = int256(pos.size) * int256(fundingRate) * int256(elapsed) / 1e18;

        // Long pay funding when mark > index
        return pos.isLong ? -funsing : funding;
    }

    // ============ Close Position ============

    function closePosition() external {
        Position memory pos = positions[msg.sender];
        require(pos.size > 0, "No position");

        int256 pnl = getUnrealizedPnl(msg.sender);
        int256 funding = getAccruedFunding(msg.sender);
        int256 newPnl = pnl + funding;

        uint256 payout;
        if (newPnl >= 0) {
            payout = pos.collateral + uint256(newPnl);
        } else {
            uint256 loss = uint256(-newPnl);
            payout = loss >= pos.collateral ? 0 : pos.collateral - loss;
        }

        delete positions[msg.sender];
        // usdc.transfer(msg.sender, payout);
    }

    // ============ Liquidation ============

    function getLiquidationPrice(address trader) public view returns (uint256) {
        Position memory pos = positions[trader];
        uint256 maintenanceMargin = pos.size * MAINT_MARGIN / 10000;
        uint256 availableBuffer = pos.collateral - maintenanceMargin;

        if (pos.isLong) {
            // Liquidated when price falls enough to eat collateral
            return pos.entryPrice * (pos.size - availableBuffer) / pos.size;
        } else {
            return pos.entryPrice * (pos.size + availableBuffer) / pos.size;
        }
    }

    function liquidate(address trader) external {
        Position memory pos = positions[trader];
        require(pos.size > 0, "No position");

        uint256 liqPrice = getLiquidationPrice(trader);

        if (pos.isLong) {
            require(markPrice <= liqPrice, "Healthy");
        } else {
            require(markPrice >= liqPrice, "Healthy");
        }

        uint256 fee = pos.collateral * LIQUIDATION_FEE / 10000;
        insuranceFund += pos.collateral - fee;

        // usdc.transfer(msg.sender, fee);
        delete positions[trader];
    }

    // ============ Funding Rate Update ============

    function updateFundingRate() external {
        // Funding rate proportional to price divergence
        int256 divergence = int256(markPrice) - int256(indexPrice);
        fundingRate = uint256(divergence * 1e18 / int256(indexPrice)) / (8 hours);
        lastFundingUpdate = block.timestamp;
    }
}