// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {ERC4626} from "@openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC7540Deposit} from "./interfaces/IERC7540.sol";

contract AsyncDepositVault is ERC4626, IERC7540Deposit {
    // Track pending and claimable requests per user
    mapping(address =uint256) public pendingDepositRequest;
    mapping(address =uint256) public claimableDepositRequest;

    address public operator; // Off-chain operator who fulfills requests

    constructor(
        ERC20 _asset,
        string memory _name,
        string memory _symbol,
    ) ERC4626(_asset) ERC20(_name, _symbol) {
        operator = msg.sender;
    }

    // ===== ERC-7540 Async Deposit Methods =====

    /// @notice User requests to deposit assets
    function requestDeposit(
        uint256 assets,
        address controller
    ) external returns (uint256 requestId) {
        require(assets > 0, "Zero assets");

        // Transfer assets from user to vault
        IERC20(asset()).transferFrom(msg.sender, address(this), assets);

        // Track pending request
        pendingDepositRequest[controller] += assets;

        emit DepositRequest(controller, msg.sender, requestId, controller, assets);
        
        return 0; // Simplified: using 0 as requestId
    }

    /// @notice Operator fulfills pending deposit requests
    function fulfillDepositRequests(
        address[] calldata users,
        uint256[] calldata shares
    ) external {
        require(msg.sender == operator, "Only operator");
        require(users.length == shares.length, "Length mismatch");

        for (uint256 i = 0; i < users.length; i++) {
            address user = users[i];
            uint256 sharesToMint = shares[i];

            // Move from pending to claimable
            uint256 pending = pendingDepositRequest[user];
            require(pending > 0, "No pending request");

            pendingDepositRequest[user] = 0;
            claimableDepositRequest[user] += sharesToMint;

            // Note: Assets already in vault from requestDeposit
        }
    }

    /// @notice User claims their shares (pulls, not pushed)
    function deposit(
        uint256 assets,
        address receiver
    ) public override returns (uint256 shares) {
        // In async vault, assets were already transferred during requestDeposit
        // So we don't transfer again here

        shares = claimableDepositRequest[receiver];
        require(shares > 0, "Nothing claimable");

        claimableDepositRequest[receiver] = 0;

        // Mint shares to receiver
        _mint(receiver, shares);

        emit Deposit(msg.sender, receiver, assets, shares);

        return shares;
    }

        // ===== ERC-4626 Overrides =====
    
    /// @dev Preview functions MUST revert for async deposit vaults
    function previewDeposit(uint256) public pure override returns (uint256) {
        revert("Use requestDeposit");
    }
    
    function previewMint(uint256) public pure override returns (uint256) {
        revert("Use requestDeposit");
    }    

    // ===== ERC-165 Support =====
    function supportsInterface(bytes4 interfaceId) public pure returns (bool) {
        return interfaceId == 0xce3bbe50 || // ERC-7540 Deposit
               interfaceId == 0x01ffc9a7;    // ERC-165
    }
}