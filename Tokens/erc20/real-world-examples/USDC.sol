// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BasicERC20} from "../BasicERC20.sol";

contract USDC is BasicERC20 {
    address public masterMinter;
    mapping(address => bool) public minters;
    mapping(address => uint256) public minterAllowance;
    mapping(address => bool) public blacklisted;

    modifier onlyMinters() {
        require(minters[msg.sender], "Not a minter");
        _;
    }

    modifier notBlacklisted(address account) {
        require(!blacklisted[account], "Blacklisted");
        _;
    }

    function mint(address to, uint256 amount) external onlyMinters {
        require(minterAllowance[msg.sender] >= amount, "Exceeds allowance");
        minterAllowance[msg.sender] -= amount;
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    function blacklist(address account) external {
        // Only admin can call
        blacklisted[account] = true;
    }

    function transfer(
        address to,
        uint256 amount
    )
        external
        override
        notBlacklisted(msg.sender)
        notBlacklisted(to)
        returns (bool)
    {
        _transfer(msg.sender, to, amount);
        return true;
    }
}
