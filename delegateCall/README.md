# Delegatecall: Complete Deep Dive

Delegatecall is one of the most powerful and dangerous features in Solidity.

## What is Delegatecall?

### [Basic Comparison](./basic-delegatecall/BasicDelegateCall.sol)

### Context Preservation

```solidity
contract ContextDemo {
    address public caller;
    uint256 public value;

    function logContext() public payable {
        caller = msg.sender;
        value = msg.value;
    }
}

contract DelegateCallDemo {
    address public caller;
    uint256 public value;

    function testCall(address target) public payable {
        // CALL: msg.sender = this contract, msg.value = 0
        target.call{value: 0}(
            abi.encodeWithSignature("logContext()")
        );
    }

    function testDelegateCall(address target) public payable {
        // DELEGATECALL: msg.sender = original sender, msg.value = original value
        target.delegatecall(
            abi.encodeWithSignature("logContext()")
        );
    }
}

// Usage:
// User calls testCall with 1 ETH
// - Target sees: msg.sender = DelegateCallDemo, msg.value = 0

// User calls testDelegateCall with 1 ETH
// - This contract executes with: msg.sender = User, msg.value = 1 ETH
```

## How Delegatecall Works Internally

### EVM Execution

```solidity
/**
 * Low-level delegatecall syntax
 */
contract LowLevelDelegateCall {
    function executeDelegateCall(
        address target,
        bytes memory data
    ) public returns (bool success, bytes memory returnData) {
        assembly {
            // delegatecall(gas, address, inputOffset, inputSize, outputOffset, outputSize)
            success := delegatecall(
                gas(),                    // Forward all gas
                target,                   // Target contract address
                add(data, 0x20),          // Input data location (skip length prefix)
                mload(data),              // Input data size
                0,                        // Output location (0 = not yet known)
                0                         // Output size (0 = not yet known)
            )

            // Copy return data
            let size := returndatasize()
            returnData := mload(0x40)       // Free memory pointer
            mstore(returnData, size)        // Store size
            mstore(0x40, add(returnData, add(size, 0x20)))  // Update free memory pointer
            returndatacopy(add(returnData, 0x20), 0, size)  // Copy data
        }
    }
}
```

### Storage Layout

```solidity
/**
 * Storage slots are accessed by position, not by name
 */
contract Target {
    uint256 public a;  // Slot 0
    uint256 public b;  // Slot 1
    
    function setA(uint256 _a) public {
        a = _a;  // Writes to slot 0
    }
}

contract Caller {
    uint256 public x;  // Slot 0 (same position as Target.a!)
    uint256 public y;  // Slot 1 (same position as Target.b!)
    
    function delegateSetA(address target, uint256 _a) public {
        target.delegatecall(
            abi.encodeWithSignature("setA(uint256)", _a)
        );
        // Target's code writes to slot 0
        // But slot 0 in Caller is 'x', not 'a'
        // Result: Caller.x is modified!
    }
}

// Example execution:
// 1. Call delegateSetA(targetAddr, 42)
// 2. Target's code: "a = 42" → "Write 42 to slot 0"
// 3. Slot 0 in Caller is variable 'x'
// 4. Result: Caller.x = 42
```

## Storage Collision Problems

### The Danger

```solidity
/**
 * DANGEROUS: Storage collision
 */
contract Implementation {
    address public owner;        // Slot 0
    uint256 public value;        // Slot 1
    
    function setValue(uint256 _value) public {
        value = _value;
    }
}

contract BadProxy {
    address public implementation;  // Slot 0 - COLLISION!
    
    fallback() external {
        address impl = implementation;
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

// Attack scenario:
// 1. Implementation.owner is at slot 0
// 2. BadProxy.implementation is also at slot 0
// 3. Call setValue() through proxy
// 4. Implementation code might write to slot 0
// 5. This overwrites the implementation address!
// 6. Attacker can redirect to malicious contract
```

### Solution: Unstructured Storage (EIP-1967)

```solidity
/**
 * SAFE: Unstructured storage using random slots
 */
contract SafeProxy {
    // Use pseudo-random slot that won't collide
    // keccak256("eip1967.proxy.implementation") - 1
    bytes32 private constant IMPLEMENTATION_SLOT = 
        0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc;
    
    bytes32 private constant ADMIN_SLOT = 
        0xb53127684a568b3173ae13b9f8a6016e243e63b6e8ee1178d6a717850b5d6103;
    
    constructor(address _implementation) {
        _setImplementation(_implementation);
    }
    
    function _setImplementation(address newImplementation) private {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }
    
    function _implementation() private view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }
    
    fallback() external payable {
        address impl = _implementation();
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }
}

// Why this works:
// - IMPLEMENTATION_SLOT = keccak256("...") - 1
// - This gives a pseudo-random slot number
// - Extremely unlikely to collide with implementation's storage
// - Implementation uses slots 0, 1, 2, 3...
// - Proxy uses slot 0x360894a13ba1a3210667c828492db98dca3e2076cc3735a920a3ca505d382bbc
```

### Structured Storage (Alternative)

```solidity
/**
 * Keep proxy and implementation storage completely separate
 */
contract ImplementationWithNamespace {
    // All implementation storage in a struct at a specific slot
    struct ImplementationStorage {
        address owner;
        uint256 value;
        mapping(address => uint256) balances;
    }
    
    // Store at deterministic slot
    bytes32 private constant STORAGE_SLOT = keccak256("implementation.storage");
    
    function _getStorage() private pure returns (ImplementationStorage storage s) {
        bytes32 slot = STORAGE_SLOT;
        assembly {
            s.slot := slot
        }
    }
    
    function setValue(uint256 _value) public {
        ImplementationStorage storage s = _getStorage();
        s.value = _value;
    }
    
    function getValue() public view returns (uint256) {
        ImplementationStorage storage s = _getStorage();
        return s.value;
    }
}
```

## Use Cases

### 1. [Upgradeable Contracts (Proxies)](./use-cases/proxy-pattern/UUPSProxy.sol)

### 2. [Library Pattern](./use-cases/proxy-pattern/library-pattern/)

### 3. [Diamond Pattern (Multi-Facet Proxy)](./use-cases/proxy-pattern/diamond-pattern/Diamond.sol)

### [4. Minimal Proxy (EIP-1167)](./use-cases/proxy-pattern/minimal-proxy/)


## Summary

**Delegatecall is powerful but dangerous**:

**Use for**:
- Proxy patterns
- Upgradeable contracts
- Library calls
- Code reuse

**Watch out for**:
- Storage collision
- Reentrancy
- Context confusion
- Selfdestruct
- Function selector clashing

**Security checklist**:
- Match storage layouts
- Use unstructured storage for proxy state
- Validate all inputs
- Protect against reentrancy
- Audit thoroughly
- Test extensively

Delegatecall is the foundation of upgradeable smart contracts and enables powerful patterns, but requires careful implementation to avoid serious vulnerabilities!

### Key Differences

```
CALL:
┌────────┐  call   ┌────────┐
│ Caller │────────>│ Target │
└────────┘         └────────┘
  Storage            Storage
     ↑                  ↑
     │                  │
  Unchanged          Modified
  
DELEGATECALL:
┌────────┐ delegatecall ┌────────┐
│ Caller │─────────────>│Target's│
│        │              │  CODE  │
└────────┘              └────────┘
  Storage                 (code only)
     ↑
     │
  Modified (using Target's code)
```