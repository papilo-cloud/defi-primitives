# Stablecoins — Deep Dive

Stablecoins solve one fundamental problem: **crypto is volatile, but finance needs stability.** You can't take out a loan or pay a salary in an asset that swings 20% in a day.

---

## The 3 Models (and why each exists)

---

### 1. Fiat-Collateralized — USDC, USDT

**The idea:** A company holds $1 in a bank for every token in circulation.

```
You send $1000 USD → Company mints 1000 USDC → You hold 1000 USDC
You burn 1000 USDC → Company sends $1000 USD back
```

**Why it works:** The peg is trivially maintained — it's just an IOU.

**The catch:** You're trusting a company (Circle, Tether). If they get frozen by regulators, hacked, or lie about reserves, your "stable" coin isn't stable at all. USDT has had persistent questions about whether it's truly 1:1 backed.

**Real risk example:** In March 2023, USDC briefly depegged to ~$0.87 when Silicon Valley Bank (where Circle held reserves) collapsed. The peg was purely trust-based — it snapped back once Circle confirmed funds were safe.

---

### 2. Crypto-Collateralized — DAI (MakerDAO)

**The idea:** Lock up more crypto than you borrow, so even if the collateral drops, the debt is still covered.

```
ETH price = $2000
You lock $3000 worth of ETH (1.5 ETH)
You can mint up to $2000 DAI (150% collateral ratio)
```

**Why overcollateralize?** Because ETH can drop 30% overnight. The excess buffer absorbs the volatility.

```solidity
// Simplified vault logic
struct Vault {
    uint collateral;  // ETH locked
    uint debt;        // DAI minted
}

// Health check
function isLiquidatable(address user) public view returns (bool) {
    uint collateralValue = vault.collateral * ethPrice;
    uint requiredValue = vault.debt * 150 / 100; // 150% ratio
    return collateralValue < requiredValue;
}
```

**What happens if ETH crashes?**

```
ETH drops from $2000 → $1200
Your 1.5 ETH is now worth $1800
Your debt is $2000 DAI — ratio is now 90% ❌
→ Liquidation triggered
→ A liquidator repays your $2000 DAI
→ They receive your $1800 ETH + a bonus (e.g. 5%)
→ You lose your collateral
```

**Stability mechanisms:**
- **Stability Fee** — interest rate on DAI debt. If DAI > $1, lower fee → more minting → supply up → price down
- **DAI Savings Rate (DSR)** — if DAI < $1, raise DSR → people lock DAI → supply down → price up
- Governance votes to adjust these levers

**Real risk:** In March 2020 ("Black Thursday"), ETH crashed 50% in hours. Liquidation auctions broke, and some vaults were liquidated for $0. MakerDAO had to mint and sell MKR tokens to cover the bad debt.

---

### 3. Algorithmic — The Graveyard and the Survivors

**The idea:** No real collateral. The peg is maintained by code and incentives.

#### ❌ UST (Terra) — The $40 Billion Collapse

```
UST peg mechanism:
Mint 1 UST → Burn $1 worth of LUNA
Burn 1 UST → Mint $1 worth of LUNA
```

This works while people believe it works. The moment confidence cracks:

```
UST depegs slightly → People panic sell UST
→ Mint massive LUNA to absorb → LUNA supply explodes
→ LUNA price crashes → $1 of LUNA is now worth $0.50
→ UST is now backed by nothing → full depeg
→ Death spiral
```

In May 2022, $40 billion was wiped out in ~72 hours. Purely algorithmic stablecoins with no real backing are now widely considered fundamentally broken.

---

#### ✅ FRAX — The Hybrid That Works

FRAX uses a smarter approach: **partially collateralized, partially algorithmic**, with a dynamic ratio.

```
Collateral Ratio (CR) starts at 100%

If FRAX > $1 (high demand):
  → Lower CR (less collateral needed)
  → More algorithmic
  
If FRAX < $1 (low confidence):
  → Raise CR (more collateral required)
  → More backed
```

**Minting FRAX at 85% CR:**
```
To mint 1 FRAX:
  → Provide $0.85 USDC (collateral)
  → Burn $0.15 worth of FXS (protocol token)
```

**Redeeming FRAX at 85% CR:**
```
Burn 1 FRAX:
  → Receive $0.85 USDC
  → Receive $0.15 worth of FXS (minted)
```

The key insight: the collateral ratio **responds to market confidence**. It's not fixed. This makes it far more resilient than pure algorithmic designs.

---

## Comparing All Three Side by Side

| | Fiat-Backed | Crypto-Backed | Algorithmic |
|---|---|---|---|
| **Peg strength** | Very strong | Strong | Fragile |
| **Decentralized?** | ❌ No | ✅ Yes | ✅ Yes |
| **Capital efficient?** | ✅ Yes (1:1) | ❌ No (150%+) | ✅ Yes |
| **Censorship resistant?** | ❌ No | ✅ Yes | ✅ Yes |
| **Collapse risk** | Regulatory/bank | ETH crash | Death spiral |
| **Example** | USDC, USDT | DAI | UST (dead), FRAX |

The **impossible triangle**: you can get 2 of these 3 — stable, decentralized, capital-efficient. Never all three. Every stablecoin is a different tradeoff.

---

## The Death Spiral — How to Model It

This is critical to understand deeply. Any stablecoin that relies on a volatile asset to maintain its peg has death spiral risk:

```
1. External shock → stablecoin loses peg slightly
2. Rational actors sell stablecoin (why hold a broken peg?)
3. Protocol mints more of the volatile token to buy back
4. Volatile token supply floods market → price drops
5. Now backing is worth even less → peg breaks further
6. Go to step 2, repeat until zero
```

**Defense mechanisms against this:**
- Overcollateralization (DAI's buffer)
- Collateral ratio that can rise (FRAX)
- Circuit breakers (pause minting)
- Diversified collateral (not just one asset)

---

## What to Build to Truly Understand This

Following the roadmap's advice — **build it yourself:**

```solidity
// Your goal: build a simplified DAI
contract MiniDAI {
    // 1. Accept ETH as collateral
    // 2. Mint stablecoin at 150% ratio
    // 3. Track health factor per vault
    // 4. Allow liquidations when undercollateralized
    // 5. Add a stability fee (simple interest)
}
```

Build this, deploy on a testnet, then **manually crash the ETH price** in your test environment and watch liquidations fire. You'll understand the mechanics more deeply than any amount of reading.

---

## Key Things to Remember

- Fiat-backed = **trust a company**
- Crypto-backed = **trust the math + overcollateralize**
- Algorithmic = **trust the incentives** (very risky)
- The peg is only as strong as what enforces it
- Every stablecoin that has collapsed did so because its **backing became circular** — the thing backing it depended on the stablecoin's own price

---

# Stablecoins — Deep Understanding & Learning Path

Let's go through every bullet, one by one, properly.

---

## Deep Understanding

### 1. Over-Collateralization Necessity

The core question: **why lock $150 to borrow $100?** It seems wasteful. Here's why it's non-negotiable.

**The volatility buffer problem:**

```
ETH price = $2000
You mint 1000 DAI, lock 0.75 ETH ($1500) → 150% ratio

ETH drops 20% overnight → your ETH = $1200
Ratio is now 120% → dangerously close to undercollateralized

ETH drops 35% → your ETH = $975
Now $975 backs $1000 DAI → system is insolvent ❌
```

The 150% ratio isn't arbitrary. It's calculated from **historical volatility**. ETH rarely drops 50%+ in under the liquidation window. The buffer buys time for liquidators to act.

**What happens if collateral ratio is too low?**

```
90% collateral ratio (like UST tried):
ETH drops 10% → entire system is immediately insolvent
No time to liquidate → bad debt socialised across all holders
```

**The capital inefficiency tradeoff is intentional.** You're paying for the right to hold a decentralized stablecoin. USDC doesn't need overcollateralization because a bank holds the real dollar — someone always bears the cost, it's just hidden.

---

### 2. Stability Fee (Interest Rate)

The stability fee is MakerDAO's **monetary policy lever** — equivalent to a central bank raising/lowering interest rates.

```
Stability Fee = annual interest on DAI debt
Paid in MKR (burned) when you close your vault
```

**How it controls the peg:**

```
DAI trading at $1.05 (above peg):
→ Too little DAI supply
→ Lower stability fee → cheaper to borrow DAI
→ More vaults open → more DAI minted
→ Supply increases → price returns to $1

DAI trading at $0.95 (below peg):
→ Too much DAI supply
→ Raise stability fee → expensive to hold debt
→ Vault owners repay loans → DAI burned
→ Supply decreases → price returns to $1
```

**The math — simple interest accrual:**

```solidity
// Debt grows every second
function currentDebt(address user) public view returns (uint) {
    uint principal = vaults[user].debt;
    uint timeElapsed = block.timestamp - vaults[user].lastUpdated;
    
    // Annualized rate converted to per-second
    // e.g. 5% APY → ~0.0000001547% per second
    uint rate = stabilityFee; // e.g. 1.05e27 (5% in ray units)
    
    return principal * (rate ** timeElapsed);
}
```

**Real example from MakerDAO history:**
- 2019: DAI was persistently below $1, stability fee was raised to **20.5% APY** to reduce supply
- It worked — the peg restored within weeks
- This is governance in action (more on that below)

---

### 3. Liquidation Auctions

This is where the system gets interesting. When a vault becomes undercollateralized, it can't just instantly sell collateral — that would be exploitable. Instead, MakerDAO uses **auctions**.

**MakerDAO's Liquidation 2.0 (Dutch Auction):**

```
Vault becomes undercollateralized
→ Collateral is seized and put to auction
→ Price starts HIGH and falls over time
→ First liquidator to accept the price wins
→ They pay DAI, receive ETH collateral
→ Vault owner gets any leftover collateral back
```

#### [Simplified Dutch auction](./Auction.sol)

**The liquidation incentive:**

```
Vault has: 1 ETH ($1800) backing 1000 DAI
Liquidation penalty: 13%

Liquidator pays: 1000 DAI
Liquidator receives: 1 ETH worth $1800
Liquidator profit: $800 (minus gas)
Vault owner gets back: $0 (wiped out)
```

The 13% penalty exists to make liquidation **profitable enough** that someone always does it quickly. If liquidators had no incentive, nobody would bother — and the system would accumulate bad debt.

**The Black Thursday failure (March 2020):**

```
ETH dropped 50% in hours
Gas prices spiked → liquidators couldn't submit transactions
Some auction bids went through at 0 DAI
→ Liquidators got free ETH
→ MakerDAO had $4M in bad debt
→ Emergency MKR mint + auction to cover losses
```

This is why auction design matters deeply. A badly designed liquidation system can be gamed.

---

### 4. Governance (Adjusting Parameters)

MakerDAO is governed by **MKR token holders**. They vote on every risk parameter in the system.

**What governance controls:**

```
Per-collateral parameters:
├── Debt Ceiling       → max DAI mintable against this asset
├── Liquidation Ratio  → e.g. 150% for ETH, 175% for smaller tokens
├── Stability Fee      → interest rate per collateral type
├── Liquidation Penalty → e.g. 13%
└── Auction Parameters → duration, starting price

System-wide parameters:
├── DAI Savings Rate (DSR)
├── Global Debt Ceiling
└── Emergency Shutdown trigger
```

**The governance process:**

```
1. Forum post (discussion, temperature check)
2. On-chain signal poll (non-binding)
3. Governance poll (binding direction vote)
4. Executive vote (actual parameter change)
5. 48-hour timelock before execution
```

The timelock is critical — it gives the community time to react to malicious proposals before they execute.

**Governance attack example:**

```
Attacker buys enough MKR tokens
→ Proposes: "raise debt ceiling on attacker's shitcoin to $1B"
→ If passed: mint $1B DAI against worthless collateral
→ Attacker walks away with $1B DAI
→ System is insolvent
```

This is why:
- MKR is expensive (attack cost = market cap of MKR)
- Timelock exists (community can react)
- Delegates exist (spread voting power)

---

### 5. Peg Stability Mechanisms

Multiple layers work together. No single mechanism is enough.

```
Layer 1: Arbitrage (market forces)
  DAI = $1.02 → Mint DAI (lock ETH), sell for $1.02 → profit
  DAI = $0.98 → Buy DAI cheap, repay vault, unlock ETH → profit
  Rational actors do this automatically → peg tightens

Layer 2: Stability Fee (supply control)
  Raise fee → less minting → supply down → price up
  Lower fee → more minting → supply up → price down

Layer 3: DAI Savings Rate (demand control)
  Raise DSR → lock DAI for yield → demand up → price up
  Lower DSR → unlock DAI → demand down → price down

Layer 4: PSM — Peg Stability Module (direct arbitrage)
  Swap USDC for DAI at exactly $1.00 (no slippage)
  This hard-caps deviation at ~$0.001
```

The PSM is the strongest mechanism — it essentially pegs DAI to USDC directly. But it introduced a tradeoff: DAI became ~60% backed by USDC, undermining its decentralization claims.

---

## Learning Path — Executed

### Step 1: History — Stablecoin Failures

**Iron Finance (June 2021) — The first large-scale death spiral:**

```
IRON = partially collateralized (75% USDC + 25% TITAN)
TITAN = protocol's own volatile token

TITAN price starts dropping
→ Arbitrageurs redeem IRON for USDC + TITAN
→ More TITAN minted → TITAN price drops further
→ More redemptions → more TITAN minted
→ TITAN goes from $60 → $0 in hours
→ IRON depegs: $0.75 (only USDC portion had value)
```

Mark Cuban was publicly invested. He called it a "bankrun." It was a textbook death spiral.

**Basis Cash, Empty Set Dollar, Ampleforth** — all tried pure algorithmic approaches, all failed or became irrelevant. The pattern is identical every time.

**UST — The biggest failure:**

```
Anchor Protocol offered 20% APY on UST deposits
→ Artificially created demand for UST
→ When Anchor's reserves ran dry, demand collapsed
→ Death spiral triggered (as described earlier)
→ $40B wiped in 72 hours
→ Do Kwon's "1 billion dollar defense fund" exhausted in 2 days
```

The lesson across all failures: **if the thing backing your stablecoin depends on your stablecoin's own confidence, you have circular logic, not backing.**

---

### Step 2: [Build a DAI-Like System](./MiniDAI.sol)

**Deploy this on Foundry/Anvil. Then:**
```bash
# Test a liquidation scenario
# 1. Open vault at 150%
# 2. Drop ETH price via setEthPrice()
# 3. Call liquidate() as another address
# 4. Watch the math work
```

---

### Step 3: Economics — Stability Mechanisms

The key economic insight is **reflexivity.** George Soros coined this for traditional markets — it applies perfectly to stablecoins.

```
Confidence → Demand → Peg holds → More confidence (virtuous cycle)
Fear → Selling → Peg breaks → More fear (death spiral)
```

Every stability mechanism is really just **breaking the reflexivity loop:**

```
Overcollateralization   → absorbs shocks before feedback loop starts
Arbitrage incentives    → mechanical actors restore peg without emotion
Stability fee           → reduces supply before speculation takes hold
PSM                     → hard ceiling on deviation, kills the feedback
```

The **weakest** mechanism: relying on future buyers to maintain confidence. (UST's Anchor yield was just bribing people to believe.)

The **strongest** mechanism: having real assets that can be sold at any price to cover the debt. (USDC has this — that's why it always recovers.)

---

### Step 4: Simulate Death Spirals

Model this in Python or even a spreadsheet:

```python
# Death spiral simulation

eth_price = 2000
collateral_ratio = 1.5
total_collateral_eth = 1000      # ETH in vaults
total_dai_minted = 1_000_000    # DAI outstanding
confidence = 1.0                 # 1.0 = full confidence

def simulate(days=30, shock=-0.3):
    global eth_price, confidence, total_dai_minted
    
    for day in range(days):
        
        # External shock on day 1
        if day == 1:
            eth_price *= (1 + shock)
        
        collateral_value = total_collateral_eth * eth_price
        backing_ratio = collateral_value / total_dai_minted
        
        # If backing < 120%, confidence drops
        if backing_ratio < 1.2:
            confidence -= 0.15
        
        # If confidence low, people redeem (reduces supply but also collateral)
        if confidence < 0.7:
            redemptions = total_dai_minted * 0.2
            total_dai_minted -= redemptions
            total_collateral_eth -= (redemptions / eth_price)
        
        print(f"Day {day}: ETH=${eth_price:.0f}, "
              f"Backing={backing_ratio:.2f}, "
              f"Confidence={confidence:.2f}, "
              f"DAI={total_dai_minted:,.0f}")
        
        if confidence <= 0:
            print("💀 System collapsed")
            break

simulate(shock=-0.4)  # 40% ETH crash
```

Run this with different shock values. You'll see exactly where the tipping point is for your collateral ratio. This is how risk teams at MakerDAO model parameters.

---

### Step 5: Design Your Own Stablecoin (On Paper)

Apply everything above. Work through these questions:

```
1. BACKING
   - What backs your coin? (ETH, BTC, RWA, nothing?)
   - How do you handle backing asset volatility?
   - What's your collateral ratio and why?

2. MINTING/BURNING
   - Who can mint? Under what conditions?
   - What's the redemption mechanism?
   - Is there a fee? Where does it go?

3. PEG MECHANICS
   - What brings the price back to $1 from above?
   - What brings it back from below?
   - What's the worst-case scenario?

4. GOVERNANCE
   - Who controls parameters?
   - How do you prevent governance attacks?
   - What can't governance touch? (immutable core)

5. FAILURE MODES
   - What's your death spiral scenario?
   - What circuit breakers exist?
   - What happens in a black swan event?
```

**A sample design exercise:**

```
"RealDAI" — backed by tokenized T-bills + ETH

Collateral: 80% USDC/T-bills + 20% ETH
Ratio: 110% (T-bills are stable, less buffer needed)
Minting: Anyone via vault or PSM
Stability Fee: Tracks T-bill yield (pass yield to DSR)
Circuit breaker: Pause minting if ETH drops >30% in 1 hour

Death spiral resistance: T-bill portion never depegs,
so 80% of backing is always solid regardless of ETH price.
```

---

## The Mental Model to Keep

Think of a stablecoin as a **three-legged stool:**

```
Leg 1: Real backing    (what's actually behind it)
Leg 2: Incentives      (why rational actors maintain the peg)
Leg 3: Governance      (who adjusts when things break)

Remove any one leg → the stool falls.

UST:  Leg 1 was circular (LUNA backed UST, UST gave LUNA value)
USDC: Leg 2 and 3 are centralized (but Leg 1 is rock solid)
DAI:  All three exist, but Leg 2 requires ETH to not crash too fast
```