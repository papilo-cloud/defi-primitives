// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IERC20 {
    // Returns total token supply
    function totalSupply() external view returns (uint256);

    // Retunrs the balance of an account
    function balanceOf(address account) external view returns (uint256);

    // Transfer tokens from caller to recepient(to)
    function transfer(address to, uint256 amount) external returns (bool);

    // Retunrs the remaining allowance for spender
    function allowance(address owner, address spender) external view returns (uint256);

    // Approves spender to spend token on behalf of caller
    function approve(address spender, uint256 amount) external returns (bool);

    // Transfer token from one address to another (requires allowance)
    function transferFrom(address from, address to, uint256 amount) external returns (bool);

    //Events
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
}