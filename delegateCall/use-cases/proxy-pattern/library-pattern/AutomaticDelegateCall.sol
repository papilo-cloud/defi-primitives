// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MathLib} from "./MathLib.sol";

// Solidity's 'using for' syntax uses delegatecall internally
contract AutomaticDelegateCall {
    using MathLib for uint256;

    function add() public pure returns (uint256) {
        uint256 a = 5;
        uint256 b = 10;
        return a.add(b); // Calls MathLib.add via delegatecall
    }
}