# Oracles — Deep Dive

Oracles are the **nervous system of DeFi.** Every primitive you've studied depends on them: stablecoin liquidations need ETH price, perpetuals need mark price, options need volatility, governance needs proposal execution. Get the oracle wrong and the entire stack built on top of it collapses.

The oracle problem is fundamental: **blockchains are deterministic, isolated systems.** A smart contract cannot reach out and fetch a price. It can only read what's already on-chain. Oracles are the bridge — but every bridge is also an attack surface.

---

## The Oracle Problem, Precisely

```
Smart contract needs to know: "What is ETH worth right now?"

What it CAN do:
  Read on-chain state (balances, storage, block data)
  
What it CANNOT do:
  Make HTTP requests
  Read external APIs
  Access off-chain databases
  
The dilemma:
  If you trust one entity to report prices → centralized, attackable
  If you use on-chain prices (DEX) → manipulable with capital
  If you use nothing → can't build financial products
  
Every oracle design is a different answer to this dilemma
```

---

## Part 1: Chainlink — Decentralized Oracle Network

### Architecture Overview

Chainlink's answer: **many independent nodes, cryptographic aggregation, economic incentives for honesty.**

```
Off-chain world:
  Coinbase API  ──┐
  Binance API   ──┼── Node 1 (fetches, signs, reports)
  Kraken API    ──┘
  
  Coinbase API  ──┐
  Bitstamp API  ──┼── Node 2 (fetches, signs, reports)
  Gemini API    ──┘
  
  ... (21+ nodes per feed)
  
On-chain world:
  Aggregator contract collects reports
  Takes median of all reported values
  Stores result with timestamp
  
Consumer contract:
  Reads from aggregator → gets price
```

**Why median, not average?**

```
21 nodes report ETH price:
  19 nodes: $2000 (honest)
   1 node:  $1    (malfunctioning)
   1 node:  $9999 (corrupted)

Average: ($2000×19 + $1 + $9999) / 21 = $1905  ← distorted
Median:  $2000                                   ← correct

Median is manipulation-resistant:
  Attacker must corrupt MAJORITY of nodes to move median
  With 21 nodes: must control 11+ to shift result
  Economic cost of corrupting 11 independent operators = enormous
```

---

### Multiple Node Operators

**Who runs Chainlink nodes?**

```
Professional node operators:
  Figment, Chorus One, Deutsche Telekom T-Systems,
  Swisscom Blockchain, LinkPool, and 50+ others

Requirements to become an operator:
  Stake LINK tokens (slashed for misbehavior)
  Maintain high uptime (SLA enforcement)
  Pass reputation vetting
  Provide reliable data sources

Each operator is:
  Geographically distributed (different countries)
  Organizationally independent (no shared infrastructure)
  Economically incentivized (earn LINK fees for honest reports)
  Economically penalized (lose staked LINK for bad data)
```

**The collusion problem:**

```
Can nodes collude to report wrong prices?

Barriers:
  Legal risk (market manipulation is illegal in most jurisdictions)
  Reputation risk (public operators, identifiable)
  Economic risk (LINK stake slashed if caught)
  Coordination problem (who contacts 11 independent entities?)
  
Attack scenario:
  Corrupt 11/21 nodes to report ETH = $1
  Trigger mass liquidations in Aave ($500M+)
  Short ETH before the attack

  Why it hasn't happened:
    LINK staked per node: $1M+
    11 nodes × $1M = $11M at risk
    Coordination = federal criminal conspiracy
    Chainlink monitors for anomalous reporting
    Protocols have circuit breakers
```

---

### Consensus Mechanism — OCR (Off-Chain Reporting)

**The old way (too expensive):**

```
Version 1 (pre-OCR):
  Each node submits transaction on-chain
  21 nodes = 21 transactions per update
  Gas cost: 21 × ~$5 = $105 per price update
  Updates every 1 hour = $2,520/day per feed
  100 price feeds = $252,000/day in gas
  
  At scale: economically unviable
```

**OCR — the solution:**

```
Off-Chain Reporting Protocol:

Round 1: Query phase (off-chain)
  Leader node broadcasts "start new round"
  All 21 nodes fetch price from their sources
  Each node signs their observation
  
Round 2: Transmission phase (off-chain)
  Nodes exchange signed observations peer-to-peer
  Each node can verify what others observed
  
Round 3: Aggregation (off-chain)
  All nodes compute the same median locally
  Nodes sign "I agree the answer is $2000"
  
Round 4: On-chain submission (single transaction)
  ONE node submits aggregated report
  Report contains: median price + ALL 21 signatures
  On-chain contract verifies N-of-M signatures
  Stores result
  
Gas cost: 1 transaction instead of 21
Savings:  ~90% reduction in oracle gas costs
```

Simplified on-chain OCR verification
#### [OCR cryptography:](./OCRAggregator.sol)

---

### Update Frequency

Chainlink updates are triggered by **two conditions**, whichever comes first:

```
Deviation threshold:
  Price moves more than X% from last reported value
  ETH/USD feed: 0.5% deviation trigger
  
  Current price: $2000 (on-chain)
  Real price:    $2011 → No update (0.55% > 0.5%, actually triggers)
  Real price:    $2009 → No update (0.45% < 0.5%)
  Real price:    $2020 → Update! (1% > 0.5%)
  
Heartbeat:
  Maximum time between updates regardless of price movement
  ETH/USD: 3600 seconds (1 hour)
  
  If ETH moves sideways for 2 hours:
    Update fires at 1 hour mark even though price unchanged
    Proves oracle is alive and working
```

**The update cost model:**

```
Who pays for updates?

Protocol sponsors:
  dApps that need the feed pay Chainlink subscription
  Pay in LINK tokens
  
Node operators earn:
  Per-report fee (from subscription)
  + LINK block rewards (subsidized by Chainlink foundation)
  
Consumer protocols:
  Don't pay per-read (reading is free — just read storage)
  Pay subscription fee to keep feed alive
  
Low-volume feeds (obscure assets):
  Expensive to maintain (few subscribers share cost)
  May have slower update frequency
  Higher deviation threshold (1% or 2%)
  
High-volume feeds (ETH, BTC):
  Many subscribers share cost
  Fast updates (0.5% deviation)
  Multiple competing feeds
```

---

### Data Quality

**Where does the price actually come from?**

```
Node operator fetches from multiple sources:

Typical sources for ETH/USD:
  Coinbase Pro API    (highest volume CEX)
  Binance API         (highest volume globally)
  Kraken API          (regulated, high quality)
  Bitstamp API        (oldest exchange)
  Gemini API          (regulated)
  
Node-level aggregation:
  Each node takes median of its sources
  If Binance glitches ($1800), Coinbase ($2000), Kraken ($2001)
  Node reports: $2000 (median of its own sources)
  
Network-level aggregation:
  21 nodes each report their median
  On-chain contract takes median of 21 medians
  
Two layers of outlier removal = high quality
```

**Data quality failure modes:**

```
1. Exchange outage during high volatility
   Binance goes down during ETH crash
   6 nodes using Binance can't fetch prices
   Now only 15 nodes reporting
   → Still works if threshold met (e.g., 14/21)
   
2. Stale exchange data
   Exchange has network issues, shows price from 5 min ago
   Nodes fetch this stale price
   Multiple nodes affected → median becomes stale
   → Heartbeat catches this (forces update eventually)
   
3. Coordinated exchange manipulation
   Whale pumps ETH on Binance only
   Binance shows $2500, all others show $2000
   Node using Binance: median of sources = $2100 (outlier)
   21-node median: still $2000 (Binance node is outlier)
   → Manipulation at one exchange doesn't move oracle
```

---

### Reading Chainlink in Practice

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface AggregatorV3Interface {
    function latestRoundData() external view returns (
        uint80  roundId,        // Current round ID
        int256  answer,         // Price (scaled by decimals)
        uint256 startedAt,      // When round started
        uint256 updatedAt,      // When answer was updated
        uint80  answeredInRound // Round in which answer computed
    );
    function decimals() external view returns (uint8);
}

contract SafePriceConsumer {
    AggregatorV3Interface public priceFeed;
    
    // Maximum age of price data we'll accept
    uint256 public constant MAX_STALENESS = 3600; // 1 hour
    
    // Maximum price deviation we'll accept vs last price
    uint256 public constant MAX_DEVIATION = 1000; // 10% in basis points
    
    int256 private lastAcceptedPrice;
    
    constructor(address _priceFeed) {
        priceFeed = AggregatorV3Interface(_priceFeed);
    }
    
    function getSafePrice() external returns (int256) {
        (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        ) = priceFeed.latestRoundData();
        
        // Check 1: Price is positive
        require(price > 0, "Invalid price: zero or negative");
        
        // Check 2: Round is complete (answeredInRound = roundId)
        require(answeredInRound >= roundId, "Stale price: round incomplete");
        
        // Check 3: Price isn't too old (heartbeat check)
        require(
            block.timestamp - updatedAt <= MAX_STALENESS,
            "Stale price: too old"
        );
        
        // Check 4: Price hasn't moved too much from last reading
        // Catches oracle manipulation or extreme volatility
        if (lastAcceptedPrice != 0) {
            int256 deviation = ((price - lastAcceptedPrice) * 10000) 
                               / lastAcceptedPrice;
            if (deviation < 0) deviation = -deviation;
            require(uint256(deviation) <= MAX_DEVIATION, "Price deviation too high");
        }
        
        lastAcceptedPrice = price;
        return price;
    }
    
    function getEthPriceUSD() external view returns (uint256) {
        (, int256 price,, uint256 updatedAt,) = priceFeed.latestRoundData();
        
        require(price > 0, "Invalid price");
        require(block.timestamp - updatedAt <= MAX_STALENESS, "Stale");
        
        // ETH/USD feed has 8 decimals
        // price = 200000000000 means $2000.00000000
        return uint256(price) / 1e8;
    }
}
```

---

## Part 2: Uniswap V3 TWAP Oracle

### TWAP vs Spot Price

**Spot price** — the current instantaneous price in a pool:

```
Uniswap V3 pool at this exact moment:
  ETH reserve: 1000 ETH
  USDC reserve: 2,000,000 USDC
  
  Spot price = USDC/ETH = 2,000,000 / 1000 = $2000

After one large trade (1000 ETH sold into pool):
  ETH reserve: 2000 ETH
  USDC reserve: ~1,333,333 USDC
  
  Spot price = 1,333,333 / 2000 = $666.67
  
Spot price moved from $2000 → $667 in one trade
If a protocol uses spot price for liquidations → disaster
```

**TWAP (Time-Weighted Average Price)** — average over time:

```
Instead of current price, average ALL prices over a window:

Price history:
  Block 100: $2000
  Block 101: $1950 (sell pressure)
  Block 102: $1980 (recovery)
  Block 103: $667  (massive flash trade)
  Block 104: $2010 (back to normal)
  Block 105: $2000
  
30-minute TWAP:
  Average = ($2000 + $1950 + $1980 + $667 + $2010 + $2000) / 6
          ≈ $1768
  
  The flash trade ($667) barely moves the TWAP
  The attacker would need to sustain the manipulation for 
  most of the 30-minute window to meaningfully shift TWAP
```

**How Uniswap stores TWAP data:**

```solidity
// Inside Uniswap V3 pool — incredibly elegant design
struct Observation {
    uint32  blockTimestamp;   // When this was recorded
    int56   tickCumulative;   // Sum of all ticks up to this point
    uint160 secondsPerLiquidityCumulativeX128;
    bool    initialized;
}

// Uniswap stores a RING BUFFER of 65,535 observations
// Each block: price is accumulated into tickCumulative
// tickCumulative = Σ(tick × seconds_elapsed)

// To get TWAP between two time points:
// TWAP_tick = (tickCumulative_t2 - tickCumulative_t1) / (t2 - t1)
// TWAP_price = 1.0001 ^ TWAP_tick  (Uniswap's tick math)
```

[**Implementing a TWAP oracle:**](./TWAPOracle.sol)

### Manipulation Resistance — The Math

**How much does it cost to manipulate a TWAP?**

```
Setup:
  ETH/USDC pool: $100M liquidity
  30-minute TWAP window
  Attacker wants to move TWAP from $2000 → $1000 (50% down)
  Goal: trigger liquidations in a lending protocol
  
Cost calculation:
  
  To move spot price from $2000 → $1000:
    Using constant product: x × y = k
    Initial: 50,000 ETH × $100M USDC = k
    
    To halve price: sell enough ETH to double ETH reserves
    Must add ~50,000 ETH to pool (double ETH side)
    
    Cost: ~50,000 ETH at $2000 = $100M just to move spot
    
  But TWAP requires sustaining this for the full window:
  
    Spot is now $1000
    Every second the TWAP is below $2000 costs:
      Pool earns fees: 0.3% × volume of manipulation = $300K+
      Price impact on return: when buying back ETH, price is worse
      
    To move 30-minute TWAP to $1000:
      Need spot = $1000 for ALL 30 minutes
      Every arb bot globally is screaming to arb this $1000 ETH
      Must fight all arbitrageurs for 30 continuous minutes
      
    Realistic cost: $200-500M for a major pool
    
  Smaller pools are cheaper to attack:
    Pool with $1M liquidity → cost drops to $2-5M
    This is why TWAP oracles on illiquid pairs are dangerous
```

**TWAP window length vs manipulation cost:**

```
Shorter window (1 min):
  Cheaper to manipulate (hold 1 minute)
  More current price data
  Better for volatile assets
  
Longer window (1 hour):
  Much more expensive to manipulate
  Lags behind real price
  Could use stale prices in fast-moving markets
  
Rule of thumb:
  Low liquidity pair (<$10M): use 1-hour TWAP + Chainlink backup
  High liquidity pair (>$100M): 30-minute TWAP may suffice
  Critical protocol (billions at stake): Chainlink only, TWAP as backup
```

---

### Oracle Gas Cost

Reading an oracle has real costs:

```
Chainlink read:
  One SLOAD from AggregatorV3Interface
  Cost: ~2,100 gas (cold storage read) or ~100 gas (warm)
  At 20 gwei: ~$0.004 per price read
  Essentially free for the consumer
  
Chainlink write (update):
  One transaction with 21 signatures
  Cost: ~500,000 gas (OCR report)
  At 20 gwei, ETH = $2000: ~$20 per update
  Paid by Chainlink node operators (funded by subscriptions)
  
Uniswap TWAP read:
  observe() call: reads from observation ring buffer
  Cost: ~30,000 gas (two storage reads + arithmetic)
  At 20 gwei: ~$1.20 per price read
  10-30x more expensive than Chainlink read!
  
Why TWAP is expensive:
  Must query two historical observations
  Binary search through ring buffer
  Tick math computation
  
Optimization: cache TWAP in your own contract
  Read TWAP once per block, store it
  Subsequent reads within same block use your cache
  
  uint256 private cachedTWAP;
  uint256 private cacheBlock;
  
  function getCachedTWAP() internal returns (uint256) {
      if (block.number > cacheBlock) {
          cachedTWAP = twapOracle.getTWAP(1800);
          cacheBlock = block.number;
      }
      return cachedTWAP;
  }
```

---

### Update Frequency Trade-offs

```
                Chainlink          Uniswap TWAP
                ─────────────────────────────────
Update type:    Push (external)    Pull (on-demand)
Freshness:      0.5% deviation     Instant spot
Lag:            ~1-3 minutes       Window size (30min)
Manipulation:   Very hard          Hard (cost-based)
Cost to read:   ~$0.004            ~$1.20
Decentralized:  Mostly             Fully
Works for:      All assets         Only DEX-listed
```

**When to use which:**

```
Use Chainlink when:
  Asset isn't on Uniswap
  Need lowest possible gas for reads
  Need human-readable price with proper decimals
  Auditors expect it (industry standard)
  
Use Uniswap TWAP when:
  Want fully on-chain, trustless oracle
  Asset has deep Uniswap liquidity
  Need oracle for new token not yet on Chainlink
  Supplementing Chainlink with manipulation check
  
Use both (most secure):
  Primary: Chainlink
  Validation: TWAP
  If they diverge > 5% → revert transaction
  Catches Chainlink manipulation AND TWAP manipulation
```

---

## Oracle Attacks — Deep Dives

### Attack 1: Flash Loan Price Manipulation

The classic attack that prompted Uniswap to build TWAP:

```
Target: Protocol using Uniswap V2 SPOT price as oracle
        (no TWAP — this was the early design mistake)

Setup:
  ETH/USDC Uniswap pool: 1000 ETH / $2M USDC → price = $2000
  Lending protocol: uses this pool's spot price for ETH collateral
  
Attack (single transaction):

Step 1: Flash loan $100M USDC from Aave

Step 2: Buy massive ETH on Uniswap
  Dump $100M USDC into pool
  ETH price spikes to $20,000 (10x manipulation)
  
Step 3: Exploit the lending protocol
  ETH "worth" $20,000 per the oracle
  Deposit 10 ETH as collateral ($200,000 at real prices)
  Oracle says: 10 ETH = $200,000 → borrow $180,000 in stablecoins
  Protocol allows it: 90% LTV of $200,000 = $180,000
  
Step 4: Sell ETH back / restore pool
  Sell ETH back to pool (or just let flash loan unwind)
  ETH price returns to $2000
  
Step 5: Repay flash loan
  Repay $100M + 0.09% fee
  
Net result:
  Borrowed $180,000 against 10 ETH worth $20,000
  LTV is now 900% (massively undercollateralized)
  Just walk away → steal $160,000
  
Real examples:
  Cream Finance: $130M hack via oracle manipulation (2021)
  Harvest Finance: $34M hack (2020)
  bZx: $1M hack (2020) — the one that started the conversation
```

**Why TWAP completely solves this:**

```
Same attack with 30-minute TWAP:

Step 2: Spike spot price to $20,000
  TWAP is still ~$2000 (averaged over 30 minutes)
  Protocol reads TWAP → still sees $2000
  
Step 3: Borrow attempt
  TWAP says ETH = $2000
  10 ETH collateral = $20,000
  Can borrow $18,000 (90% LTV of $20,000)
  Not $180,000 — attack fails
  
Flash loan manipulation is single-block → TWAP is immune
```

---

### Attack 2: Multi-Block Manipulation

The sophisticated attack designed specifically to defeat TWAPs:

```
Goal: Manipulate 30-minute TWAP by controlling price for 30+ minutes

The attacker needs:
  Enough capital to hold manipulated price against all arbitrageurs
  Block proposer power (can order/censor transactions)
  
With Proof of Stake:
  Validators are known in advance (RANDAO)
  An attacker can predict they'll propose next 3 blocks
  
Attack over N consecutive blocks:
  
  Block 1 (attacker proposes):
    Dumps 10,000 ETH into pool (price crashes to $500)
    Censors all arbitrage transactions
    
  Block 2 (attacker proposes):
    Maintains position
    Still censors arbitrage
    
  Block 3 (attacker proposes):
    Closes position
    
  After 3 blocks:
    TWAP barely moved (3 blocks / 30-min window = 1%)
    Wasn't enough to trigger liquidations
    
The realistic multi-block attack:
  Needs to control >>50% of the 30-minute window
  = ~900 blocks
  Probability of proposing 900 consecutive blocks?
  Essentially zero (you'd need to own 100% of stake)
```

**The real multi-block threat — Sandwich around oracle updates:**

```
Some protocols refresh their oracle price at specific intervals
An attacker who can predict the update timing:

Block N-1: Manipulate Uniswap spot price down
Block N:   Oracle update reads manipulated price (if using spot)
           Liquidations triggered at wrong price
Block N+1: Restore price, profit from liquidations

Defense: Use TWAP (not spot) at oracle update time
         Use Chainlink (external data, can't be sandwiched on-chain)
```

---

### Attack 3: Sandwich Attack on Oracle Updates

More subtle — attacking the moment of price reading:

```
Chainlink updates at a specific transaction in a block
Miner/validator can order transactions within a block

Sandwich:
  Tx 1 (attacker): Open large position betting ETH falls
  Tx 2: Chainlink update (happens to report lower price)
  Tx 3 (attacker): Close position, profit
  
This isn't really "attacking the oracle"
It's exploiting oracle update timing (MEV)

Defense:
  Commit-reveal schemes (reveal position after oracle update)
  TWAPs (price can't be sandwiched — it's historical average)
  VWAP oracles (volume-weighted, harder to sandwich)
```

---

### Attack 4: Stale Data

The simplest and most common oracle failure:

```
Scenario 1: Network congestion
  Ethereum gas prices spike to 5000 gwei
  Chainlink update transaction stuck in mempool (underpaid gas)
  ETH crashes 40% in the real world
  Oracle still shows old (high) price
  Lending protocol doesn't trigger liquidations
  Protocol accrues bad debt
  
  Defense: Check updatedAt timestamp
    require(block.timestamp - updatedAt < 3600, "Stale price");

Scenario 2: Chainlink node outage
  Multiple nodes go offline simultaneously (infra issue)
  No quorum reached → no price update
  Price stays stale while market moves
  
  Defense: Cross-reference with TWAP
    If Chainlink and TWAP diverge >5% → use more conservative value

Scenario 3: Depeg attack
  DAI depegs to $0.90 in a black swan event
  Chainlink USDC/USD oracle: $1.00 (legitimate, USDC is fine)
  Protocol using DAI as "stablecoin" collateral treats it as $1
  User borrows against DAI collateral valued at $1 when it's $0.90
  
  Defense: Monitor depeg, circuit breaker if stablecoin depegs >5%
```

**Stale price in code:**

```solidity
// BAD — no staleness check
function getBadPrice() external view returns (int256) {
    (, int256 price,,,) = priceFeed.latestRoundData();
    return price;  // Could be hours old during an outage
}

// GOOD — full validation
function getValidatedPrice() external view returns (uint256) {
    (
        uint80 roundId,
        int256 price,
        ,
        uint256 updatedAt,
        uint80 answeredInRound
    ) = priceFeed.latestRoundData();
    
    require(price > 0,                              "Negative price");
    require(answeredInRound >= roundId,             "Round incomplete");
    require(block.timestamp - updatedAt < 3600,     "Stale: >1 hour old");
    require(uint256(price) < type(uint256).max / 2, "Price overflow risk");
    
    return uint256(price);
}
```

---

## Learning Path — Executed

### Step 1: Study Chainlink Architecture

**Key contracts to read on Etherscan:**

```
ETH/USD Price Feed: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419

Functions to trace:
  latestRoundData()     → your entry point
  latestAnswer()        → simplified (no round data)
  
EACAggregatorProxy     → the proxy users call
  ↓ delegates to
AccessControlledOffchainAggregator → the real logic
  stores: latestAnswer, latestTimestamp, transmitters[]
  
Read:
  s_transmitters mapping  → see active node operators
  s_hotVars              → packed configuration (threshold, etc.)
  latestConfigDetails()   → OCR configuration
```

**Decode a real Chainlink OCR transaction:**

```
Find a recent ETH/USD update on Etherscan:
  To: 0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419
  Function: transmit(bytes,bytes32[],bytes32[],bytes32)
  
Decode the calldata:
  First param (bytes): the encoded report
    → Contains: median price, timestamp, juels (LINK payment)
  rs[], ss[], rawVs: the 21 node signatures
  
You can verify each signature:
  ecrecover(keccak256(report), v, r, s) → node operator address
  Cross-reference with registered transmitters
  
This is how you know the data is real
```

---

### Step 2: Implement a TWAP Oracle

[**Full implementation with multiple windows:**](./MultiWindowTWAP.sol)

**Testing your TWAP on a fork:**

```bash
# Foundry: fork mainnet, test TWAP behavior

forge test --fork-url https://eth-mainnet.alchemyapi.io/v2/YOUR_KEY \
           --fork-block-number 18000000

# Then in your test:
function testTWAPManipulationResistance() public {
    // Get baseline TWAP
    int24 baselineTick = oracle.getTWAPTick(1800);
    
    // Simulate huge trade (price manipulation)
    // Buy 10,000 ETH worth of USDC in the pool
    vm.startPrank(richAddress);
    swapRouter.exactInputSingle(params);
    vm.stopPrank();
    
    // TWAP should barely move
    int24 afterTick = oracle.getTWAPTick(1800);
    int24 movement = afterTick - baselineTick;
    if (movement < 0) movement = -movement;
    
    // Movement should be tiny (< 1% = 100 ticks)
    assertLt(uint256(int256(movement)), 100, "TWAP manipulated too easily");
}
```

---

### Step 3: Attack Simulation (Testnet)

[**Flash loan oracle attack — build and run it:**](./AttackContract.sol)

**Run this on a local fork with a intentionally vulnerable protocol to see it work. Then add TWAP oracle — watch it fail.**

---

### Step 4: Implement Defenses

[**Circuit breaker system:**](./OracleDefenses.sol)
---

### Step 5: Compare Oracle Solutions

```
Oracle        Chainlink         Uniswap TWAP      Pyth              Band Protocol
─────────────────────────────────────────────────────────────────────────────────────
Type          Push (external)   Pull (on-chain)   Push (pull model) Push (external)
Data source   CEX APIs          DEX liquidity     CEX + market      CEX APIs
Freshness     0.5% deviation    30-min average    <400ms            ~10 min
Gas (read)    ~2,100            ~30,000           ~5,000            ~10,000
Manipulation  Very hard         Capital-based     Hard              Hard
Trust         Node operators    AMM math          Pythnet validators Band validators
Best for      Most assets       DEX-listed pairs  Low-latency apps  Cross-chain
Failure mode  Node cartel       Large capital     Validator cartel  Validator cartel
Audited       Yes               Yes (Uniswap)     Yes               Yes
```

**Pyth — the new challenger:**

```
Architecture:
  Publishers (Binance, Coinbase, Jump Trading) push prices to Pythnet
  Pythnet = purpose-built Solana chain for oracle data
  Data bridged to EVM chains via Wormhole
  
Pull model:
  Unlike Chainlink (always on-chain), Pyth is on-demand
  You submit a price update WITH your transaction
  Prove freshness via VAA (Verifiable Action Approval)
  
  // User calls your contract:
  bytes[] memory priceUpdateData = getPythPriceUpdate();  // from Pyth API
  pyth.updatePriceFeeds{value: fee}(priceUpdateData);     // push to chain
  uint256 price = pyth.getPrice(ETH_USD_PRICE_ID);        // now read it
  
Benefits:
  Price updated on-demand → always fresh when needed
  Lower on-chain cost (no continuous heartbeat)
  400ms latency vs Chainlink's minutes
  
Tradeoffs:
  Requires off-chain API call before on-chain tx
  More complex integration
  Newer, less battle-tested
  
Best for:
  Perpetual protocols (need low-latency funding rate)
  Options protocols (need fresh vol data)
  High-frequency use cases
```

---

## The Full Mental Model

```
Oracle Security Layers (defense in depth):

Layer 1: Data Source Quality
  Multiple independent CEX APIs per node
  Median across sources
  Remove single-exchange manipulation

Layer 2: Node Decentralization  
  21+ independent operators
  Threshold signatures
  Economic incentives (stake at risk)
  
Layer 3: On-chain Aggregation
  Median of all node reports
  Requires majority to manipulate
  Block timestamp validation
  
Layer 4: TWAP Cross-validation
  Historical average vs point price
  Detects flash manipulation
  Protocol-level check before critical operations
  
Layer 5: Staleness Checks
  updatedAt timestamp validation
  answeredInRound comparison
  Heartbeat monitoring
  
Layer 6: Circuit Breakers
  Per-block change limits
  Cross-feed divergence detection
  Emergency pause mechanisms
  
Layer 7: Protocol Design
  Time delays before large liquidations
  Partial liquidations (not all-or-nothing)
  Conservative collateral factors for volatile assets

Remove any layer → attack surface opens
The $1B+ protocols run all 7 layers simultaneously
```