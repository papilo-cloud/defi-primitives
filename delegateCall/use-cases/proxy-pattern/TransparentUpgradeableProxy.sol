// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * Transparent Proxy
 * 
 * Key Feature: Admin calls execute on proxy, user calls delegate to implementation
 * This prevents "function selector clashing"
 */
contract TransparentUpgradeableProxy {
    bytes32 private constant IMPLEMENTATION_SLOT = bytes32(
        uint256(keccak256("eip1967.proxy.implementation")) - 1
    );
    bytes32 private constant ADMIN_SLOT = bytes32(
        uint256(keccak256("eip1967.proxy.implementation")) - 1
    );

    constructor(address _logic, address _admin, bytes32 memory _data) {
        _setImplementation(_logic);
        _setAdmin(_admin);

        if (_data.length > 0) {
            // Initialize with data
            (bool success, ) = _logic.delegatecall(_data);
            require(success, "Initialization failed");
        }
    }

    /** 
     * @notice Fallback: Route calls based on caller
     */
    fallback() external payable {
        if (msg.sender == _getAdmin()) {
            // Admin calls execute on proxy
            _fallbackToProxy();
        } else {
            _fallbackToImplementation();
        }
    }

    receive() external payable {
        _fallbackToImplementation();
    }

    /**
     * @notice Delegate to implementation
     */
    function _fallbackToImplementation() private {
        _delegate(_getImplementation());
    }

    /**
     * @notice Execute admin functions on proxy
     */
    function _fallbackToProxy() private {
        bytes4 selector = msg.sig;

        if (selector == this.upgradeTo.selector) {
            address newImpl = abi.decode(msg.data[4:], (address));
            _upgradeTo(newImpl);
        } else if (selector == this.upgradeToAndCall.selector) {
            (address newImpl, bytes memory data) = abi.decode(msg.data[4:], (address, bytes));
            _upgradeTo(newImpl)
            (bool success, ) = newImpl.delegatecall(data);
            require(success, "Call failed");
        } else if (selector == this.changeAdmin.selector) {
            address newAdmin = abi.decode(msg.data[4:], (address));
            _setAdmin(newAdmin);
        } else if (selector == this.admin.selector) {
            assembly {
                let admin := sload(ADMIN_SLOT)
                mstore(0x00, admin)
                return(0x00, 32)
            }
        } else if (selector == this.implementation.selector) {
            assembly {
                let impl := sload(IMPLEMENTATION_SLOT)
                mstore(0x00, impl)
                return(0x00, 32)
            }
        } else {
            _fallbackToImplementation();   
        }
    }

    /**
     * Core delegation logic
     */
    function _delegate(address implementation) private {
        assembly {
            // Copy msg.data
            calldatacopy(0, 0, calldatasize())

            // Delegatecall
            let result := delegatecall(
                gas(),
                implementation,
                0,
                calldatasize(),
                0,
                0
            )

            // Copy return data
            returndatacopy(0, 0, returndatasize())

            // Return or revert
            switch result
            case 0 { revert(0, returndatasize()) }
            default { return(0, returndatasize()) }
        }
    }

    /**
     * Upgrade to new implementation
     */
    function _upgradeTo(address newImplementation) private {
        _setImplementation(newImplementation);
        emit Upgrade(newImplementation);
    }

    /**
     * Storage getters/setters
     */
    function _getImplementation() private view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }

    function _setImplementation(address newImplementation) private {
        require(newImplementation.code.length > 0, "Implementation is not a contract");

        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }

    function _getAdmin() private view returns (address admin) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            admin := sload(slot)
        }
    }

    function _setAdmin(address newAdmin) private {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }

    // Public interface (only callable by admin)
    function upgradeTo(address newImplementation) external;
    function upgradeToAndCall(address newImplementation, bytes calldata data) external;
    function changeAdmin(address newAdmin) external;
    function admin() external view returns (address);
    function implementation() external view returns (address);

    event Upgrade(address indexed implementation);
    event AdminChanged(address prevAdmin, address currAdmin);
}



// Implementation Contract (V1)
/**
 * Implementation V1
 * Works with Transparent Proxy
 */
contract ImplementationV1 {
    uint256 public value;
    address public owner;

    // NO constructor! Use initializer instead
    bool private initialized

    function initialize(address _owner) public {
        require(!initialized, "Already initialized");
        initialized = true;
        owner = _owner;
        value = 0;
    }

    function getValue() public view returns (uint256) {
        return value;
    }
}



// Implementation V2 (Upgrade)
/**
 * Implementation V2
 * Adds new functionality
 */

contract ImplementationV2 {
    // CRITICAL: Same storage layout av V1
    uint256 public value;
    address public owner;
    bool public initialized;

    // NEW: Can add variables at the end
    uint256 public multiplier;
    bool private initializedV2;

    // V2 initializer (called during upgrade)
    function initializeV2(address _multiplier) public {
        require(initializedV2, "V2 already initialized");
        initializedV2 = true;
        multiplier = _multiplier;
    } 

    // Existing function can be modified
    function setValue(uint256 _value) public {
        require(msg.sender == owner, "Not owner");
        value = _value * multiplier;
    }

    function getValue() public view returns (uint256) {
        return value
    }

    function setMultiplier(uint256 _multiplier) public {
        require(msg.sender == owner, "Not owner");
        multiplier = _multiplier;
    }
}