// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract AaveLending {
    enum IterestRateMode {NONE, STABLE, VARIABLE}

    mapping(address => mapping(address => IterestRateMode)) public rateMode;
    mapping(address => uint256) public stableRate;

    event Borrow(
        address indexed borrower,
        address indexed asset,
        uint256 amount,
        uint256 currentStableRate,
        IterestRateMode
    );

    function borrow(
        address asset,
        uint256 amount,
        uint256 interestRateMode
    ) external {
        if (interestRateMode == 1) {
            // Stable rate: Locked rate for predictability
            uint256 currentStableRate = calculateStableRate(asset);
            stableRate[asset] = currentStableRate;
            rateMode[msg.sender][asset] = IterestRateMode.STABLE;

            emit Borrow(msg.sender, asset, amount, currentStableRate, InterestRateMode.STABLE);
        } else {
            // Variable rate: Fluctuates with utilization
            rateMode[msg.sender][asset] = IterestRateMode.VARIABLE;
            
            emit Borrow(msg.sender, asset, amount, 0, InterestRateMode.STABLE);
        }

        _executeBorrow(msg.sender, asset, amount);
    }
}