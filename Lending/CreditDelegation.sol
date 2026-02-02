// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title CreditDelegation
 *@dev Lend your borrowing power to someone else: they can borrow against your collateral.  
 */
contract CreditDelegation {
    mapping(address => mapping(address => uint256)) public borrowAllowance;

    function approveDelegation(address delegatee, uint256 amount) external {
        borrowAllowance[msg.sender][delegatee] = amount;
    }

    function borrowWithDelegation(
        address delegator,
        address asset,
        uint256 amount
    ) external {
        require(
            borrowAllowance[delegator][msg.sender] >= amount, "Insufficient delegation"
        );

        // Borrow against delegator's collateral
        // But delegatee receives the funds
        borrowAllowance[delegator][msg.sender] -= amount;
        _borrow(delegator, msg.sender, asset, amount);
    }
}

// Use case: Institution delegates to trader
// - Institution has collateral but doesn't trade
// - Trader has skill but lacks capital
// - Win-win!