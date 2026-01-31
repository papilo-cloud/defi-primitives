// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

}

contract CToken {
    // Currentexchange rate
    uint256 public exchangeRateStored;

    function exchangeRate() public returns (uint256) {
        // Rate = (Cash + Borrow - Reserve) / TotalSupply
        uint256 cach = IERC20(token).balanceOf(address(this));
        uint256 borrows = totalBorrows;
        uint256 reserves = totalReserves;
        uint256 supply = totalSupply;

        if (supply == 0) return initialExchangeRate;

        return ((cach + borrows - reserves) * 1e18) / supply;
    }

    function mint(uint mintAmount) external returns (uint256) {
        // Calculate cTokens to mint
        uint256 exchangeRate = exchangeRateCurrent();
        uint256 mintTokens = (mintAmount * 1e18) / exchangeRate;

        // Transfer underlying
        IERC20(token).transferFrom(msg.sender, address(this), minAmount);

        // Mint cTokens
        _mint(msg.sender, mintTokens);

        return mintTokens;
    }

    function redeem(uint256 redeemTokens) external returns (uint256) {
        // Calculate underlying to return
        uint256 exchangeRate = exchangeRateCurrent();
        uint256 redeemAmount = (redeemTokens * exchangeRate) / 1e18;

        // Burn cToken
        _burn(msg.sender, redeemTokens);

        // Transfer underlying
        IERC20(token).transfer(msg.sender, redeemAmount);

        return redeemAmount;
    }
}