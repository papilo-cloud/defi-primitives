// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Simple Token Cloning
 * @notice Step 1: Create Implementation
 */
contract TokenImplementation {
    // Storage layout MUST be consistent
    string public name;
    string public symbol;
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    address public owner;

    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 _initSupply
    ) external {
        require(bytes(name).length == 0, "Already initialized");

        name = _name;
        sumbol = _sumbol;
        initialSupply = _initSupply;
        owner = msg.sender;
        balanceOf[msg.sender] = _initSupply;
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        
        balanceOf[msg.sender] -= amount;
        balanceOf[to] += amount;
        
        return true;
    }
}


/**
 * @notice Step 2: Create Factory
 */
contract TokenFactory {
    address public implementation;
    address[] public allTokens;

    event TokenCreated(address indexed token, string name, string symbol);

    constructor(address _implementation) {
        implementation = _implementation;
    }

    function createToken(
        string memory name,
        string memory symbol,
        uint256 initialSupply
    ) external returns (address) {
        MinimalProxy proxy = new MinimalProxy();
        address token = proxy.clone(implementation);

        // Initialize the clone
        (bool success, ) = token.call(abi.encodeWithSignature("initialize(string,string,uint256)", name, symbol, initialSupply));
        require(success);

        allTokens.push(token);
        emit TokenCreated(token, name, symbol);
        return token;
    }

    function getTokenCount() external view returns (uint256) {
        return allTokens.length;
    }
}