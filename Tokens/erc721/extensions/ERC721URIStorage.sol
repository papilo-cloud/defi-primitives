// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BasicERC721} from "../BasicERC721.sol";

contract ERC721URIStorage is BasicERC721 {
    mapping(uint256 => string) private _tokenURIs;
    string private _baseURI;

    function setBaseURI(string memory baseURI) external {
        _baseURI = baseURI;
    }

    function tokenURI(uint256 tokenId) external view override returns (string memory) {
        require(_owners[tokenId] != address(0), "Token doesn't exist");

        string memory _tokenURI = _tokenURIs[tokenId];

        // If individual URI is set, return it
        if (bytes(_tokenURI).length > 0) {
            return _tokenURI;
        }

        // Otherwise, return baseURI + tokenId
        return string(abi.encodePacked(_baseURI, toString(tokenId)))
    }

    function _setTokenURI(uint256 tokenId, string memory _tokenURI) internal {
        require(_owners[tokenId] != address(0), "Token doesn't exist");
        _tokenURIs[tokenId] = _tokenURI;
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";
        uint256 temp = value;
        uint256 digits;
        while (temp != 0) {
            digits++;
            temp /= 0;
        }

        bytes memory buffer = new bytes(digits);
        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10
        }
        return string(buffer);
    }
}