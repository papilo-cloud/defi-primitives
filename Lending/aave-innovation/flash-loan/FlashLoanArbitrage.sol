// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {FlashLoan, IFlashLoanReceiver} from "./FlashLoan.sol";

contract FlashLoanArbitrage is IFlashLoanReceiver {
    FlashLoan public aave;
    function executeArbitrage() external {
        // 1. Flash loan 1000 ETH
        aave.flashLoan(address(this), address(WETH), 1000 ether, "");
    }

    function executeOperation(
        address asset, 
        uint256 amount, 
        uint256 premium,
        bytes calldata params
    ) external returns (bool) {
        // 2. Buy ETH on Uniswap at $2000
        uint256 usdcSpent = uniswap.swap(1000 ether);
        // Spent: ~2,000,000 USDC

        // 3. Sell ETH on Sushiswap at $2010
        uint256 usdcReceived = sushiswap.swap(1000 ether);
        // Received: ~2,010,000 USDC

        // 4. Profit: 10,000 USDC
        // 5. Repay flash loan: 1000 ETH + fee
        uint256 repayAmount = amount + premium;
        IERC20(asset).approve(msg.sender, repayAmount);

        // 6. Keep profit: ~9,100 USDC (after fees)
        return true;
    }
}