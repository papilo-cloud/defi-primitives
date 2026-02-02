// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract EMode {
    struct EModeCategory {
        uint16 ltv;                     // Loan to Value
        uint16 liquidationThreshold;
        uint16 liquidationBonus;
        address priceSource;
    }

    mapping(uint8 => EModeCategory) public eModeCategories;
    mapping(address => uint8) public userMode;

    // E-Mode Category 1: Stablecoins
    // ETH category: 97% LTV, 98% liquidation threshold
    eModeCategories[1] = EModeCategory({
        ltv: 9700,                     // 97%
        liquidationThreshold: 9800,    // 98%
        liquidationBonus: 102,         // 2%
        priceSource: address(0)
    })

    function setUserEMode(uint8 categoryId) external {
        require(categoryId <= MAX_EMODE_CATEGORIES, "Invalid category");
        userEMode[msg.sender] = categoryId;
    }
}

// Example: Stablecoin E-Mode
// Deposit 100,000 USDC
// Normal mode: Borrow up to 80,000 DAI (80% LTV)
// E-Mode: Borrow up to 97,000 DAI (97% LTV)
// Much more capital efficient!

// ETH E-Mode:
// Deposit 10 ETH
// Borrow up to 9 stETH (90% LTV)
// Perfect for leverage staking