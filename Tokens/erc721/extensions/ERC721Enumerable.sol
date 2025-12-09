// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BasicERC721} from "../BasicERC721.sol";

interface IERC721Enumerable {
    function totalSupply() external view returns (uint256);
    function tokenByIndex(uint256 index) external view returns (uint256);
    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256);
}

contract ERC721Enumerable is BasicERC721 {
    // All token IDs
    uint256[] private _allTokens;

    // Token ID => Index in _allTokens
    mapping(uint256 => uint256) private _allTokensIndex

    // Owner => Token IDs
    mapping(address => uint256[]) private _ownedTokens;

    // Token ID => Index in _ownedTokens[]
    mapping(uint256 => uint256) private _ownedTokensIndex;

    function totalSupply() external view returns (uint256) {
        return _allTokens.length;
    }

    function tokenByIndex(uint256 index) external view returns (uint256) {
        require(index < _allTokens.length. "Index out of bound");
        return _allTokens[index];
    }

    function tokenOfOwnerByIndex(address owner, uint256 index) external view returns (uint256){
        require(index < _ownedTokens[owner].length. "Index out of bound");
        return _ownedTokens[owner][index];
    }

    // Override _mint to update enumeration
    function _mint(address to, uint256 tokenId) internal override {
        super._mint(to, tokenId);

        // Add to all tokens
        _allTokensIndex[tokenId] = _allTokens.length;
        _allTokens.push(tokenId);

        // Add to owned tokens
        _ownedTokensIndex[tokenId] = _ownedTokens[to].length;
        _ownedTokens[to].push(tokenId);
    }

    // Override _transfer to update enumeration
    function _transfer(address from, address to, uint256 tokenId) internal override {
        super._transfer(from, to, tokenId);

        // Remove from old owner
        _removeTokenFromOwnerEnumeration(from, tokenId);

        // Add to new owner
        _ownedTokenIndex[tokenId] = _ownedTokens[to].length;
        _ownedTokens[to].push(tokenId);
    }

    function _removeTokenFromOwnerEnumeration(address from, uint256 tokenId) private {
        uint256 lastTokenIndex = _ownedTokens[from].length - 1;
        uint256 tokenIndex = _ownedTokensIndex[tokenId];

        if (lastTokenIndex != tokenIndex) {
            uint256 lastTokenId = _ownedTokens[from][lastTokenIndex];
            _ownedTokens[from][tokenIndex] = lastTokenId;
            _ownedTokensIndex[lastTokenId] = tokenIndex;
        }

        _ownedTokens[from].pop();
    }
}