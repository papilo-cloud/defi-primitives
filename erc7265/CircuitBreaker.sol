// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CircuitBreaker {
    using SafeERC20 for IERC20;

    // Events
    event AssetRegistered(address indexed asset, uint256 threshold);
    event RateLimitTriggered(address indexed asset, uint256 amount);
    event RateLimitReset(address indexed asset);
    event OutflowRecorded(address indexed asset, uint256 amount, uint256 netOutflow);

    // Errors
    error NotAuthorized();
    error RateLimitExceeded(address asset, uint256 amount, uint256 limit);
    error AssetNotRegistered(address asset);

    struct AssetConfig {
        uint256 rateLimitPercentage;    // e.g., 10 = 10%
        uint256 lookbackPeriod;         // e.g., 3600 = 1 hour
        uint256 minTriggerAmount;       // Minimum to check
        bool isRegistered;
    }

    struct FlowTracking {
        uint256 totalInflow;
        uint256 totalOutflow;
        uint256 lastResetTime;
        bool isLimited;
    }

    mapping(address => AssetConfig) public assetConfigs;
    mapping(address => FlowTracking) public flowTracking;
    mapping(address => bool) public isProtectedContract;

    address public admin;
    bool public revertOnLimit;  // Mode: true = revert, false = delay

    modifier onlyAdmin() {
        if (msg.sender != admin) revert NotAuthorized();
        _;
    }

    modifier onlyProtected() {
        if (!isProtectedContract[msg.sender]) revert NotAuthorized();
        _;
    }

    constructor(address _admin, bool _revertOnLimit) {
        admin = _admin;
        revertOnLimit = _revertOnLimit;
    }

    /**
     * @notice Register new asset with circuit breaker
     */
    function registerAsset(
        address asset,
        uint256 rateLimitPercentage,
        uint256 lookbackPeriod,
        uint256 minTriggerAmount,
    ) external onlyAdmin {
        assetConfigs[asset] = AssetConfig({
            rateLimitPercentage: rateLimitPercentage,
            lookbackPeriod: lookbackPeriod,
            minTriggerAmount: minTriggerAmount,
            isRegistered: true
        });

        flowTracking[asset].lastResetTime = block.timestamp;

        emit AssetRegistered(asset, rateLimitPercentage);
    }

    /**
     * @notice Record token inflow to protocol
     */
    function recordInflow(address asset, uint256 amount) external onlyProtected {
        if (!assetConfigs[asset].isRegister) {
            revert AssetNotRegistered(asset);
        }

        _checkAndResetPeriod(asset);
        flowTracking[asset].totalInflow += amount;
    }

    /**
     * @notice Check and record token outflow
     * @dev This is the critical function called before transfers
     */
    function checkAndRecordOutflow(address asset, uint256 amount) external onlyProtected returns (bool allowed) {
        if (!assetConfigs[asset].isRegistered) {
            revert AssetNotRegistered(asset);
        }

        AssetConfig memory config = assetConfigs[asset];

        // Skip check if below minimum trigger amount
        if (amount < config.minTriggerAmount) {
            flowTracking[asset].totalOutflow += amount;
            return true;
        }
        _checkAndResetPeriod(asset);

        FlowTracking storage tracking = flowTracking[asset];
        uint256 newOutflow = tracking.totalOutflow + amount;
        uint256 netOutflow = newOutflow - tracking.totalInflow;

        // Calculate protocol's current balance
        uint256 protocolBalance = IERC20(asset).balanceOf(msg.sender);

        uint256 maxAllowed = (protocolBalance * config.rateLimitPercentage) / 100;

        // Check if rate limit exceeded
        if (netOutflow > maxAllowed) {
            tracking.isLimited = true;
            emit RateLimitTriggered(asset, amount);
            if (revertOnLimit) {
                revert RateLimitExceeded(asset, netOutflow, maxAllowed);
            }
            return true;
        }

        // Update tracking
        tracking.totalOurflow = newOutflow;
        emit OutflowRecorded(asset, amount, netOutflow);

        return true;
    }

    /**
     * @notice Check if lookback period has passed and reset if needed
     */
    function _checkAndResetPeriod(address asset) internal {
        FlowTracking storage config = flowTracking[asset];
        AssetConfig memory config = assetConfigs[asset];

        if (block.timestamp >= tracking.lastResetTime + config.lookbackPeriod) {
            tracking.totalInflow = 0;
            tracking.totalOutflow = 0;
            tracking.isLimited = false;
            tracking.lastResetTime = block.timestamp;

            emit RateLimitReset(asset);
        }
    }

    /**
     * @notice Admin can override rate limit in emergency
     */
    function overrideLimit(address asset) external onlyAdmin {
        flowTracking[asset].isLimited = false;
        flowTracking[asset].totalInflow = 0;
        flowTracking[asset].totalOutflow = 0;
        flowTracking[asset].lastResetTime = block.timestamp;
    }

    /**
     * @notice Add protected contract
     */
    function addProtectedContract(address protectedContract) external onlyAdmin {
        isProtectedContract[protectedContract] = true;
    }

    /**
     * @notice Check current rate limit status
     */
    function getRateLimitStatus(address asset) 
        external 
        view 
        returns (
            uint256 currentOutflow,
            uint256 maxAllowed,
            bool isLimited,
            uint256 timeUntilReset
        )
    {
        FlowTracking memory tracking = flowTracking[asset];
        AssetConfig memory config = assetConfigs[asset];

        currentOutflow = tracking.totalOutflow - tracking.totalInflow;

        // Get protocol balance from first protected contract
        // In production, you'd track this per protected contract
        maxAllowed = 0; // Simplified

        isLimited = tracking.isLimited;

        uint256 timePassed = block.timestamp - tracking.lastResetTime;
        timeUntilReset = timePassed >= config.lookbackPeriod ? 0 : (config.lookbackPeriod - timePassed);

        return (currentOutflow, maxAllowed, isLimited, timeUntilReset);
    }
}