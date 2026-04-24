// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {GovToken} from "./GovToken.sol";
import {Timelock} from "./Timelock.sol";

contract MiniGovernor {
    Timelock public timelock;
    GovToken public govToken;

    uint public votingDelay = 1; // blocks use (13140 ~2 days in prod)
    uint public votingPeriod = 100; // blocks use (40320 ~2 days in prod)
    uint public proposalThreshold = 1_000e18;
    uint public quorumThreshold = 10_000e18;

    uint proposalCount;

    enum ProposalState {
        Pending,    // Created, voting not started
        Active,     // Voting open
        Canceled,
        Defeated,
        Succeeded,
        Queued,     // In timelock
        Expired,
        Executed
    }

    struct Proposal {
        uint id;
        address proposer;
        uint eta;               // Timelock execution time
        address[] targets;      // Contracts to call
        uint[] values;          // ETH values
        string[] signatures;    // Function signatures
        bytes[] calldatas;      // Encoded arguments
        uint startBlock;
        uint endBlock;
        uint forVotes;
        uint againstVotes;
        uint abstainVotes;
        bool canceled;
        bool executes;
        mapping(address => Receipt) receipts;
    }

    struct Receipt {
        bool hasVoted;
        uint8 support;      // 0=against, 1=for, 2=abstain
        uint96 votes;
    }

    mapping(uint => Proposal) public proposals;

    // ── Propose ──

    function propose(
        address[] memory targets,
        uint[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint) {
        require(
            govToken.getPriorVotes(msg.sender, block.number - 1) >= proposalThreshold,
            "Below threshold"
        );

        proposalCount++;
        Proposal storage p = proposals[proposalCount];
        p.id = proposalCount;
        p.proposer = msg.sender;
        p.startBlock = block.timestamp + votingDelay;
        p.endBlock = block.timestamp + votingDelay + votingPeriod;
        p.targets = targets;
        p.values = values;
        p.calldatas = calldatas;
        p.description = description;

        return proposalCount;
    }

    // ── Vote ──

    function castVote(uint proposalId, uint8 support) external {
        require(state(proposalId) == ProposalState.Active, "Not active");

        Proposal storage p = proposals[proposalId];
        require(!p.receipts[msg.sender].hasVoted, "Already voted");

        // Snapshot at proposal start — flash loan safe
        uint96 votes = govToken.getPriorVotes(msg.sender, p.startBlock);
        
        if (support == 0) p.againstVotes += votes;
        else if (support == 1) p.forVotes += votes;
        else if (support == 2) p.abstainVotes += votes;

        p.receipts[msg.sender].hasVoted = Receipt(true, support, votes);
    }

    // ── Queue → Execute ──

    function queue(uint proposalId) external {
        require(state(proposalId) == ProposalState.Succeeded);

        Proposal storage p = proposals[proposalId];
        uint eta = block.timestamp + 2 days;    // timelock delay
        p.eta = eta;

        for (uint256 i = 0; i < p.targets.length; i++) {
            timelock.queueTransaction(p.targets[i], p.values[i], "", p.calldatas[i], eta);
        }
    }

    function execute(uint proposalId) external {
        require(state(proposalId) == ProposalState.Succeeded);

        Proposal storage p = proposals[proposalId];
        p.executes = true;

        for (uint256 i = 0; i < p.targets.length; i++) {
            timelock.executeTransaction(p.targets[i], p.values[i], "", p.calldatas[i], p.eta);
        }
    }

    // ── State Machine ──

    function state(uint proposalId) public view returns (ProposalState) {
        Proposal storage p = proposals[proposalId];

        if (p.canceled) return ProposalState.Canceled;
        if (block.number <= p.startBlock) return ProposalState.Pending;
        if (block.number <= p.endBlock) return ProposalState.Active;
        if (p.forVotes <= p.againstVotes || p.forVotes < quorumThreshold) return ProposalState.Defeated;
        if (p.eta == 0) return ProposalState.Succeeded;
        if (p.executes) return ProposalState.Executed;
        if (block.timestamp > p.eta + 14 days) return ProposalState.Expired;

        return ProposalState.Queued;
    }
}