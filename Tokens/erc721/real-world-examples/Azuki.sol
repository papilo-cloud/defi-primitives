// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {BasicERC721} from "../BasicERC721.sol";
import {ERC721Enumerable} from "../../ERC721Enumerable.sol";

contract Azuki is BasicERC721, ERC721Enumerable {
    uint256 public constant MAX_SUPPLY = 10000;
    uint256 public constant PRICE = 1 ether;
    uint256 public constant MAX_PER_MINT = 5;
    
    uint256 private _tokenIdCounter;
    string private _baseTokenURI;
    address private owner;

    modifier onlyOwner() {
        require(owner == msg.sender, "Not the owner");
        _;
    }

    constructor() BasicERC721("Azuki", "AZUKI"){
        owner = msg.sender
    }

    function mint(uint256 quantity) external payable {
        require(quantity <= MAX_PER_MINT, "Exceeds max per mint");
        require(_tokenIdCounter + quantity <= MAX_SUPPLY, "Exceeds max supply");
        require(msg.value >= PRICE * quantity, "Insufficient payment");

        for (uint256 i = 0; i < quantity; i++) {
            _safeMInt(msg.sender, _tokenIdCounter);
            _tokenIdCounter++;
        }
    }

    function setBaseURI(string memory baseURI) external {
        _baseTokenURI = baseURI;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        address owner = _owners[tokenId];
        require(owner != address(0), "Token doesn't exist");
        return string(abi.encodePacked(_baseTokenURI, toString(tokenId), ".json"));
    }
}