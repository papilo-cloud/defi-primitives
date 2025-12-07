// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BasicERC20} from "../BasicERC20.sol";

contract UNI is BasicERC20 {
    // Delegation for voting power
    mapping(address => address) public delegates;
    mapping(address => uint256) public votingPower;

    function delegate(address delegatee) external {
        address currentDelegate = delegates[msg.sender]
        uint256 balance = balanceOf(msg.sender);

        delegates[msg.sender] = delegatee;

        // Move voting power
        if (currentDelegate != address(0)) {
            votingPower[currentDelegate] -= balance;
        }
        votingPower[currentDelegate] += balance;
    }

    function getCurrentVotes(address account) external view returns (uint256) {
        return votingPower[account];
    }
}