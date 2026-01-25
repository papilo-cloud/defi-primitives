// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

// BASIC COMPARISON BETWEEN NORMAL CALL AND DELEGATECALL
contract Target {
    uint256 public value;
    address public sender;

    function setValue(uint256 _value) external {
        value = _value;
        sender = msg.sender;
    }
}


contract Caller {
    uint256 public value;
    address public sender;
    Target public target;

    constructor(address _target) {
        target = Target(_target);
    }

    function nornamCall(uint256 _value) external {
        target.setValue(_value);
        // Result:
        // - Target's storage is modified
        // - Target's value changes
        // - Target's sender = Caller's address
        // - Caller's storage unchanged
    }

    // DELEGATECALL
    function delegateCall(uint256 _value) external {
        (bool success, ) = address(target).delegatecall(
            abi.encodeWithSignature("setValue(uint256)", _value)
        );
        require(success);
        // Result:
        // - Caller's storage is modified
        // - Caller's value changes
        // - Caller's sender = msg.sender (EOA) who called Caller
        // - Target's storage unchanged
    }
}


// CONTEXT PRESERVATION WITH DELEGATECALL
contract ContextDemo {
    uint256 public value;
    address public sender;

    function logContext(uint256 _value) external payable {
        value = _value;
        sender = msg.sender;
    }
}

contract DelegateCallDemo {
    uint256 public value;
    address public sender;

    constructor(address target) {
        target.call{value: 0}(
            abi.encodeWithSignature("logContext(uint256)")
        );
    }

    function testDelegateCall(uint256 target) external payable {
        target.delegatecall(
            abi.encodeWithSignature("logContext(uint256)")
        );
    }
}
// Usage:
// User calls testCall with 1 ETH
// - Target sees: msg.sender = DelegateCallDemo, msg.value = 0

// User calls testDelegateCall with 1 ETH
// - This contract executes with: msg.sender = User, msg.value = 1 ETH