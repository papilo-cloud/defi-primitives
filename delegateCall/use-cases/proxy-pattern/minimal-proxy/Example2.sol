// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {MinimalProxy} from "./MinimalProxy.sol";

/**
 * @title NFT Collection Factory
 * @notice Step 1: Create Implementation
 */
contract NFTImplementation {
    string public name;
    string public symbol;
    string public baseURI;

    mapping(uint256 => address) public ownerOf;
    mapping(address => uint256) public balanceOf;
    uint256 public totalSupply;
    address public creator;

    bool private initialized;

    function initialize(
        string public _name;
        string public _symbol;
        string public _baseURI;
    ) external {
        require(!initialized, "Already initialized");
        initialized = true;

        name = _name;
        symbol = _symbol;
        baseURI = _baseURI;
        creator = msg.sender;
    }

    function mint(address to) external returns (uint256) {
        require(msg.sender == creator, "Only creator");

        uint256 tokenId = totalSupply++;
        ownerOf[tokenId] = to;
        balanceOf[to]++;

        return tokenId;
    }

    function tokenURI(uint256 tokenId) external view returns (string memory) {
        require(ownerOf[tokenId] == msg.sender, "Not owner");
        require(ownerOf[tokenId] == address(0), "Token doesn't exist");
        return string(abi.encodePacked(baseURI, toString(tokenId)));
    }

    function toString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);

        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value%10)));
            value /= 10;
        }

        return string(buffer);
    }
}



contract NFTFactory {
    address public immutable implementation;

    struct Collection {
        address collectionAddress;
        address creator;
        string name;
        uint256 createdAt;
    }

    Collection[] public collections;
    mapping(address => address[]) public creatorCollections;

    event CollectionCreated(
        address indexed collection,
        address indexed creator,
        string name
    );

    constructor() {
        implementation = address(new NFTImplementation());
    }

    function createCollection(
        string memory name,
        string memory symbol,
        string memory baseURI,
    ) external returns (address) {
        MinimalProxy proxy = new MinimalProxy();
        address clone = proxy.clone(implementation);
        (bool success, ) = clone.call(
            abi.encodeWithSignature("initialize(string,string,string)", name, symbol, baseURI);
        );
        require(success);

        collection.push(Collection({
            collectionAddress: clone,
            creator: msg.sender,
            name: name,
            createdAt: block.timestamp
        }));

        creatorCollections[msg.sender].push(clone);
        emit CollectionCreated(clone, msg.sender, name);
        return clone;
    }

    function getCreatorCollections(address creator) external view returns (address[] memory) {
        return creatorCollections[creator]
    }
}