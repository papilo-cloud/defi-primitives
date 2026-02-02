// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

}

interface IFlashLoanReceiver {
    function executeOperation(
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata params
    ) external returns (bool);
}

contract FlashLoan {
    function flashLoan(
        address receiver,
        address token,
        uint256 amount,
        bytes calldata params
    ) external {
        // 1. Send tokens to receiver
        uint256 balanceBefore = IERC20(token).balanceOf(address(this));

        // 2. Call receiver's callback function
        IFlashLoanReceiver(receiver).executeOperation(token, amount, fee, params);

        // 3. Check tokens were returned + fee
        uint256 balanceAfter = IERC20(token).balanceOf(address(this));
        require(balanceAfter >= balanceBefore + fee, "Flash loan not repaid");
    }
}

// Flash loan fee: 0.09% (Aave)