// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import {BasicERC20} from "../BasicERC20.sol";

contract MintableERC20 is BasicERC20 {
    address public owner;

    modifier onlyOwner() {
        require(owner == msg.sender, "Not owner");
        _;
    }

    constructor() BasicERC20("MIntable", "MINT", 18) {
        owner = msg.sender;
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        _mint(to, amount);
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }
}