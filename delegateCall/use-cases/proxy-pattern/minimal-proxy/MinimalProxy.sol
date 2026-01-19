// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title Minimal Proxy (EIP-1167)
 * @notice Clone pattern: Create cheap copies of a contract
 */
contract MinimalProxy {
    // Minimal proxy bytecode
    // Clones are ~45 bytes vs thousands for full contract
    
    function clone(address implementation) public returns(address instance) {
        bytes20 targetBytes = bytes20(implementation);
        assembly {
            let clone := mload(0x40)
            mstore(
                clone,
                0x3d602d80600a3d3981f3363d3d373d3d3d363d73000000000000000000000000
            )
            mstore(add(clone, 0x14), targetBytes)
            mstore(add(clone, 0x28), 
                0x5af43d82803e903d91602b57fd5bf30000000000000000000000000000000000
            )
            instance := create(0, clone, 0x37)
        }
    }
}
