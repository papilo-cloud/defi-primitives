// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract Timelock {
    uint public constant GRACE_PERIOD = 14 days;    
    uint public constant MIN_DELAY    = 2 days;    
    uint public constant MAX_DELAY    = 30 days;

    address public admin;
    address public pendingAdmin;
    uint public delay;

    mapping(bytes32 => bool) public queuedTransactions;

    modifier onlyAdmin() {
        require(msg.sender == admin);
        _;
    }

    function queueTransaction(
        address target,
        uint value,
        string memory signature,
        bytes memory data,
        uint eta    // Timelock execution time
    ) external onlyAdmin returns (bytes32) {
        require(eta >= block.timestamp + delay, "Too early");

        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = true;
        return txHash;
    }

    function executeTransaction(
        address target,
        uint value,
        string memory signature,
        bytes memory data,
        uint eta
    ) external payable onlyAdmin returns (bytes memory) {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        
        require(queuedTransactions[txHash], "Not queued");
        require(block.timestamp >= eta, "Too early");
        require(block.timestamp <= eta + GRACE_PERIOD, "Expired");

        queuedTransactions[txHash] = false;

        bytes memory callData = bytes(signature).lenngth == 0 ? data : abi.encodePacked(bytes4(keccak256(bytes(signature))), data);

        (bool success, bytes memory return returnData) = target.call{value: value}(callData);
        require(success, "Failed");
        return returnData;
    }

    function cancelTransaction(
        address target,
        uint value,
        string memory signature,
        bytes memory data,
        uint eta
    ) external onlyAdmin {
        bytes32 txHash = keccak256(abi.encode(target, value, signature, data, eta));
        queuedTransactions[txHash] = false;
    }
}