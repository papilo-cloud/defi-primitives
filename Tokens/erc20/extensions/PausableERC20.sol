// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BasicERC20} from "../BasicERC20.sol";

contract PausableERC20 is BasicERC20 {
    bool public paused;
    address public owner;

    modifier whenNotPaused() {
        require(!paused, "Token is paued");
        _;
    }

    function pause() external {
        require(msg.sender == owner);
        paused = true;
    }

    function unpause() external {
        require(msg.sender == owner);
        paused = false;
    }

    function transfer(address to, uint256 amount) external override whenNotPaused returns (bool) {
        _transfer(msg.sender, to, amount);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) external override whenNotPaused returns (bool) {
        // ... implementation
    }
}