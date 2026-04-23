// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// Simplified on-chain OCR verification
contract OCRAggregator {
    struct Report {
        int192 median;          // The agreed price
        bytes32[] rs;           // Signature components
        bytes32[] ss;
        bytes32 rawVs;
    }

    address[] public signers;   // Whitelisted node addresses
    uint8 public threshold;     // Minimum signatures required (f+1)

    event AnswerUpdated(int192, uint80, uint32);

    function transmit(
        bytes calldata report,
        bytes32[] calldata rs,
        bytes32[] calldata ss,
        bytes32 rawVs
    ) external {
        // Decode the report
        (int192 median, uint32 timestamp) = abi.decode(report, (int92, uint32));

        // Verify enough valid signatures
        bytes32 reportHash = keccak256(report);
        uint validSignatures = 0;

        for (uint256 i = 0; i < rs.length; i++) {
            uint8 v = uint8(rawVs[i]) + 27;
            address signer = ecrecover(reportHash, v, rs[i], ss[i]);

            if (isValidSigner(signer)) {
                validSignatures++;
            }
        }

        require(validSignatures >= threshold, "Insufficient signatures");

        // Store the valid price
        latestAnswer = median;
        latestTimestamp = timestamp;

        emit AnswerUpdated(median, roundId, timestamp);
    }
}