// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface ICircuitBreaker {
    
    // Events
    event AssetRegistered(
        address indexed asset,
        uint256 metricThreshold,
        uint256 minAmountToLimit
    );

    event AssetParamsUpdated(
        address indexed asset,
        uint256 metricThreshold,
        uint256 minAmountToLimit
    );

    event RateLimitTriggered(
        address indexed asset,
        uint256 amount,
        uint256 timestamp
    );

    // Core Functions

    /**
     * @notice Called before token outflow to check rate limits
     * @param token Address of the token
     * @param amount Amount of tokens being transferred
     * @return Whether the transfer should proceed
     */
    function onTokenOutflow(
        address token,
        uint256 amount
    ) external returns (bool);

    /**
     * @notice Called to record token inflow
     * @param token Address of the token
     * @param amount Amount of tokens received
     */
    function onTokenInflow(
        address token,
        uint256 amount
    ) external;

    /**
     * @notice Check if protocol is currently rate limited
     * @param token Token to check
     * @return Whether rate limit is active
     */
    function isRateLimited(address token) external view returns (bool);

    /**
     * @notice Register a new asset with circuit breaker
     * @param asset Token address
     * @param metricThreshold Maximum allowed outflow
     * @param minAmountToLimit Minimum amount to trigger limit
     */
    function registerAsset(
        address token,
        uint256 metricThreshold,
        uint256 minAmountToLimit
    ) external;

    /**
     * @notice Update parameters for existing asset
     */
    function updateAssetParams(
        address asset,
        uint256 metricThreshold,
        uint256 minAmountToLimit
    ) external;

    /**
     * @notice Emergency override of rate limit
     */
    function overrideRateLimit(address asset) external;
}