// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract IsolationMode {
    mapping(address => bool) public isIsolated;
    mapping(address => uint256) public debtCeiling; // Max debt in USD

    function supply(address asset, uint256 amount) external {
        if (isIsolated[asset]) {
            // Can only borrow stablecoins in isolation mode
            // Cannot use other collateral
            // Limited by debt ceiling

            require(getUserTotalDebt(msg.sender) + newBorrow <= debtCeiling[asset], "Debt ceiling exceeded");
        }
    }

    _supply(msg.sender, asset, amount);
}

// Example: New volatile token XYZ
// - Listed in isolation mode
// - Debt ceiling: $1M
// - Users can deposit XYZ
// - But can only borrow USDC/DAI (not ETH or other tokens)
// - Max total borrowing: $1M
// - Protects protocol if XYZ crashes