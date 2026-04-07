// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";

/**
 * @title RWA Vault for Tokenized Real Estate
 * @notice Both deposits and redemptions are async due to:
 * - KYC/AML requirements
 * - Property appraisal cycles
 * - Legal custody transfers
 * - NAV updates (monthly)
 */
contract RealEstateVault is ERC4626 {
    // Request tracking
    struct DepositRequest {
        uint256 assets;
        uint256 timestamp;
        bool kycPassed;
        bool legalApproved;
    }

    struct RedeemRequest {
        uint256 shares;
        uint256 timestamp;
        bool propertyValued;
        bool liquiditySourced;
    }

    mapping(address => DepositRequest) public depositRequests;
    mapping(address => RedeemRequest) public redeemRequests;
    mapping(address => uint256) public claimableShares;
    mapping(address =uint256) public claimableAssets;

    address public kycOracle;
    address public legalCustodian;
    address public valuationOracle;

    uint256 public monthlyNAV; // Updated once per month
    uint256 public lastNAVUpdate;

    // ===== Async Deposit Flow =====

    function requestDeposit(
        uint256 assets,
        address controller
    ) external returns (uint256 requestId) {
        require(assets >= 10_000e6, "Min $10k deposit"); // Minimum for RWA

        // Transfer assets
        IERC20(asset()).transferFrom(msg.sender, address(this), assets);

        // Create request
        depositRequests[controller] = DepositRequest({
            assets: assets,
            timestamp: block.timestamp,
            kycPassed: false,
            legalApproved: false
        });

        // Trigger off-chain KYC
        emit KYCRequired(controller);

        return uint256(uint160(controller)); // Use address as requestId
    }

    /// @notice KYC oracle marks user as passed
    function approveKYC(address user) external {
        require(msg.sender == kycOracle, "Only KYC oracle");
        depositRequests[user].kycPassed = true;

        // Trigger legal review
        emit LegalReviewRequired(user);
    }

    /// @notice Legal custodian approves deposit
    function approveLegal(address user) external {
        require(msg.sender == legalCustodian, "Only custodian");
        require(depositRequests[user].kycPassed, "KYC not passed");

        depositRequests[user].legalApproved = true;

        // Wait for next NAV update to finalize
    }

    /// @notice Admin updates NAV and fulfills deposits (monthly)
    function updateNAVAndFulfillDeposits(
        uint256 newNAV,
        address[] calldata users
    ) external {
        require(msg.sender == valuationOracle, "Only oracle");
        require(block.timestamp >= lastNAVUpdate + 30 days, "Too soon");

        monthlyNAV = newNAV; // e.g., 1.05e6 = $1.05 per share
        lastNAVUpdate = block.timestamp;

        // Fulfill all approved requests at this NAV
        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            DepositRequest memory req = depositRequests[user];

            if (req.kycPassed && req.legalApproved) {
                // Calculate shares at current NAV
                uint256 shares = (req.assets * 1e6) / monthlyNAV;

                // Mark as claimable
                claimableShares[user] += shares;

                // Clear request
                delete depositRequests[user];
            }
        }
    }

    /// @notice User claims their shares
    function deposit(uint256, address receiver) public override returns (uint256 shares) {
        shares = claimableShares[receiver];
        require(shares > 0, "Nothing claimable");

        claimableShares[receiver] = 0;
        _mint(receiver, shares);

        return shares;
    }

    // ===== Async Redeem Flow (similar pattern) =====

    function requestRedeem(uint256 shares, address controller) external {
        // Transfer shares to vault
        _transfer(msg.sender, address(this), shares);

        redeemRequests[controller] = RedeemRequest({
            shares: shares,
            timestamp: block.timestamp,
            propertyValued: false,
            liquiditySourced: false
        });

        // May need to sell underlying property
        emit PropertySaleRequired(controller, shares);
    }

    // ... similar fulfillment pattern ...
}