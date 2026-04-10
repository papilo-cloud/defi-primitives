// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {CircuitBreaker} from "./CircuitBreaker.sol";

abstract contract ProtectedContract {
    using SafeERC20 for IERC20;

    CircuitBreaker public immutable circuitBreaker;

    error TransferBlocked();

    constructor(address _circuitBreaker) {
        circuitBreaker = CircuitBreaker(_circuitBreaker);
    }

    /**
     * @notice Safe transfer with inflow recording
     */
    function cbInflowSafeTransferFrom(
        address token,
        address from,
        address to,
        uint256 amount
    ) internal {
        IERC20(token).safeTransferFrom(from, to, amount);
        circuitBreaker.recordInflow(token, amount);
    }

    /**
     * @notice Safe transfer with outflow checking
     */
    function cbOutflowSafeTransfer(
        address token,
        uint256 amount,
        address to,
        bool ignoreLimit
    ) internal {
        if (!ignoreLimit) {
            bool allowed = circuitBreaker.checkAndRecordOutflow(token, amount);
            if (!allowed) revert TransferBlocked();
        }

        IERC20(token).safeTransfer(to, amount);
    }
}