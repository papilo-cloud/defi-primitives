// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * Complete Upgradeable Proxy with upgradeToAndCall
 * 
 * This implementation follows EIP-1967 for storage slots
 * and includes security best practices
 */
contract UpgradeableProxy {
    
    // EIP-1967 storage slots
    bytes32 private constant IMPLEMENTATION_SLOT = 
        bytes32(uint256(keccak256("eip1967.proxy.implementation")) - 1);
    bytes32 private constant ADMIN_SLOT = 
        bytes32(uint256(keccak256("eip1967.proxy.admin")) - 1);
    
    // Events
    event Upgraded(address indexed implementation);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    
    // Custom errors (gas efficient)
    error NotAuthorized();
    error InvalidImplementation();
    error ImplementationNotContract();
    error UpgradeCallFailed(bytes reason);
    
    /**
     * Constructor
     * @param _implementation Initial implementation contract address
     * @param _admin Address that can upgrade the proxy
     */
    constructor(address _implementation, address _admin) {
        _setImplementation(_implementation);
        _setAdmin(_admin);
    }
    
    /**
     * Modifier to restrict access to admin only
     */
    modifier onlyAdmin() {
        if (msg.sender != _getAdmin()) revert NotAuthorized();
        _;
    }
    
    /**
     * SIMPLE UPGRADE FUNCTION
     * Upgrades to a new implementation
     * 
     * @param newImplementation Address of the new implementation contract
     */
    function upgradeTo(address newImplementation) external onlyAdmin {
        _upgradeTo(newImplementation);
    }
    
    /**
     * UPGRADE AND CALL FUNCTION
     * Upgrades to a new implementation and calls a function on it
     * 
     * This is useful for:
     * 1. Upgrading and initializing new storage variables
     * 2. Migrating data during upgrade
     * 3. Setting up the new implementation
     * 
     * @param newImplementation Address of the new implementation contract
     * @param data Calldata to execute on the new implementation (e.g., initialize function)
     */
    function upgradeToAndCall(address newImplementation, bytes calldata data) 
        external 
        payable 
        onlyAdmin 
    {
        // First, upgrade to new implementation
        _upgradeTo(newImplementation);
        
        // Then, call the initialization function
        assembly {
            // Copy calldata to memory
            let dataSize := data.length
            let dataPtr := mload(0x40)
            calldatacopy(dataPtr, data.offset, dataSize)
            
            // Delegatecall to new implementation
            // This executes the function in the context of THIS contract
            // so it can initialize storage variables
            let result := delegatecall(
                gas(),
                newImplementation,
                dataPtr,
                dataSize,
                0,
                0
            )
            
            // Check if call was successful
            if iszero(result) {
                // Copy revert reason
                let returnSize := returndatasize()
                returndatacopy(0, 0, returnSize)
                revert(0, returnSize)
            }
        }
    }
    
    /**
     * Internal upgrade function with validation
     */
    function _upgradeTo(address newImplementation) internal {
        // Validation checks
        if (newImplementation == address(0)) {
            revert InvalidImplementation();
        }
        
        // Verify it's a contract (has code)
        uint256 size;
        assembly {
            size := extcodesize(newImplementation)
        }
        if (size == 0) {
            revert ImplementationNotContract();
        }
        
        // Set new implementation
        _setImplementation(newImplementation);
        emit Upgraded(newImplementation);
    }
    
    /**
     * Change the admin address
     */
    function changeAdmin(address newAdmin) external onlyAdmin {
        if (newAdmin == address(0)) revert InvalidImplementation();
        
        address previousAdmin = _getAdmin();
        _setAdmin(newAdmin);
        emit AdminChanged(previousAdmin, newAdmin);
    }
    
    /**
     * Get current implementation address
     */
    function implementation() external view returns (address) {
        return _getImplementation();
    }
    
    /**
     * Get current admin address
     */
    function admin() external view returns (address) {
        return _getAdmin();
    }
    
    /**
     * INTERNAL STORAGE FUNCTIONS
     * Using assembly to access EIP-1967 storage slots
     */
    
    function _getImplementation() internal view returns (address impl) {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            impl := sload(slot)
        }
    }
    
    function _setImplementation(address newImplementation) internal {
        bytes32 slot = IMPLEMENTATION_SLOT;
        assembly {
            sstore(slot, newImplementation)
        }
    }
    
    function _getAdmin() internal view returns (address adm) {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            adm := sload(slot)
        }
    }
    
    function _setAdmin(address newAdmin) internal {
        bytes32 slot = ADMIN_SLOT;
        assembly {
            sstore(slot, newAdmin)
        }
    }
    
    /**
     * FALLBACK FUNCTION
     * Delegates all calls to the current implementation
     */
    fallback() external payable {
        _delegate(_getImplementation());
    }
    
    /**
     * RECEIVE FUNCTION
     * Allows contract to receive ETH
     */
    receive() external payable {
        _delegate(_getImplementation());
    }
    
    /**
     * Delegate execution to implementation contract
     */
    function _delegate(address impl) internal {
        assembly {
            // Copy calldata to memory
            calldatacopy(0, 0, calldatasize())
            
            // Delegate call to implementation
            // This executes implementation code with proxy's storage
            let result := delegatecall(gas(), impl, 0, calldatasize(), 0, 0)
            
            // Copy return data
            returndatacopy(0, 0, returndatasize())
            
            // Return or revert based on result
            switch result
            case 0 {
                revert(0, returndatasize())
            }
            default {
                return(0, returndatasize())
            }
        }
    }
}

// ============================================================================
// IMPLEMENTATION CONTRACTS EXAMPLES
// ============================================================================

/**
 * IMPLEMENTATION V1
 * Initial version
 */
contract ImplementationV1 {
    // Storage layout MUST match across all versions
    uint256 public value;
    address public owner;
    
    // Initializer (called once after deployment)
    function initialize(uint256 _value) external {
        require(owner == address(0), "Already initialized");
        value = _value;
        owner = msg.sender;
    }
    
    function setValue(uint256 _value) external {
        require(msg.sender == owner, "Not owner");
        value = _value;
    }
    
    function getValue() external view returns (uint256) {
        return value;
    }
    
    function version() external pure returns (string memory) {
        return "v1";
    }
}

/**
 * IMPLEMENTATION V2
 * Upgraded version with new features
 */
contract ImplementationV2 {
    // CRITICAL: Storage layout must match V1
    uint256 public value;
    address public owner;
    
    // New storage variables go AFTER existing ones
    uint256 public multiplier;
    mapping(address => uint256) public balances;
    
    // Migration function (called via upgradeToAndCall)
    function initializeV2(uint256 _multiplier) external {
        require(multiplier == 0, "Already initialized V2");
        multiplier = _multiplier;
    }
    
    // Enhanced setValue with multiplier
    function setValue(uint256 _value) external {
        require(msg.sender == owner, "Not owner");
        value = _value * multiplier;
    }
    
    function getValue() external view returns (uint256) {
        return value;
    }
    
    // New function
    function setMultiplier(uint256 _multiplier) external {
        require(msg.sender == owner, "Not owner");
        multiplier = _multiplier;
    }
    
    // New function
    function deposit() external payable {
        balances[msg.sender] += msg.value;
    }
    
    function version() external pure returns (string memory) {
        return "v2";
    }
}

/**
 * IMPLEMENTATION V3
 * Another upgrade with data migration
 */
contract ImplementationV3 {
    // Storage layout must match previous versions
    uint256 public value;
    address public owner;
    uint256 public multiplier;
    mapping(address => uint256) public balances;
    
    // New storage
    bool public paused;
    uint256 public totalDeposits;
    
    // Complex migration function
    function initializeV3(address[] calldata users, uint256[] calldata amounts) external {
        require(!paused, "Already initialized V3");
        require(users.length == amounts.length, "Length mismatch");
        
        // Migrate existing balances
        for (uint256 i = 0; i < users.length; i++) {
            balances[users[i]] = amounts[i];
            totalDeposits += amounts[i];
        }
        
        paused = false;
    }
    
    function setValue(uint256 _value) external {
        require(!paused, "Paused");
        require(msg.sender == owner, "Not owner");
        value = _value * multiplier;
    }
    
    function pause() external {
        require(msg.sender == owner, "Not owner");
        paused = true;
    }
    
    function unpause() external {
        require(msg.sender == owner, "Not owner");
        paused = false;
    }
    
    function version() external pure returns (string memory) {
        return "v3";
    }
}

// ============================================================================
// USAGE EXAMPLE CONTRACT
// ============================================================================

contract UpgradeExample {
    UpgradeableProxy public proxy;
    
    /**
     * STEP 1: Deploy and Initialize V1
     */
    function deployV1() external returns (address) {
        // Deploy implementation V1
        ImplementationV1 implV1 = new ImplementationV1();
        
        // Deploy proxy pointing to V1
        proxy = new UpgradeableProxy(address(implV1), msg.sender);
        
        // Prepare initialization data
        bytes memory initData = abi.encodeWithSignature(
            "initialize(uint256)",
            100  // initial value
        );
        
        // Initialize through proxy
        (bool success, ) = address(proxy).call(initData);
        require(success, "Initialization failed");
        
        return address(proxy);
    }
    
    /**
     * STEP 2: Upgrade to V2 with initialization
     */
    function upgradeToV2() external {
        // Deploy implementation V2
        ImplementationV2 implV2 = new ImplementationV2();
        
        // Prepare initialization data for V2
        bytes memory initData = abi.encodeWithSignature(
            "initializeV2(uint256)",
            2  // multiplier value
        );
        
        // Upgrade and initialize in one transaction
        proxy.upgradeToAndCall(address(implV2), initData);
    }
    
    /**
     * STEP 3: Upgrade to V3 with data migration
     */
    function upgradeToV3(address[] calldata users, uint256[] calldata amounts) external {
        // Deploy implementation V3
        ImplementationV3 implV3 = new ImplementationV3();
        
        // Prepare migration data
        bytes memory initData = abi.encodeWithSignature(
            "initializeV3(address[],uint256[])",
            users,
            amounts
        );
        
        // Upgrade and migrate data
        proxy.upgradeToAndCall(address(implV3), initData);
    }
    
    /**
     * STEP 4: Interact with proxy
     */
    function getValue() external view returns (uint256) {
        // Call through proxy - will execute current implementation
        (, bytes memory result) = address(proxy).staticcall(
            abi.encodeWithSignature("getValue()")
        );
        return abi.decode(result, (uint256));
    }
    
    function getVersion() external view returns (string memory) {
        (, bytes memory result) = address(proxy).staticcall(
            abi.encodeWithSignature("version()")
        );
        return abi.decode(result, (string));
    }
}

// ============================================================================
// TESTING HELPER
// ============================================================================

contract ProxyTester {
    /**
     * Example: How to use upgradeToAndCall
     */
    function testUpgradeToAndCall() external {
        // 1. Deploy V1
        ImplementationV1 v1 = new ImplementationV1();
        UpgradeableProxy proxy = new UpgradeableProxy(address(v1), address(this));
        
        // Initialize V1
        (bool success1, ) = address(proxy).call(
            abi.encodeWithSignature("initialize(uint256)", 100)
        );
        require(success1, "V1 init failed");
        
        // 2. Upgrade to V2 with upgradeToAndCall
        ImplementationV2 v2 = new ImplementationV2();
        
        bytes memory v2InitData = abi.encodeWithSignature(
            "initializeV2(uint256)",
            3  // multiplier
        );
        
        proxy.upgradeToAndCall(address(v2), v2InitData);
        
        // 3. Verify upgrade worked
        (, bytes memory versionData) = address(proxy).staticcall(
            abi.encodeWithSignature("version()")
        );
        string memory version = abi.decode(versionData, (string));
        require(
            keccak256(bytes(version)) == keccak256(bytes("v2")),
            "Upgrade failed"
        );
    }
}