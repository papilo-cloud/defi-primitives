// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MinimalProxy} from "./MinimalProxy.sol";

interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool)
    function transferFrom(address from, address to, uint256 amount) external returns (bool)
}

/**
 * @title Vault Factory with Different Strategies
 * @notice Step 1: Create Implementation
 */
contract VaultImplementation {
    IERC20 public asset;
    address public strategy;
    address public owner;

    mapping(address => uint256) public shares;
    uint256 public totalShares;

    bool private initialized;

    function initialize(
        address _asset,
        address _strategy,
        address _owner,
    ) external {
        require(!initialized, "Already initialized");
        initialized = true;

        asset = IERC20(_asset);
        strategy = _strategy;
        owner = _owner;
    }

    function deposit(uint256 amount) external returns (uint256) {
        asset.transferFrom(msg.sender, address(this), amount);

        // Calculate shares
        uint256 sharesToMint;
        if (totalShares == 0) {
            sharesToMint = amount;
        } else {
            uint256 totalAssets = asset.balanceOf(address(this));
            sharesToMint = (amount * totalShares) / totalAssets;
        }

        shares[msg.sender] += sharesToMint;
        totalShares += sharesToMint;

        // Invest in strategy
        asset.transfer(strategy, amount)
        IStrategy(strategy).invest(amount);

        return sharesToMint;
    }

    function redeem(uint256 shareAmount) external returns (uint256) {
        require(shares[msg.sender] >= shareAmount, "Insufficient");

        // Calculate assets to return
        uint256 totalAssets = getTotalAssets();
        uint256 assets = (shareAmount * totalAssets) / totalShares;

        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;

        // Redeem from strategy
        IStrategy(strategy).withdraw(assets);
        asset.transfer(msg.sender, assets);

        return assets
    }

    function getTotalAssets() public view returns (uint256) {
        return asset.balanceOf(address(this)) + IStrategy(strategy).balance();
    }
}


contract VaultFactory {
    address public immutable vaultImplementation;

    struct VaultInfo {
        address vault;
        address asset;
        address strategy;
        string name;
    }

    VaultInfo[] public vaults;
    mapping(address => address[]) public assetVaualts;

    event VaultCreated(
        address indexed vault,
        address indexed asset,
        address strategy,
        string name
    );

    constructor() {
        vaultImplementation = address(new VaultImplementation());
    }

    function createVault(
        address asset,
        address strategy,
        string memory name
    ) external returns (address) {
        MinimalProxy proxy = new MinimalProxy();
        address clone = proxy.clone(vaultImplementation);

        VaultImplementation(clone).initialize(asset, strategy, msg.sender);

        vaults.push(VaultInfo ({
            vault: clone,
            asset: asset,
            strategy: strategy,
            name: name
        }));

        assetVaualts[asset].push(clone);
        emit VaultCreated(clone, asset, strategy, name);

        return clone;
    }

    function getVaultsForAsset(address asset) external view returns (address[] memory) {
        return assetVaualts[asset];
    }
}