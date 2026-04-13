// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ICircuitBreaker} from "./ICircuitBreaker.sol"; 

contract CircuitBreaker is {
    struct AssetParams {
        uint256 metricThreshold;        // Max outflow allowed
        uint256 minAmountToLimit;       // Minimum to trigger check
        uint256 lookbackPeriod;         // Time window in seconds
        uint256 cooldownPeriod;         // Pause duration
        bool isRegistered;
    }

    struct RateLimitState {
        uint256 totalInflow;            // Cumulative inflows
        uint256 totalOutflow;           // Cumulative outflows
        uint256 netOutflow;             // Outflow - Inflow
        uint256 lastUpdate;             // Last timestamp
        bool isLimited;                 // Currently rate limited
    }

    // Storage mappings
    mapping(address => AssetParams) public assetParams;
    mapping(address => RateLimitState) public rateLimitStates;
    mapping(address => bool) public protectedContracts;

    address public admin;
    uint256 public gracePeriod;
}