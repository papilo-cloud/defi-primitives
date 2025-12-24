// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC4626 {
    // =============== ASSET INFO ==============
    function asset() external view returns (address);
    // Returns address oof underlying token (DAI, USDC, etc.)

    function totalAssets() external view returns (uint256);

    // ============ SHARE CONVERSIONS ============
    function convertToShares(uint256 assets) external view returns (uint256);
    // How many shares for X assets

    function convertToAssets(uint256 shares) external view returns(uint256);
    // How many assets for X shares

    // ============ DEPOSIT LIMITS ============
    function maxDeposit(address receiver) external view returns (uint256);
    // Max asset that can be deposited

    function maxMint(address receiver) external view returns (uint256);
    // Max shares that can be minted

    // ============ PREVIEW FUNCTIONS ============
    function previewDeposit(uint256 assets) external view returns (uint256);
    // How many shares will I get for X assets?

    function previewMint(uint256 shares) external view returns (uint256);
    // How many assets needed for X shares?
    
    // ============ DEPOSIT FUNCTIONS ============
    function deposit(uint256 assets, address receiver) external returns (uint256 shares);
    // Deposit assets, receive shares

    function mint(uint256 shares, address receiver) external returns (uint256 assets);
    // Mint shares, pay assets

    // ============ WITHDRAW LIMITS ============
    function maxWithdraw(address owner) external view returns (uint256);
    // Max assets that can be withdrawn

    function maxRedeem(address owner) external view returns (uint256);
    // Max shares that can be redeemed

    // ============ PREVIEW FUNCTIONS ============
    function previewWithdraw(uint256 assets) external view returns (uint256);
    // How many shares to burn for X assets?

    function previewRedeem(uint256 shares) external view returns (uint256);
    // How many assets for X shares?

    // ============ WITHDRAW FUNCTIONS ============
    function withdrwa(uint256 assets, address receiver, address owner) external returns (uint256 shares);
    // Withdraw assets, burn shares

    function redeem(uint256 shares, address receiver, address owner) external returns (uint256 assets);
    // Redeem shares, receive assets
}