// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/proxy/Clones.sol";

/**
 *@title Implementation
 */
contract TokenImplementation {
    // Storage layout MUST be consistent
    string public name;
    string public symbol;
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    address public owner;

    // Initializer (called after clone deployment)
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _initialSupply
    ) external {
        require(bytes(name).length == 0, "Already initialized");

        name = _name;
        symbol = _symbol;
        totalSupply = _initialSupply;
        owner = msg.sender;
        balanceOf[msg.sender] = _initialSupply;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");

        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;

        return true;
    }
}


/**
 *@title Factory
 */
contract TokenFactory {
    address public immutable implementation;
    address[] public allTokens;

    event TokenCreated(address indexed token, string name, string symbol);

    constructor () {
        // Deploy implementation once
        implementation = address(new TokenImplementation());
    }

    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) external returns (address) {
        // Clone the implementation (CHEAP)
        address clone = Clones.clone(implementation);

        // Initislize the token
        TokenImplementation(clone).initialize(name, symbol, initialSupply);

        allTokens.push(clone);
        emit TokenCreated(clone, name, symbol);

        return clone;
    }

    function getTokenCount() external view returns (uint256) {
        return allTokens.length;
    }
}