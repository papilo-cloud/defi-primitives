// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {IERC1155, IERC1155MetadataURI} from "./IERC1155.sol";

contract ERC1155 is IERC1155, IERC1155MetadataURI {
    // Token ID => Account => Balance
    mapping(uint256 => mapping(address => uint256)) private _balances;

    // Account => Operator => Approved
    mapping(address => mapping(address => bool)) private _operatorApprovals;

    // Token Id => URI
    mapping(uint256 => string) private _uris;

    function balanceOf(address account, uint256 id) public view returns (uint256) {
        require(account != address(0), "Zero address");
        return _balances[id][account];
    }

    function balanceOfBatch(address[] memory accounts, address[] memory ids) public view returns (uint256[] memory) {
        require(accounts.length == ids.length, "Length mismatch");
        uint256[] memory batchBalances = new uint256[](ids.length);

        for (uint256 i = 0; i < ids.length; i++) {
            batchBalances[i] = balanceOf(accounts[i], ids[i]);
        }

        return batchBalances;
    }

    function setApprovalForAll(address operator, bool approved) external {
        require(msg.sender != operator, "Approve to self");
        _operatorApprovals[msg.sender][operator] = approved;
        emit ApprovalForAll(msg.sender, operator, approved);
    }

    function isApprovedForAll(address account, address operator) public view returns (bool) {
        return _operatorApprovals[account][operator];
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) public {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "Not authorized");
        require(to != address(0), "Transfer to zero address");

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "INsufficient amount");

        unchecked {
            _balances[id][from] = fromBalance - amount;
            _balances[id][to] += amount;
        }

        emit TransferSingle(msg.sender, from, to, id, amount);

        _doSafeTransferAcceptanceCheck(msg.sender, from, to, id, amount, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) public {
        require(from == msg.sender || isApprovedForAll(from, msg.sender), "Not authorized");
        require(to != address(0), "Transfer to zero address");
        require(accounts.length == ids.length, "Length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            uint256 id = ids[i];
            uint256 amount = amounts[i];

            uint256 fromBalance = _balances[id][from];
            require(fromBalance >= amount, "Insufficient balance");

            unchecked {
                _balances[id][from] = fromBalance - amount;
                _balances[id][to] += amount;
            }
        }

        emit TransferBatch(msg.sender, from, to, ids, amounts);
        
        _doSafeBatchTransferAcceptanceCheck(msg.sender, from, to, ids, amounts, data);
    }

    function _mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal {
        require(to != address(0), "Mint to zero");

        _balances[id][to] += amount;
        emit TransferSingle(msg.sender, address(0), to, id, amount);

        _doSafeTransferAcceptanceCheck(msg.sender, address(0), to, id, amount, data);
    }

    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal {
        require(to != address(0), "MInt to zero");
        require(ids.length == amounts.length, "Length mismatch");

        for (uint256 i = 0; i < ids.length; i++) {
            _balances[ids[i]][to] += amounts[i];
        }

        emit TransferBatch(msg.sender, address(0), to, ids, amounts);

        _doSafeBatchTransferAcceptanceCheck(msg.sender, address(0), to, ids, amounts, data);
    }

    function _burn(address from, uint256 id, uint256 amount) internal {
        require(from != address(0), "Burn from zero");

        uint256 fromBalance = _balances[id][from];
        require(fromBalance >= amount, "Insufficient balance");

        unchecked {
            _balances[id][from] = fromBalance - amount;
        }

        emit TransferSingle(msg.sender, from, address(0), id, amount);
    }

    function uri(uint256 id) public view returns (string memory) {
        return _uris[id];
    }

    function _setURI(uint256 id, string memory newUri) internal {
        _uris[id] = newUri;
        emit URI(newUri, id);
    }

    function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155Received(
                operator, from, id, amount, data
            ) returns (bytes4 response) {
                require(
                    response == IERC1155Receiver.onERC1155Received.selector,
                    "Rejected"
                );
            } catch {
                revert("Non-receiver");
            }
        }
    }

        function _doSafeTransferAcceptanceCheck(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) private {
        if (to.code.length > 0) {
            try IERC1155Receiver(to).onERC1155BatchReceived(
                operator, from, ids, amounts, data
            ) returns (bytes4 response) {
                require(
                    response == IERC1155Receiver.onERC1155BatchReceived.selector,
                    "Rejected"
                );
            } catch {
                revert("Non-receiver");
            }
        }
    }
}