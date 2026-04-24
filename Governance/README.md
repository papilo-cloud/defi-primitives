# Governance — Deep Dive

Governance is how a DeFi protocol makes decisions without a CEO. It's the system that answers: **who controls the protocol, how do changes happen, and how do you stop bad actors from taking over?**

Get it wrong and your protocol gets drained. Get it right and you have a self-sustaining organization that outlives any individual team.

---

## What Governance Actually Controls

Before the mechanics, understand the **stakes.** A governance system controls:

```
Treasury:
  Uniswap DAO treasury → $3B+ in UNI tokens
  A single malicious proposal passing = entire treasury drained

Protocol Parameters:
  Interest rates, collateral ratios, fee switches
  Wrong parameter → protocol insolvency

Smart Contract Upgrades:
  Governance can replace any contract in the system
  Malicious upgrade = backdoor into every user's funds

Fee Distribution:
  Who gets protocol revenue
  Billions of dollars per year at stake
```

This is why governance design is one of the hardest problems in DeFi. You're building a decision-making system where the wrong decision costs billions.

---

## How On-Chain Governance Works — The Full Lifecycle

### Compound Governor (The Standard)

Most DeFi governance is a fork or variation of Compound's Governor. Understanding it means understanding 80% of DeFi governance.

```
Proposal Lifecycle:

[Pending] → [Active] → [Succeeded/Defeated] → [Queued] → [Executed]
               ↓                                    ↓
           [Canceled]                          [Expired]
```

Each stage has a purpose:

```
Pending (Voting Delay):
  Proposal exists but voting hasn't started
  Gives token holders time to:
    - Read the proposal
    - Acquire/delegate tokens
    - Organize opposition
  Duration: typically 1-2 days

Active (Voting Period):
  Token holders cast votes
  Duration: typically 3-7 days
  After: counted → Succeeded or Defeated

Queued (Timelock):
  Passed proposal sits in timelock contract
  Community can react to malicious proposals
  Duration: typically 2-7 days
  Critical security layer

Executed:
  Proposal's transactions run on-chain
  Changes take effect
  
Expired:
  Queued proposal not executed within window
  Expires to prevent stale proposals executing later
```

---

## Deep Understanding: Mechanisms

### 1. Quorum Requirements

Quorum = **minimum participation** needed for a vote to be valid.

```
Example: Uniswap requires 40M UNI votes to reach quorum
         (out of 1B total UNI = 4% threshold)

If a proposal gets:
  60M FOR, 5M AGAINST → Passes (quorum met, majority FOR)
  30M FOR, 5M AGAINST → Fails  (quorum not met, doesn't matter if majority FOR)
  60M FOR, 61M AGAINST → Fails (quorum met but majority AGAINST)
```

**Why quorum matters:**

```
Without quorum:
  10 whale accounts vote FOR a malicious proposal
  Everyone else doesn't notice
  Proposal passes with 0.01% of supply
  
With quorum:
  Attacker must mobilize significant token supply
  Raises attack cost dramatically
  Forces community engagement
```

**The quorum dilemma:**

```
Too low:  Easy for small group to pass proposals (attack risk)
Too high: Nothing ever passes (governance paralysis)

Compound: 400,000 COMP (~4% of supply) — historically very hard to reach
Uniswap:  40M UNI (4% of supply) — often fails quorum
MakerDAO: Dynamic quorum based on topic sensitivity
```

**Real consequence:** Uniswap's fee switch vote (distribute fees to UNI holders) has failed multiple times purely due to insufficient voter turnout despite majority support. Quorum requirements can freeze even uncontroversial decisions.

---

### 2. Voting Delay & Period

```solidity
contract GovernorSettings {
    // Voting delay: blocks before voting starts after proposal
    uint256 public votingDelay = 13140;    // ~2 days in blocks (6500 blocks/day)
    
    // Voting period: how long voting is open
    uint256 public votingPeriod = 40320;   // ~7 days in blocks
    
    // Proposal threshold: tokens needed to create proposal
    uint256 public proposalThreshold = 1_000_000e18;  // 1M tokens
}
```

**Voting delay — the snapshot problem:**

```
Without voting delay:
  Attacker sees proposal posted
  Buys 10M tokens in the same block
  Immediately votes FOR malicious proposal
  
With voting delay:
  Proposal posted at block 1,000,000
  Token snapshot taken at block 1,000,000
  Voting starts at block 1,013,140

  Tokens bought AFTER block 1,000,000 have NO voting power
  Attack requires buying tokens BEFORE seeing the proposal
  → Much harder, much more expensive
```

**Voting period — the participation tradeoff:**

```
Too short (1 day):
  Many token holders miss the vote
  Whales who watch closely dominate
  Flash loan attacks easier (short window)
  
Too long (30 days):
  Governance is sluggish
  Can't respond quickly to emergencies
  Voter fatigue (participation drops over time)
  
Sweet spot: 5-7 days for major proposals
            2-3 days for parameter adjustments
```

---

### 3. Timelock (Execution Delay)

The timelock is the **most important security mechanism** in governance. It's the gap between a proposal passing and actually executing.

```solidity
contract TimelockController {
    uint256 public minDelay;  // Minimum wait time
    
    mapping(bytes32 => uint256) public timestamps;  // proposalId → execution time
    
    function schedule(
        address target,
        uint value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt,
        uint256 delay
    ) external onlyRole(PROPOSER_ROLE) {
        require(delay >= minDelay, "Delay too short");
        
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        timestamps[id] = block.timestamp + delay;
        
        emit CallScheduled(id, target, value, data, delay);
    }
    
    function execute(
        address target,
        uint value,
        bytes calldata data,
        bytes32 predecessor,
        bytes32 salt
    ) external onlyRole(EXECUTOR_ROLE) {
        bytes32 id = hashOperation(target, value, data, predecessor, salt);
        
        require(block.timestamp >= timestamps[id], "Too early");
        require(timestamps[id] != 0, "Not scheduled");
        
        timestamps[id] = 0;
        
        (bool success,) = target.call{value: value}(data);
        require(success, "Execution failed");
    }
    
    // Emergency: cancel a queued proposal
    function cancel(bytes32 id) external onlyRole(CANCELLER_ROLE) {
        timestamps[id] = 0;
        emit Cancelled(id);
    }
}
```

**What the timelock enables:**

```
Scenario: Malicious proposal passes somehow

Without timelock:
  Proposal passes → executes immediately
  Funds drained before anyone reacts
  
With 48-hour timelock:
  Proposal passes
  Community has 48 hours to:
    - Identify the attack
    - Multi-sig cancels the proposal
    - Alert users to withdraw funds
    - Fork the protocol if necessary
    
  The timelock is a circuit breaker
  Even if governance is compromised, you have an exit window
```

**Timelock length tradeoffs:**

```
Protocol          Timelock    Reasoning
──────────────────────────────────────────────
Compound          48 hours    Balance speed vs safety
Uniswap           7 days      High value treasury, extra cautious  
MakerDAO          24-72 hours Varies by proposal type
Aave              24 hours    DeFi needs to respond to market

Shorter: More responsive to emergencies
Longer:  More time to detect/cancel attacks
```

---

### 4. Delegation

Token holders often don't vote. Delegation solves this:

```solidity
contract ERC20Votes {
    // Each account can delegate their voting power
    mapping(address => address) private _delegates;
    
    // Checkpointed voting power (snapshot per block)
    mapping(address => Checkpoint[]) private _checkpoints;
    
    struct Checkpoint {
        uint32 fromBlock;
        uint224 votes;
    }
    
    function delegate(address delegatee) external {
        _delegate(msg.sender, delegatee);
    }
    
    function _delegate(address delegator, address delegatee) internal {
        address currentDelegate = _delegates[delegator];
        uint256 delegatorBalance = balanceOf(delegator);
        
        _delegates[delegator] = delegatee;
        
        // Move voting power from old → new delegate
        _moveVotingPower(currentDelegate, delegatee, delegatorBalance);
    }
    
    function getVotes(address account) external view returns (uint256) {
        // Returns voting power at current block
        return _checkpoints[account].length == 0 
            ? 0 
            : _checkpoints[account][_checkpoints[account].length - 1].votes;
    }
    
    function getPastVotes(address account, uint256 blockNumber) 
        external view returns (uint256) 
    {
        // Binary search through checkpoints for historical voting power
        // This is what prevents buying tokens after proposal creation
        return _checkpointsLookup(_checkpoints[account], blockNumber);
    }
}
```

**How delegation works in practice:**

```
Typical token holder:
  Has 50,000 UNI tokens
  Never votes (too busy, doesn't understand proposals)
  50,000 UNI = dead voting power

With delegation:
  Delegates to a trusted delegate (researcher, DAO contributor)
  Delegate now has 50,000 extra UNI to vote with
  Retains ownership (can undelegate anytime)
  Delegate cannot transfer tokens
```

**The delegate ecosystem:**

```
Uniswap has ~100 active delegates
Top delegates control 100M+ UNI each (delegated by others)

Delegates are:
  - Protocol researchers (a16z research, GFX Labs)
  - DeFi funds (Blockchain Capital, Andreessen)
  - Community members who post regular governance updates
  - Other protocols (Aave delegates to Aave treasury, etc.)
  
This creates a representative democracy layer
Instead of direct democracy (impractical at scale)
```

**Self-delegation quirk:**

```solidity
// You must delegate to YOURSELF to have voting power
// Even if you hold tokens, voting power = 0 until you call:

token.delegate(msg.sender);  // Activate your own voting power

// Why? Gas optimization — 
// Tracking voting power for every transfer is expensive
// Only track when explicitly activated
```

---

### 5. Vote Escrow (ve-Model)

Invented by Curve Finance, now used everywhere. The core idea: **lock tokens longer = more voting power.**

```
veCRV (vote-escrowed CRV):

Lock 1 CRV for 1 week   → 0.0019 veCRV  (almost nothing)
Lock 1 CRV for 1 year   → 0.25 veCRV
Lock 1 CRV for 2 years  → 0.50 veCRV
Lock 1 CRV for 4 years  → 1.00 veCRV    (maximum)

veCRV decays linearly as time passes:
  Lock 4 years → 1 veCRV
  After 1 year → 0.75 veCRV
  After 2 years → 0.50 veCRV
  After 4 years → 0 veCRV (fully unlocked)
```

**What veCRV gives you:**

```
1. Voting power (governance)
2. Boosted CRV rewards (up to 2.5x on liquidity positions)
3. Share of protocol fees (50% of trading fees → veCRV holders)
4. Gauge weight voting (direct CRV emissions to pools)
```

**Gauge weight voting — the "Curve Wars":**

```
Curve emits CRV tokens to liquidity providers continuously
Distribution between pools = determined by gauge weights
Gauge weights = voted on weekly by veCRV holders

If you control enough veCRV:
  → Vote 100% weight to your pool
  → Your pool gets massive CRV emissions
  → APY spikes → LPs pile in → your pool has deep liquidity

This is worth real money:
  More liquidity → lower slippage → more trading volume
  More volume → more fees → more attractive pool
  Every major stablecoin issuer needs Curve liquidity
```

**This created the Curve Wars:**

```
Convex Finance built on top of Curve:
  
  Users deposit CRV → Convex locks it as veCRV forever
  Convex issues cvxCRV (liquid representation)
  Convex controls massive veCRV voting bloc
  
  Protocols bribe Convex/veCRV holders:
    "Vote your veCRV weight to our pool"
    "We'll pay you $500K in our token per week"
  
  This created a meta-governance layer:
    Control veCRV → control Curve emissions
    Control Curve emissions → control DeFi liquidity
    Control DeFi liquidity → control entire ecosystems
    
  Convex accumulated 50%+ of all veCRV
  They became the de-facto controller of Curve governance
```

### [Implementing ve-model](./VotingEscrow.sol)

---

## Attacks on Governance

### Attack 1: Token Accumulation (Buy and Pass)

The straightforward attack:

```
Target: Protocol with $500M treasury, governance by GOV token

Step 1: Research
  Total GOV supply: 100M tokens
  Quorum: 10M tokens (10%)
  Current market cap: $50M
  Treasury: $500M
  
  Attack cost: Buy 10M GOV ≈ $5M
  Attack reward: Control $500M treasury
  ROI: 10,000%

Step 2: Accumulate quietly
  Buy GOV slowly over weeks (avoid price impact)
  Use multiple wallets
  Look like a legitimate large holder

Step 3: Draft malicious proposal
  "Transfer 50M USDC from treasury to address X"
  X is attacker's wallet
  
Step 4: Vote passes
  Attacker's 10M tokens meets quorum
  Other holders don't notice or don't care
  
Step 5: Execute after timelock
  Wait out timelock
  Execute → drain treasury
```

**Real example: Build Finance (2022)**

```
Attacker accumulated enough BUILD tokens
Passed proposal to mint 1.1B new tokens to themselves
All governance tokens → worthless overnight
Treasury → drained

Cost of attack: ~$160,000
Value extracted: ~$500,000

Why it worked:
  Low quorum threshold
  Low token market cap (cheap to buy control)
  Community not engaged in governance
  No multi-sig veto
```

---

### Attack 2: Flash Loan Governance

The fast version — borrow voting power for a single transaction:

```
Without snapshot protection:

Block N:
  1. Flash loan 10M GOV tokens from lending protocol
  2. Vote on malicious proposal (or create + vote if same block possible)
  3. Repay flash loan
  4. Net cost: just the flash loan fee (~0.09%)

This is why ERC20Votes uses block snapshots:
  Voting power = tokens held at proposal creation block
  Flash-borrowed tokens weren't held at snapshot
  → Flash loan attack impossible with proper implementation
```

**But the attack evolved — multi-block flash loan governance:**

```
Some protocols allow same-block voting
Or have very short voting delays

Block N:   Borrow 10M GOV tokens
Block N+1: Proposal created (snapshot taken with borrowed tokens)
Block N+2: Repay loan (but voting power is locked to snapshot)
Block N+3 to N+7: Vote using snapshot voting power

This requires the protocol to use current balance vs snapshot balance
MakerDAO's old MCD governance was vulnerable to this
```

**The Beanstalk attack (2022) — $182M:**

```
Beanstalk used a governance system where:
  - Proposals could be voted on immediately
  - Flash loans could vote
  - No timelock

Attack sequence (single transaction):
  1. Flash loan $1B worth of assets
  2. Deposit into Beanstalk liquidity pools
  3. Receive STALK governance tokens
  4. Immediately vote FOR pre-staged malicious proposal
  5. Proposal executes: drains $182M from protocol
  6. Repay flash loan
  7. Keep $182M

Total time: 13 seconds (1 transaction)
Loss: $182M
Recovery: Zero
```

---

### Attack 3: Bribe Attacks

Subtler and increasingly common:

```
Legitimate path:
  Protocol A needs Curve gauge weight
  Protocol A buys CRV/CVX to vote themselves
  Cost: $10M+ depending on voting power needed

Bribe path:
  Protocol A goes to Votium (bribe marketplace)
  Offers $1M in token X per week to veCRV voters
  who vote for their gauge

  veCRV holders calculate:
    Earn $1M in bribes for voting with my 1M veCRV
    vs. Earn $200K in base fees
    
  Rational choice: take the bribe
  Protocol A gets gauge weight for $1M
  vs $10M+ in token purchases

  Scale: Votium processes $50M+/month in bribes
```

**Where bribing becomes an attack:**

```
Malicious bribe:
  Attacker wants to drain Compound treasury
  
  "I'll pay 0.5 ETH per 1000 COMP votes
   to any holder who votes FOR proposal #117"
   
  Legitimate holders don't read the proposal
  They just see free ETH
  Vote FOR → malicious proposal passes
  
This is rational individual behavior leading to catastrophic outcome
The "voter apathy + financial incentive" combination is deadly
```

**The Tornado Cash governance attack (2023):**

```
Attacker submitted innocent-looking proposal
Hidden inside: a function that also granted 1.2M TORN tokens to attacker

Community voted FOR (looked legitimate)
After passing, attacker had 1.2M TORN (majority voting power)
Used it to:
  - Take over governance entirely
  - Drain treasury
  - Delist TORN from exchanges (reputation destroyed)
  
Lesson: Always audit the FULL bytecode, not just the description
```

---

## Solutions

### 1. Timelock Delays (Already Covered)

The minimum viable protection. Buys time to react.

```
Minimum timelocks by protocol type:

Small protocol (<$10M TVL):   24 hours
Medium protocol ($10-100M):   48 hours
Large protocol (>$100M):      7 days
Core infrastructure:          14+ days

Emergency actions:
  Some protocols have "guardian" multi-sig
  Can execute time-sensitive fixes faster
  With limited scope (can't drain treasury)
```

---

### 2. Multi-sig Veto

A safety committee with power to cancel queued proposals:

```
Structure:
  5/9 multi-sig of trusted community members
  Can cancel any queued proposal
  Cannot propose or execute
  Cannot drain treasury
  Can only CANCEL

This creates a human layer of protection:
  Malicious proposal passes vote
  Community alerts security council
  5/9 members sign cancellation
  Proposal cancelled before execution
  
The multi-sig is the last line of defense
Even if governance is compromised
```

**The trust problem with multi-sigs:**

```
Multi-sig introduces centralization
Members could collude to:
  - Cancel legitimate proposals (censorship)
  - Be bribed to NOT cancel malicious proposals
  
Mitigation:
  - Members are public (reputation at stake)
  - Members are geographically distributed
  - Members from different organizations
  - Rotating membership via governance
  - Time-limited veto power (can't block forever)
```

**Aave's Guardian model:**

```
Aave guardian = 10/15 multi-sig
Members: Aave Companies, delegates, community leads

Powers:
  ✅ Can cancel proposals in queue
  ✅ Can freeze markets in emergency
  ❌ Cannot move treasury
  ❌ Cannot change protocol code directly
  ❌ Cannot pass proposals without governance
```

---

### 3. Conviction Voting

Instead of binary votes with deadlines, conviction builds continuously:

```
Traditional voting:
  Proposal exists for 7 days
  Vote yes/no
  Whoever has majority at day 7 wins
  
Conviction voting:
  You stake tokens ON a proposal
  Conviction accumulates over time (like charging a battery)
  Proposal passes when conviction threshold is reached
  
  Conviction Formula:
    Conviction(t) = Stake × (1 - decay^t)
    
  Where decay (e.g., 0.9 per day) means:
    Day 1: 1000 tokens staked → 100 conviction
    Day 2: still staked → 190 conviction
    Day 5: still staked → 410 conviction
    Day 10: still staked → 651 conviction
```

**Why this defeats flash loan attacks:**

```
Flash loan: stake 10M tokens for 1 block
  Conviction = 10M × (1 - 0.9^(1/86400)) ≈ nearly 0
  
  You need to hold tokens over DAYS to build conviction
  Flash-borrowed tokens have zero conviction
  
Long-term holder: stake 100K tokens for 30 days
  Conviction = 100K × (1 - 0.9^30) ≈ 96,000
  
  Patient holders > wealthy short-term speculators
```

**Conviction voting solves voter apathy too:**

```
You don't need to show up on voting day
Your conviction accumulates automatically while you're sleeping
Governance runs continuously, not in episodic sprints

Used by: Gardens, 1Hive, Aragon

Tradeoff: Slower to respond to urgent situations
          Better for continuous resource allocation
```

---

### 4. Quadratic Voting

Makes it expensive to accumulate disproportionate voting power:

```
Linear voting (standard):
  1 token = 1 vote
  10,000 tokens = 10,000 votes
  
  Whale with 10,000 tokens
  vs 100 users with 100 tokens each
  Whale wins (10,000 vs 10,000... actually equal)
  
  But if 1 whale has 1,000,000 tokens:
  Whale = 1,000,000 votes
  100 users with 100 tokens = 10,000 votes
  Whale wins 100:1

Quadratic voting:
  Cost of N votes = N² tokens
  
  1 vote costs 1 token
  2 votes costs 4 tokens
  3 votes costs 9 tokens
  10 votes costs 100 tokens
  100 votes costs 10,000 tokens
  1000 votes costs 1,000,000 tokens
```

**The math of quadratic resistance:**

```
Whale (1,000,000 tokens):
  Can cast √1,000,000 = 1,000 votes
  
100 users (10,000 tokens each, 1,000,000 total):
  Each casts √10,000 = 100 votes
  Total: 100 × 100 = 10,000 votes
  
Community wins 10:1 over whale with same total tokens
Power redistributes to broad participation
```

**The Sybil attack problem:**

```
Quadratic voting assumes 1 person = 1 account

Attacker with 1,000,000 tokens:
  Linear:     1,000,000 votes (1 account)
  Quadratic:  1,000 votes (1 account)
  
  BUT with Sybil attack (split into 1000 accounts, 1000 tokens each):
  Quadratic:  1000 × √1000 = 31,622 votes
  
  31x more powerful than honest quadratic voting!
  
Mitigation needs identity verification:
  Proof of Humanity
  Worldcoin (biometric)
  Social graph (BrightID)
  
Without Sybil resistance: quadratic voting is broken
```

**Gitcoin Grants uses quadratic funding** (related mechanism):

```
Matching pool: $1M from sponsors

Project A received:
  1 donation of $1000 → matching = √1000 = $31.6
  
Project B received:
  100 donations of $10 each → matching = (100 × √10)² / normalization ≈ much more
  
Broad community support → more matching
Whale donations → less marginal impact
Community preferences → more accurately reflected
```

---

## Learning Path — Executed

### Step 1: Study Compound Governor & Snapshot

**Compound Governor Bravo — the canonical implementation:**

```solidity
// The full governance flow

contract GovernorBravo {
    
    uint public votingDelay = 13140;    // ~2 days
    uint public votingPeriod = 40320;   // ~7 days
    uint public proposalThreshold = 100_000e18;
    uint public quorumVotes = 400_000e18;
    
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
        uint eta;              // Timelock execution time
        address[] targets;     // Contracts to call
        uint[] values;         // ETH values
        string[] signatures;   // Function signatures
        bytes[] calldatas;     // Encoded arguments
        uint startBlock;
        uint endBlock;
        uint forVotes;
        uint againstVotes;
        uint abstainVotes;
        bool canceled;
        bool executed;
        mapping(address => Receipt) receipts;
    }
    
    struct Receipt {
        bool hasVoted;
        uint8 support;      // 0=against, 1=for, 2=abstain
        uint96 votes;
    }
    
    function propose(
        address[] memory targets,
        uint[] memory values,
        string[] memory signatures,
        bytes[] memory calldatas,
        string memory description
    ) external returns (uint) {
        // Check proposer has enough tokens (at current block)
        require(
            comp.getPriorVotes(msg.sender, block.number - 1) >= proposalThreshold,
            "Insufficient proposal threshold"
        );
        
        uint startBlock = block.number + votingDelay;
        uint endBlock = startBlock + votingPeriod;
        
        proposalCount++;
        Proposal storage newProposal = proposals[proposalCount];
        newProposal.id = proposalCount;
        newProposal.proposer = msg.sender;
        newProposal.targets = targets;
        newProposal.values = values;
        newProposal.signatures = signatures;
        newProposal.calldatas = calldatas;
        newProposal.startBlock = startBlock;
        newProposal.endBlock = endBlock;
        
        return newProposal.id;
    }
    
    function castVote(uint proposalId, uint8 support) external {
        require(state(proposalId) == ProposalState.Active, "Not active");
        
        Proposal storage proposal = proposals[proposalId];
        Receipt storage receipt = proposal.receipts[msg.sender];
        
        require(!receipt.hasVoted, "Already voted");
        
        // CRITICAL: Use votes at proposal START block (snapshot)
        // Not current balance → prevents flash loan attacks
        uint96 votes = comp.getPriorVotes(msg.sender, proposal.startBlock);
        
        if (support == 0) {
            proposal.againstVotes += votes;
        } else if (support == 1) {
            proposal.forVotes += votes;
        } else if (support == 2) {
            proposal.abstainVotes += votes;
        }
        
        receipt.hasVoted = true;
        receipt.support = support;
        receipt.votes = votes;
    }
    
    function queue(uint proposalId) external {
        require(state(proposalId) == ProposalState.Succeeded);
        
        Proposal storage proposal = proposals[proposalId];
        uint eta = block.timestamp + timelock.delay();
        
        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.queueTransaction(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                eta
            );
        }
        
        proposal.eta = eta;
    }
    
    function execute(uint proposalId) external payable {
        require(state(proposalId) == ProposalState.Queued);
        
        Proposal storage proposal = proposals[proposalId];
        proposal.executed = true;
        
        for (uint i = 0; i < proposal.targets.length; i++) {
            timelock.executeTransaction{value: proposal.values[i]}(
                proposal.targets[i],
                proposal.values[i],
                proposal.signatures[i],
                proposal.calldatas[i],
                proposal.eta
            );
        }
    }
}
```

**Snapshot — off-chain voting:**

```
Why Snapshot?
  On-chain voting costs gas
  Each vote = transaction = $5-50 in gas
  Poor people can't afford to participate
  Whales dominate even more

Snapshot solution:
  Signatures are free (no gas)
  Votes stored off-chain (IPFS)
  Counting is off-chain
  
  Tradeoff: Not trustless
  Snapshot could theoretically alter results
  Used for signaling, not binding execution
  
  Often used as:
    Temperature check (non-binding) → Snapshot
    Binding execution → On-chain Governor
    
  MakerDAO flow:
    Discussion (forum) → Signal poll (Snapshot) → 
    Governance poll (on-chain, non-executive) →
    Executive vote (on-chain, executes changes)
```

---

### Step 2: Implement a Governance System



#### [Governance Token ](./gov-system/GovToken.sol)
#### [Timelock](./gov-system/Timelock.sol)
#### [Governor](./gov-system/Governor.sol)

---

### Step 3: Simulate Attack Scenarios

```javascript
// Foundry tests — run these

// Attack 1: Low quorum exploit
function testLowQuorumAttack() public {
    // Mint 10M tokens to attacker
    govToken.mint(attacker, 10_000_000e18);
    // Total supply = 100M, quorum = 10M (only need attacker's votes)
    
    // Create malicious proposal: drain treasury
    address[] memory targets = new address[](1);
    targets[0] = address(treasury);
    bytes[] memory calldatas = new bytes[](1);
    calldatas[0] = abi.encodeWithSignature(
        "transfer(address,uint256)", 
        attacker, 
        treasury.balance()
    );
    
    vm.prank(attacker);
    uint propId = governor.propose(targets, new uint[](1), calldatas, "Legitimate upgrade");
    
    // Skip voting delay
    vm.roll(block.number + governor.votingDelay() + 1);
    
    // Only attacker votes — still meets quorum
    vm.prank(attacker);
    governor.castVote(propId, 1); // FOR
    
    // Skip voting period
    vm.roll(block.number + governor.votingPeriod() + 1);
    
    // Proposal succeeded with only attacker's votes
    assertEq(uint(governor.state(propId)), uint(ProposalState.Succeeded));
    
    // Fix: raise quorumThreshold to 40% of supply
}

// Attack 2: Flash loan governance (should FAIL with proper implementation)
function testFlashLoanGovernanceBlocked() public {
    // Fast-forward 1 block after proposal creation (snapshot taken)
    uint propId = _createProposal();
    
    // Attacker flash-borrows 50M tokens AFTER snapshot
    // Tries to vote with them
    vm.prank(attacker);
    // Should revert: getPriorVotes at snapshot block = 0
    vm.expectRevert();
    governor.castVote(propId, 1);
}

// Attack 3: Bribe attack simulation
function testBribeAttackEconomics() public {
    uint treasuryValue = 100_000_000e18; // $100M
    uint attackerTokens = 5_000_000e18;   // 5M tokens
    uint tokenPrice = 1e18;               // $1 per token
    
    uint attackCost = attackerTokens * tokenPrice / 1e18; // $5M
    
    // If proposal passes, attacker drains $100M
    // ROI = 20x even if tokens become worthless after
    
    // Mitigation: treasury actions require higher quorum (20%+)
    // and longer timelock (7 days) than parameter changes
    
    assertTrue(attackCost < treasuryValue); // Attack is profitable
}
```

---

### Step 4: Design a Novel Voting Mechanism

**Optimistic Governance — flip the default:**

```
Standard governance:
  Everything requires majority FOR to pass
  Status quo = nothing changes
  
Optimistic governance:
  Proposals pass AUTOMATICALLY after timelock
  UNLESS enough people vote AGAINST (veto threshold)
  
  Logic:
    Most proposals are legitimate
    Bad proposals will get vetoed
    Good proposals don't need mobilizing voters
    
  Implementation:
    Proposal created
    48-hour "veto window"
    If >10% of supply votes AGAINST → vetoed
    Otherwise → auto-executes
    
  Benefit: Reduces governance fatigue
  Risk: Sleepy community = malicious proposals slip through
```

**Delegated conviction + Optimistic hybrid:**

```
Design exercise:

"PermissionedDAO"

Layer 1: Delegated Experts
  Technical committee (5 people)
  Can execute parameter changes immediately
  Changes limited to ±20% of current values
  Can be removed by token holders anytime

Layer 2: Token Governance
  Major changes require token vote
  Uses conviction voting (builds over 7 days)
  Flash loan immune, whale resistant
  
Layer 3: Emergency Multi-sig
  3/5 can pause protocol
  Cannot execute changes, only pause
  
Layer 4: Full Community (nuclear option)
  Any token holder can trigger a "constitutional vote"
  Requires 30-day campaign period
  Can override any other layer
  
Rationale:
  Day-to-day: experts handle fast
  Normal decisions: conviction voting
  Emergencies: multi-sig pause
  Fundamental changes: full community
  
  Each layer handles what it's suited for
  No single point of control
```

---

## The Mental Model

```
Governance is a game theory problem, not just code:

Players:
  Token holders (voters)
  Delegates (representatives)
  Proposers (protocol contributors)
  Attackers (rational profit-seekers)
  Protocols (external protocols that hold tokens)

Each player is rational:
  Voter: maximize portfolio value
  Delegate: maximize reputation + compensation
  Attacker: maximize extracted value
  
The system is secure only if:
  Attack cost > Attack reward (always)
  Honest participation > Apathetic non-participation
  No single player can capture the system
  
When any of these fail, the system fails
Timelock, quorum, snapshot = tools that preserve these conditions
```

---

## Where Next

You've now covered Stablecoins, Derivatives, and Governance deeply. The roadmap suggests **Yield Aggregators** next — which ties directly to governance because vault strategies are often governance-controlled (Yearn's governance votes on strategy parameters, fee splits, and which strategies get capital). Governance is the "operating system" that Yield Aggregators run on.