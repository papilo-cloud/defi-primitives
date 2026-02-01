// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {InterestRateModel} from "./InterestRateModel.sol";

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

}

contract CompoundLike {
    // Token balances
    mapping(address => mapping(address => uint256)) public supplied;
    mapping(address => mapping(address => uint256)) public borrowed;

    // Pool state
    mapping(address => uint256) public totalSupply;
    mapping(address => uint256) public totalBorrow;
    mapping(address => uint256) public totalReserves;

    // Interest rate state
    mapping(address => uint256) public borrowIndex;
    mapping(address => uint256) public supplyIndex;
    mapping(address => uint256) public lastAccrualBlock;

    mapping(address => mapping(address => uint256)) public cTokenBalance;

    address[] supportedTokens;

    // Events
    event Supply(address indexed user, address token, uint256 amount);
    event Borrow(address indexed user, address token, uint256 amount);
    event Repay(address indexed user, address token, uint256 amount);
    event Withdraw(address indexed user, address token, uint256 amount);

    // Each asset has a collateral factor (LTV)

    constructor() {
        collateralFactor[ETH] = 0.75e18;    // 75% LTV
        collateralFactor[WBTC] = 0.70e18;   // 70% LTV
        collateralFactor[USDC] = 0.80e18;   // 80% LTV
        collateralFactor[SHIB] = 0.40e18;   // 40% LTV (risky asset)
    }

    function supply(address token, uint256 amount) external {
        // Transfer tokens from user
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Accrue interest
        accrueInterest(token);

        // Update supplied amount (in underlying term)
        supplied[msg.sender][token] += amount;
        totalSupply[msg.sender] += amount;

        // MInt cToken (receipt tokens)
        uint256 cTokenAmount = (amount * 1e18) / exchangeRate(token);
        cTokenBalance[msg.sender][token] += cTokenAmount

        emit Supply(msg.sender, token, amount)
    }

    function borrow(address token, uint256 amount) external {
        // Accrue interest
        accrueInterest(token);

        // Check collateral
        require(getAccountLiquidity(msg.sender) >= amount, "Insufficient collateral");

        // Update borrowed amount
        borrowed[msg.sender][token] += amount;
        totalBorrow[token] += amount;

        // Transfer tokens to user
        IERC20(token).transfer(msg.sender, amount);

        emit Borrow(msg.sender, token, amount)
    }

    function repay(address token, uint256 amount) external {
        // Accrue interest
        accrueInterest(token);

        // Transfer from user
        IERC20(token).transferFrom(msg.sender, address(this), amount);

        // Update borrowed amount
        uint256 borrowBalance = borrowed[msg.sender][token];
        uint256 repayAmount = amount > borrowBalance ? borrowBalance : amount;

        borrowed[msg.sender][token] -= repayAmount;
        totalBorrow[token] -= repayAmount;

        emit Repay(msg.sender, token, repayAmount);
    }

    function withdraw(address token, uint256 amount) external {
        // Accrue interest
        accrueInterest(token);

        // Check if withdrawal leaves account healthy
        require(getAccountLiquidity(msg.sender) >= 0, "Insufficient liquidity");

        // Update supplied amount
        supplied[msg.sender][token] -= amount;
        totalSupply[msg.sender] -= amount;

        // Burn cTokens
        uint256 cTokenAmount = (amount * 1e18) / exchangeRate(token);
        cTokenBalance[msg.sender][token] -= cTokenAmount;

        // Transfer tokens to user
        IERC20(token).transfer(msg.sender, amount);

        emit Withdraw(msg.sender, token, amount);
    }

    function accrueInterest(address token) public {
        uint256 currentBlock = block.number;
        uint256 accrualBlock = lastAccrualBlock[token];

        if (accrualBlock == currentBlock) return;

        uint256 cash = IERC20(token).balanceOf(address(this));
        uint256 borrows = totalBorrow[token];
        uint256 reserves = totalReserves[token];

        // Get current borrow rate per block
        uint256 borrowRatePerBlock = InterestRateModel.getBorrowRate(cash, borrows, reserves);

        // Calculate interest accrued
        uint256 blockDelta = currentBlock - accrualBlock;
        uint256 simpleInterest = borrowRatePerBlock * blockDelta;
        uint256 interestAccumulated = (simpleInterest * borrows) / 1e18;

        // Update state
        totalBorrow[token] += interestAccumulated;
        totalReserves[token] += (interestAccumulated * reserveFactor) / 1e18;
        borrowIndex[token] += (borrowIndex[token] * simpleInterest) / 1e18;
        lastAccrualBlock[token] = currentBlock;
    }
    

    // Collateralization & Health Factor
    function getAccountLiquidity(address account) public view returns (uint256 liquidity, uint256 shortfall) {
        uint256 totalCollateral = 0;
        uint256 totalBorrow = 0;

        // Calculate total collateral value (adjusted by collateral factor)
        for (uint i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            uint256 supplied = supplied[account][token];

            if (supplied > 0) {
                uint256 price = oracle.getPrice(token);
                uint256 collateral = (supplied * price) / 1e18;
                uint256 weightedCollateral = (collateralValue * collateralFactor[token]) / 1e18;
                totalCollateral += weightedCollateral;
            }
        }

        // Calculate total borrow value
        for (uint i = 0; i < supportedTokens.length; i++) {
            address token = supportedTokens[i];
            uint256 borrowedAmount = borrowed[account][token];

            if (borrowedAmount > 0) {
                uint256 price = oracle.getPrice(token);
                uint256 borrowValue = (borrowedAmount * price) / 1e18;
                totalBorrow += borrowValue;
            }
        }

        // Calculate liquidity or shortfall
        if (totalCollateral > totalBorrow) {
            liquidity = totalCollateral - totalBorrow;
        } else {
            liquidity = 0;
            shortfall = totalBorrow - totalCollateral
        }
    }

    // Health Factor (Aave)
    function getHealthFactor(address user) public view returns (uint256) {
        (uint256 totalCollateral, uint256 totalDebt, uint256 availableBorrow, uint256 liquidationThreshold) = 
            getUserAccountData(user);

            if (totalDebt == 0) return type(uint256).max;

            return (totalCollateral * liquidationThreshold) / (totalDebt * 1e4);
    }

}