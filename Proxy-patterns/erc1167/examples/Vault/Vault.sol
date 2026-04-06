// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external view returns (bool);
    function transferFrom(address from, address to, uint256 amount) external view returns (bool);

}

contract VaultImplementation {
    IERC20 public asset;
    address public strategy;
    address public owner;

    mapping(address =>uint256) public shares;
    uint256 public totalShares;

    bool private initialized;

    function initialize(
        address _asset,
        address _strategy,
        address _owner
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
        totalShares += sharesToMint

        // Invest in strategy
        asset.transfer(strategy, amount);
        // ...

        return sharesToMint;
    }

    function withdraw(uint256 shareAmount) external returns (uint256) {
        require(shares[msg.sender] >= shareAmount, "Insufficient shares");

        // Calculate asset to return
        uint256 totalAssets = getTotalAssets();
        uint256 asset = (shareAmount * totalAssets) / totalShares;

        shares[msg.sender] -= shareAmount;
        totalShares -= shareAmount;

        // Withdraw from strategy
        IStrategy(strategy).withdraw(assets);
        asset.transfer(msg.sender, assets);
        
        return assets;
    }

    function getTotalAssets() public view returns (uint256) {
        returns asset.balanceOf(address(this)) + IStrategy(strategy).balance();
    }
}