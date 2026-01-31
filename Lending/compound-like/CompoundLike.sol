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

    // Events
    event Supply(address indexed user, address token, uint256 amount);
    event Borrow(address indexed user, address token, uint256 amount);
    event Repay(address indexed user, address token, uint256 amount);
    event Withdraw(address indexed user, address token, uint256 amount);


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
}