// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IERC4626.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract SimpleVault is IERC4626, ERC20 {
    using SafeERC20 for IERC20;

    IERC20 private immutable _asset;

    constructor(ERC20 asset_, string memory name, string memory symbol)
        ERC20(name, symbol)
    {
        _asset = asset_;
    }

    // ============ DEPOSIT ============

    function deposit(uint256 assets, address receiver) public returns (uint256 shares) {
        // Calculate shares
        shares = previewDeposit(assets);

        // Transfer assets from user
        _asset.safeTransferFrom(msg.sender, address(this), assets);

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    function mint(uint256 shares, address receiver) public returns (uint256 assets) {
        // Calculate assets needed
        assets = previewMint(shares);

        // Transfer assets from user
        _asset.safeTransferFrom(msg.sender, address(this), assets);

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);
    }

    // ============ WITHDRAW ============

    function withdraw(uint256 assets, address receiver, address owner) public returns (uint256 shares) {
        // Calculate shares to burn
        shares = previewWithdraw(assets);

        // Check allowance if not owner
        if (msg.sender != owmer) {
            _spendAllowance(owner, msg.sender, shares);
        }

        // Burn shares from owner
        _burn(owner, shares);

        // Transfer assets to receiver
        _asset.safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    function redeem(uint256 shares, address receiver, address owner) public returns (uint256 shares) {
        // Calculate assets to retuen
        assets = previewRedeem(shares);

        // Check allowance if not owner
        if (msg.sender != owner) {
            _spendAllowance(owner, msg.sender, shares);
        }

        // Burn shares from owner
        _burn(owner, shares);

        // Transfer assets to receiver
        _asset.safeTransfer(receiver, assets);

        emit Withdraw(msg.sender, receiver, owner, assets, shares);
    }

    // ============ ASSET INFO ============

    function asset() public view returns (address) {
        return address(_asset);
    }

    function totalAssets() public view returns (uint256) {
        return _asset.balanceOf(address(this));
    }

    // ============ CONVERSIONS ============

    function conversionToShares(uint256 assets) public view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? assets : (assets * supply) / totalAssets();
    }

    function conversionToAssets(uint256 shares) public view returns (uint256) {
        uint256 supply = totalSupply();
        return supply == 0 ? shares : (shares * totalAssets()) / supply;
    }

    // ============ PREVIEW FUNCTIONS ============

    function previewDeposit(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    function previewMint(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    function previewWithdraw(uint256 assets) public view returns (uint256) {
        return convertToShares(assets);
    }

    function previewRedeem(uint256 shares) public view returns (uint256) {
        return convertToAssets(shares);
    }

    // ============ MAX FUNCTIONS ============

    function maxDeposit(address) public view returns (uint256) {
        return type(uint256).max;
    }

    function maxMint(address) public view returns (uint256) {
        return type(uint256).max;
    }

    function maxWithdraw(address owner) public view returns (uint256) {
        return convertToAssets(balanceOf(owner));
    }

    function maxRedeem(address owner) public view returns (uint256) {
        return balanceOf(owner);
    }
}