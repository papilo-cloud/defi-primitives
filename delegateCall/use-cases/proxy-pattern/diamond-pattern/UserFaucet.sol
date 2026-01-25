// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Diamond} from "./Diamond.sol";

// Different facets for different functionality
contract UserFacet {
    mapping(address => string) public names;

    function setName(string calldata name) external {
        names[msg.sender] = name;
    }
}

contract TokenFacet {
    mapping(address => uint256) public balances;

    function mint(address to, uint256 amount) external {
        balances[msg.sender] -= amount;
        balances[to] += amount;
    }
}