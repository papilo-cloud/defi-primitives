// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MintableERC20} from "./MintableERC20.sol";

contract CappedERC20 is MintableERC20 {
    uint256 public immutable cap;

    constructor(uint256 _cap) {
        cap = _cap;
    }

    function mint(address to, uint256 amount) external override onlyOwner {
        require(totalSupply() + amount <= cap, "Cap exceeded");
        _mint(to, amount);
    }
}