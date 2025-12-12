// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC1155 {
    // Transfer single token type
    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes calldata data
    ) external;

    // Batch-transfer multiple token types
    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] calldata ids,
        uint256[] calldata amounts,
        bytes calldata data
    ) external;

    // Get balance of token type for address
    function balanceOf(
        address account,
        uint256 id
    ) external view returns (uint256);

    // Get balances of multiple token types for multiple addresses
    function balanceOfBatch(
        address[] calldata account,
        uint256[] calldata ids
    ) external view returns (uint256[] memory);

    // Approve operator for all token types
    function setApprovalForAll(address operator, bool approved) external;

    // Check if operator approved
    function isApprovedForAll(
        address account,
        address operator
    ) external view returns (bool);

    // Events
    event TransferSingle(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256 id,
        uint256 value
    );
    event TransferBatch(
        address indexed operator,
        address indexed from,
        address indexed to,
        uint256[] ids,
        uint256[] values
    );
    event ApprovalForAll(
        address indexed account,
        address indexed operator,
        bool approved
    );
    event URI(
        string value,
        uint256 indexed id
    );
}

// Receiver interface
interface IERC1155MetadataURI {
    function uri(uint256 id) external view returns (string memory);
}

// Receiver interface
interface IERC1155Receiver {
    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes calldata data
    ) external returns (bytes4);

    function onERC1155BatchReceived(
        address operator,
        address from,
        uint256[] calldata ids,
        uint256[] calldata values,
        bytes calldata data
    ) external returns (bytes4);
}