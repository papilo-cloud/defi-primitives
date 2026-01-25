// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MathLib} from "./MathLib.sol";

contract Calculator {
    address public mathLib;
    uint256 public result;

    constructor (address _mathLib) {
        mathLib = _mathLib;
    }

    function add(uint256 a, uint256 b) public {
        (bool success, bytes memory data) = mathLib.delegatecall(
            abi.encodeWithSignature("add(uint256,uint256)", a, b)
        );
        require(success);

        result = abi.decode(data, (uint256));
    }
}