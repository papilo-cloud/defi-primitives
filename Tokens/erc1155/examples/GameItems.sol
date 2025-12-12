// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC1155} from "../../ERC1155.sol";

contract GameItems is ERC1155 {
    // Token IDs
    uint256 public constant GOLD = 0;
    uint256 public constant SILVER = 1;
    uint256 public constant SWORD = 2;
    uint256 public constant SHIELD = 3;
    uint256 public constant RARE_SWORD = 4;

    // Token ID => Max supply (0 = unlimited)
    mapping(uint256 => uint256) public maxSupply;

    // Token ID => Current supply
    mapping(uint256 => uint256) public currentSupply;

    constructor() {
        // Fungible currencies (unlimited)
        maxSupply[GOLD] = 0;
        maxSupply[SILVER] = 0;

        // Common items (10,000 each)
        maxSupply[SWORD] = 10000;
        maxSupply[SHIELD] = 10000;

        // Rare item (only 100!)
        maxSupply[RARE_SWORD] = 100;

        // Set URIs
        _setURI(GOLD, "ipfs://gold.json");
        _setURI(SILVER, "ipfs://silver.json");
        _setURI(SWORD, "ipfs://sword.json");
        _setURI(SHIELD, "ipfs://shield.json");
        _setURI(RARE_SWORD, "ipfs://rare-sword.json");
    }

    function mint(address to, uint256 id, uint256 amount) external {
        // Check supply limits
        if (maxSupply[id] > 0) {
            require(
                currentSupply[id] + amount <= maxSupply[id],
                "Exceeds max supply"
            );
            currentSupply[id] += amount;
        }

        _mint(to, id, amount, "");
    }

    function craft(
        address player,
        uint256[] memory materials,
        uint256[] memory amounts,
        uint256 resultId
    ) external {
        // Burn materials
        for (uint256 i = 0; i < materials.length; i++) {
            _burn(player, materials[i], amounts[i]);
        }

        // Mint results
        _mint(player, resultId, 1, "");
    }

    // Example: Craft rare sword from 2 regular swords + 100 gold
    function craftRareSword(address player) external {
        _burn(player, SWORD, 2);
        _burn(player, GOLD, 100);
        _mint(player, RARE_SWORD, 1, "");
    }

    function swap(
        address user1,
        address user2,
        uint256[] memory ids1,
        uint256[] memory ids2,
        uint256[] memory amounts1,
        uint256[] memory amounts2
    ) external {
        require(ids1.length == amounts1.length, "Length mismatch");
        require(ids2.length == amounts2.length, "Length mismatch");

        safeBatchTransferFrom(user1, user2, ids1, amounts1, "");
        safeBatchTransferFrom(user2, user1, ids2, amounts2, "");
    }
}

contract RoleBased {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    mapping(bytes32 => mapping(address => bool)) public hasRole;

    modifier onlyRole(bytes32 role) {
        require(hasRole[role][msg.sender], "Not authorized");
        _;
    }

    function mint(address to, uint256 id, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, id, amount, "")
    }
}