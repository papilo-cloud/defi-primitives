// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract VotingEscrow {
    struct LockedBalance {
        int128 amount;
        uint256 end;        // Unlock timestamp
    }

    mapping(address => LockedBalance) public locked;

    uint256 constant MAXTIME = 4 * 365 * 86400;  // 4 years

    function createLock(uint256 value, uint256 unlockTime) external {
        require(unlockTime > block.timestamp, "Must be in future");
        require(unlockTime <= block.timestamp + MAXTIME, "Too long");
        require(locked[msg.sender].amount == 0, "Already locked");

        // Round to nearest week (for cleaner decay calculation)
        unlockTime = (unlockTime / (1 weeks)) * 1 weeks;

        locked[msg.sender] = LockedBalance({
            amount: int128(int256(value)),
            end: unlockTime
        });

        // Pull CRV tokens
        // crvToken.transferFrom(msg.sender, address(this), value);
    }

    function balanceOf(address addr) external view returns (uint256) {
        LockedBalance memory lock = locked[addr];
        if (lock.end <= block.timestamp) return 0;

        uint256 timeRemaining = lock.end - block.timestamp;

        // Voting power = amount × (timeRemaining / MAXTIME)
        // Decays linearly to 0 at unlock
        return uint256(int256(lock.amount)) * timeRemaining / MAXTIME;
    }

    function withdraw() external {
        LockedBalance memory lock = locked[msg.sender];
        require(block.timestamp >= lock.end, "Still locked");

        uint256 value = uint256(int256(lock.amount));
        delete locked[msg.sender];

        // crvToken.transfer(msg.sender, value);
    }
}