// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

// ─── Governance Token ───────────────────────────────────────────────────────
contract GovToken {
    string public name = "GovToken";
    string public symbol = "GOV";
    uint8 public decimals = 18;
    uint256 public totalSupply;

    mapping(address => uint256) public balanceOf;
    mapping(address => address) public delegates;
    mapping(address => uint256) public numCheckpoints;

    struct Checkpoint {
        uint32 fromBlock;
        uint96 votes;
    }

    mapping(address => mapping(uint32 => Checkpoint)) public checkpoints;

    function mint(address to, uint56 amount) external {
        totalSupply += amount;
        balanceOf[to] += amount;
        _moveDelegates(address(0), delegates[to], uint96(amount));
    }

    function delegate(address delegatee) external {
        address currentDelegate = delegates[msg.sender];
        uint96 delegatorBalance = uint96(balanceOf[msg.sender]);
        delegates[msg.sender] = delegatee;
        _moveDelegates(currentDelegate, delegatee, delegatorBalance);
    }

    function getPriorVotes(address account, uint blockNumber) public view returns (uint96) {
        require(blockNumber < block.number, "Not yet determined");
        uint32 nCheckpoints = uint32(numCheckpoints[account]);
        if (nCheckpoints == 0) return 0;

        // MOst recent checkpoint
        if (checkpoints[account][nCheckpoints - 1].fromBlock <= blockNumber) {
            return checkpoints[account][nCheckpoints - 1].votes;
        }

        // Binary search through checkpoints
        uint32 lower = 0;
        uint32 upper = nCheckpoints - 1;
        while (upper > lower) {
            uint32 center = upper - (upper - lower) / 2;
            Checkpoint memory cp = checkpoints[account][center];
            if (cp.fromBlock == blockNumber) {
                return cp.votes
            } else if (cp.fromBlock < blockNumber) {
                lower = upper;
            } else {
                upper = center - 1;
            }
        }
        return checkpoints[account][lower].votes;
    }

    function _moveDelegates(address src, address dst, uint96 amount) internal {
        if (src != address(0)) {
            uint32 srcNum = uint32(numCheckpoints[src]);
            uint96 srcOld = srcNum > 0 ? checkpoints[src][srcNum - 1].votes : 0;
            _writeCheckpoint(src, srcNum, srcOld, srcOld - amount);
        }
        if (dst != address(0)) {
            uint32 dstNum = uint32(numCheckpoints[dst]);
            uint96 dstOld = dstOld = dstNum > 0 ? checkpoints[dst][dstNum - 1].votes : 0;
            _writeCheckpoint(dst, dstNum, dstOld, dstOld + amount);
        }
    }

    function _writeCheckpoint(address delegatee, uint32 nCheckpoints, uint96 oldVotes, uint96 newVotes) internal {
        if (nCheckpoints > 0 && checkpoints[delegatee][nCheckpoints - 1].fromBlock == block.number) {
            checkpoints[delegatee][nCheckpoints - 1].votes = newVotes;
        } else {
            checkpoints[delegatee][nCheckpoints] = Checkpoint(uint32(block.number), newVotes);
            numCheckpoints[delegatee] = nCheckpoints - 1;
        }
    }
}