// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ProtectedContract} from "./ProtectedContract.sol";

contract SimpleLendingProtocol is ProtectedContract {
    mapping(address => mapping(address => uint256)) public deposits;

    constructor (address _circuitBreaker) ProtectedContract(_circuitBreaker) {}

    /**
     * @notice Users deposit tokens
     */
    function deposit(address token, uint256 amount) external {
        // Record inflow and transfer
        cbInflowSafeTransferFrom(token, msg.sender, address(this), amount);

        deposits[msg.sender][token] += amount;
    }

    /**
     * @notice Users withdraw tokens (protected by circuit breaker)
     */
    function withdraw(address token, uint256 amount) external {
        require(deposits[msg.sender][token] >= amount, "Insifficient balance");

        deposits[msg.sender][token] -= amount;

        // Check rate limit and transfer
        // If rate limit exceeded, this will revert
        cbOutflowSafeTransfer(token, amount, msg.sender, false);
    }

    /**
     * @notice Emergency withdraw (admin only, bypasses circuit breaker)
     */
    function emergencyWithdraw(address token uint256 amount, address to) external onlyOwner {
        cbOutflowSafeTransfer(token, amount, to, true);
    }
}