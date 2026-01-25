// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 *@notice Using delegatecall for library functionality
 */
library MathLib {
    function add(uint256 a, uint256 b) public pure returns (uint256) {
        return a + b;
    }

    function multiply(uint256 a, uint256 b) public pure returns (uint256) {
        return a * b;
    }
}
