// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract InterestRateModel {
    uint256 public constant BASE_RATE = 0.02e18;         // 2% APY
    uint256 public constant MULTIPLIER = 0.10e18;        // Slope below kink
    uint256 public constant JUMP_MULTIPLIER = 1.09e18;   // Slope above kink
    uint256 public constant KINK = 0.80e18;              // 80% utilization

    function getBorrowRate(uint256 cash, uint256 borrows, uint256 reserves) public pure returns (uint256) {
        uint256 util = getUtilization(cash, borrows, reserves);

        if (util <= KINK) {
            // Below kink: Linear increase
            // Rate = BaseRate + Utilization * Multiplier
            return BASE_RATE + (util * MULTIPLIER) / 1e18;
        } else {
            // Above kink: Jump increase
            // Rate = BaseRate + Kink * Multiplier + (Util - Kink) * JumpMultiplier
            uint256 normalRate = BASE_RATE + (KINK * MULTIPLIER) / 1e18;
            uint256 excessUtil = util - KINK;
            return normalRate + (excessUtil * JUMP_MULTIPLIER) / 1e18;
        }
    }

    function getSupplyRate(
        uint256 cash,
        uint256 borrows,
        uint256 reserves,
        uint256 reserveFactor
    ) 
        public pure returns (uint256)
    {
        uint256 util getUtilization(cash, borrows, reserves);
        uint256 borrowRate = getBorrowRate(cash, borrows, reserves);

        // Supply Rate = Borrow Rate * Utilization * (1 - Reserve Factor)
        uint256 rateToPool = (borrowRate * (1e18 - reserveFactor)) / 1e18;
    }

    function getUtilization(uint256 cash, uint256 borrows, uint256 reserves) public pure returns (uint256) {
        if (borrow == 0) return 0;
        return (borrows * 1e18) / (cash + borrows - reserves);
    }
}