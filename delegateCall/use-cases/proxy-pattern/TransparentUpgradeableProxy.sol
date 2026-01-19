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

    event Upgrade(address indexed implementation);
    event AdminChanged(address prevAdmin, address currAdmin);

    error NotAuthorized();
    error InvalidImplementation();
    error ImplementationNotContract();
    error InitializationFailed();
    error UpgradeCallFailed(bytes reason);

    modifier onlyAdmin() {
        if(msg.sender != _getAdmin()) revert NotAuthorized();
        _;
    }

    constructor(address _logic, address _admin, bytes memory _data) {
        _setImplementation(_logic);
        _setAdmin(_admin);

        if (_data.length > 0) {
            // Initialize with data
            (bool success, ) = _logic.delegatecall(_data);
            if(!success) revert InitializationFailed();
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
            _upgradeTo(newImpl);
            (bool success, ) = newImpl.delegatecall(data);
            require(success, "Call failed");
        } else if (selector == this.changeAdmin.selector) {
            address newAdmin = abi.decode(msg.data[4:], (address));
            _setAdmin(newAdmin);
        } else if (selector == this.admin.selector) {
            bytes32 slot = ADMIN_SLOT;
            assembly {
                let admin := sload(slot)
                mstore(0x00, admin)
                return(0x00, 32)
            }
        } else if (selector == this.implementation.selector) {
            bytes32 slot = IMPLEMENTATION_SLOT;
            assembly {
                let impl := sload(slot)
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
            // Copy msg.data, calldata to memory
            calldatacopy(0, 0, calldatasize())

            // Delegatecall to implementation
            // This executes implementation code with proxy storage
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
        if (newImplementation == address(0)) {
            revert InvalidImplementation();
        }

        // Verify if it's a contract
        uint256 size;
        assembly {
            size := extcodesize(newImplementation)
        }
        if (size == 0) {
            revert ImplementationNotContract();
        }

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
    function upgradeTo(address newImplementation) external onlyAdmin {
        _upgradeTo(newImplementation);
    }

    function upgradeToAndCall(address newImplementation, bytes calldata data) external onlyAdmin {
        _upgradeTo(newImplementation);
        (bool success, ) = newImplementation.delegatecall(data);
        if(!success) revert UpgradeCallFailed("Upgrade call failed");
    }

    function changeAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert InvalidImplementation();

        address prevAdmin = _getAdmin();
        _setAdmin(newAdmin);
        emit AdminChanged(prevAdmin, newAdmin);
    }

    function admin() external view returns (address) {
        return _getAdmin();
    }

    function implementation() external view returns (address) {
        return _getImplementation();
    }
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
    bool private initialized;

    function initialize(address _owner) public {
        require(!initialized, "Already initialized");
        initialized = true;
        owner = _owner;
        value = 0;
    }

    function setValue(uint256 _value) public {
        require(msg.sender == owner, "Not owner");
        value = _value;
    }

    function getValue() public view returns (uint256) {
        return value;
    }

    function getVersion() public pure returns (string memory) {
        return "V1";
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

    // NEW: Can add variables at the end
    uint256 public multiplier;
    mapping(address => uint256) public balances;

    // V2 initializer (called during upgrade)
    function initializeV2(uint256 _multiplier) public {
        require(multiplier == 0, "V2 already initialized");
        owner = msg.sender; // Just for safety
        multiplier = _multiplier;
    } 

    // Existing function can be modified
    function setValue(uint256 _value) public {
        require(msg.sender == owner, "Not owner");
        value = _value * multiplier;
    }

    function getValue() public view returns (uint256) {
        return value;
    }

    function setMultiplier(uint256 _multiplier) public {
        require(msg.sender == owner, "Not owner");
        multiplier = _multiplier;
    }

    function deposit() public payable {
        balances[msg.sender] += msg.value;
    }

    function getVersion() public pure returns (string memory) {
        return "V2";
    }
}


// Note: In practice, use OpenZeppelin's TransparentUpgradeableProxy for security and reliability.
/**
 * IMPLEMENTATION V3
 * Another upgrade with data migration
 */
contract ImplementationV3 {
    // CRITICAL: Same storage layout as V1 and V2
    uint256 public value;
    address public owner;
    uint256 public multiplier;
    mapping(address => uint256) public balances;

    // New variable added in V3
    bool public paused;
    uint256 public totalDeposits;

    // Migrate existing data
    function migrateData() public {
        require(msg.sender == owner, "Not owner");
        totalDeposits = 0;
        // Sum all balances to get total deposits
        for (uint i = 0; i < 100; i++) { // Simplified for example
            totalDeposits += balances[address(i)];
        }
    }

    function setValue(uint256 _value) public {
        require(!paused, "Paused");
        require(msg.sender == owner, "Not owner");
        value = _value * multiplier;
    }

    function pause() public {
        require(msg.sender == owner, "Not owner");
        paused = true;
    }

    function unpause() public {
        require(msg.sender == owner, "Not owner");
        paused = false;
    }

    function getVersion() public pure returns (string memory) {
        return "V3";
    }

    function getTotalDeposits() public view returns (uint256) {
        return totalDeposits;
    }
}