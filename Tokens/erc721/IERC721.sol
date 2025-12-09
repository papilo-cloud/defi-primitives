// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IERC721 {
    // Return number of tokens owned by address
    function balanceOf(address owner) external view returns (uint256);

    // Return owner of token ID
    function ownerOf(uint256 tokenId) external view returns (address);

    // Safe transfer with callback check
    function safeTransferFrom(address from, address to, uint256 tokenId) external;
    function safeTransferFrom(address from, address to, uint256 tokenId, bytes calldata data) external;

    // Transfer without callbask check (dangerous!)
    function transferFrom(address from, address to, uint256 tokenId) external;

    // Approve single token
    function approve(address to, uint256 tokenId) external;

    // Approve all tokens (operator)
    function setApprovalForAll(address operator, bool approved) external;

    // Get approved address for token
    function getApproved(uint256 tokenId) external view returns (address);

    // Check if operator approved for all
    function isApprovedForAll(address owner, address operator) external view returns (bool);

    // Events
    event Transfer(address indexed from, address indexed to, uint256 indexed tokenId);
    event Approval(address indexed owner, address indexed approved, uint256 indexed tokenId);
    event ApprovalForAll(address indexed owner, address indexed operator, bool approved);
}

// Optional metadata extension
interface IERC721Metadata {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function tokenURI(uint256 tokenId) external view returns (string memory);
}