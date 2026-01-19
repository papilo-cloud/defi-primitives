// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title UUPS Proxy (Universal Upgradeable Proxy Standard)
 * @notice Upgrade logic lives in implementation, not proxy
 */
contract UUPSProxy {
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(
        uint256(keccak256('eip1967.proxy.implementation')) - 1
    );

    error InvalidImplementation()
    error ImplementationNotContract()

    constructor(address _implementation, bytes memory _data) {
        _setImplemeatation(_implementation);

        if (_data.length > 0) {
            (bool success, ) = _implementation.delegatecall(code);
            require(success);
        }
    }

    fallback() external payable {
        _delegate(_getImplementation());
    }

    receive() external payable {
        _delegate(_getImplementation());
    }

    function _delegate(address implementation) private {
        assembly {
            calldatacopy(0, 0, calldatasize())
            let result := delegatecall(gas(), 0, implementation, 0, calldatasize(), 0, 0)
            returndatacopy(0, 0, returndatasize())
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    function _getImplementation() private view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    function _setImplementation(address newImplementation) private {
        if (newImplementation == address(0)) {
            revert InvalidImplementation();
        }
        uint256 size;
        assembly {
            size := extcodesize(newImplementation)
        }
        if (size == 0) {
            revert ImplementationNotContract();
        }
        
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }
}



/**
 * @title UUPSImplementation
 * @notice Implementation with upgrade capability
 */
contract UUPSImplementation {
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(
        uint256(keccak256("eip1967.proxy.implementation")) - 1
    );

    address public owner;
    uint256 public value;

    function initialize(address _owner) external {
        require(owner == address(0), "Already initialized");
        owner = _owner;
    }

    /**
     * @notice Upgrade function lives in implementation!
     */
    function upgradeTo(address newImplementation) external {
        require(msg.sender == owner, "Not owner");
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }

    function setValue(uint256 _value) external {
        value = _value
    }

    function getValue() external view returns(uint256) {
        return value;
    }
}