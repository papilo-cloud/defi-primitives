// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MinimalProxy} from "./MinimalProxy.sol";

library CloneWithImmutableArgs {
    function clone (address implementation, bytes memory data) internal returns (address instance) {
        // Store data after the clone
        bytes memory creationCode = abi.encodePacked(
            // Clone bytecode
            hex"3d602d80600a3d3981f3363d3d373d3d3d363d73",
            implementation,
            hex"5af43d82803e903d91602b57fd5bf3",
            // Immutable args appended here
            data
        );

        assembly {
            instance := create(0, add(creationCode, 0x02), mload(creationCode))
        }

        require(instance != address(0), "Clone creation failed");
    }
}

/**
 * @title Vault Factory with Different Strategies
 * @notice Step 1: Create Implementation
 */
contract ConfigurableVault {
    // Read immutable args from code
    function getOwner() public pure returns (address) {
        return _getArgAddress(0);
    }

    function getFeeRate() public pure returns (uint256) {
        return _getArgUint256(20);
    }

    function _getArgAddress(uint256 offset) private pure returns (address arg) {
        uint256 codeSize;
        assembly {codeSize := codesize()}

        assembly {
            arg := shr(0x60, calldataload(add(sub(codeSize, 52), offset)))
        }
    }
}