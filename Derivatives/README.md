# Derivatives — Deep Dive

Derivatives are contracts whose value is **derived** from an underlying asset. In DeFi, that's usually ETH, BTC, or other tokens. You're not buying the asset — you're buying exposure to its price movement, with more control and capital efficiency than spot trading.

Two families: **Options** (right to buy/sell) and **Perpetuals** (leveraged futures with no expiry).

---

## Part 1: Options

### What an Option Actually Is

```
A call option gives you the RIGHT (not obligation)
to BUY an asset at a fixed price (strike) by a certain date (expiry)

A put option gives you the RIGHT (not obligation)
to SELL an asset at a fixed price by a certain date
```

**Concrete example:**

```
ETH = $2000 today
You buy a call option: strike = $2500, expiry = 30 days, cost = $100

Scenario A: ETH goes to $3000
  → You exercise: buy ETH at $2500, immediately worth $3000
  → Profit: $3000 - $2500 - $100 (premium) = $400

Scenario B: ETH stays at $2000
  → Option expires worthless
  → Loss: $100 (just the premium)

Scenario C: ETH drops to $1500
  → Don't exercise (why buy at $2500 when market is $1500?)
  → Loss: $100 (just the premium, not the full drop)
```

This is the key insight: **options give asymmetric payoff.** Capped downside (premium paid), uncapped upside. That's why they cost money.

---

## The Greeks — How Options Actually Move

Greeks measure **sensitivity** of an option's price to different variables. This is how traders think, not just "will ETH go up?"

---

### Delta (Δ) — Sensitivity to Price

```
Delta = how much the option price moves 
        for every $1 move in the underlying

Call options: Delta between 0 and 1
Put options:  Delta between -1 and 0
```

**Examples:**

```
ETH = $2000, Call option strike $2500 (far out of the money)
Delta = 0.10
→ If ETH moves $100, option moves $10

ETH = $2000, Call option strike $2000 (at the money)  
Delta = 0.50
→ If ETH moves $100, option moves $50

ETH = $2000, Call option strike $1500 (deep in the money)
Delta = 0.90
→ If ETH moves $100, option moves $90
```

**Intuition:** Delta is roughly the probability the option expires in the money. Deep ITM options behave almost like holding the asset (delta ≈ 1). Far OTM options barely move with price (delta ≈ 0).

**Delta hedging** — how protocols stay market neutral:

```solidity
// If you sold 10 ETH call options with delta = 0.4 each
// Your total delta exposure = 10 × 0.4 = 4 ETH short

// To hedge: buy 4 ETH spot
// Now your portfolio delta = 0
// You don't care which direction ETH moves (short term)

// But delta changes as price moves → must rebalance constantly
// This rebalancing cost is what option buyers actually pay for
```

---

### Gamma (Γ) — Rate of Change of Delta

```
Gamma = how fast delta changes 
        for every $1 move in the underlying
```

**Why it matters:**

```
ETH = $2000, ATM call, Delta = 0.50, Gamma = 0.03

ETH moves to $2100:
  New delta = 0.50 + (0.03 × 100) = 0.50 + 3.0... 
  
  Wait — gamma is per $1 move:
  New delta = 0.50 + (0.03 × 100) = 0.50 + 3.0?
  
  No: New delta ≈ 0.50 + 0.03 × 1 per dollar = 0.53 after $1 move
  After $100 move: delta ≈ 0.80 (approximately)
```

**Gamma is highest at-the-money and near expiry.** This is "gamma risk" — near expiry, small price moves cause massive delta changes, forcing constant rebalancing.

```
Options expiring in 1 hour, strike = current price:
  → Tiny price move can swing delta from 0.50 to 0.10 or 0.90
  → Protocols get "gamma squeezed"
  → Massive rebalancing costs
```

This is why options near expiry are dangerous to sell (as a market maker). Gamma works against you.

---

### Theta (Θ) — Time Decay

```
Theta = how much option value decays each day
        simply from time passing (everything else equal)

Theta is always negative for option buyers
Theta is always positive for option sellers
```

**The decay curve:**

```
Option with 30 days to expiry, worth $200
  Day 30 → Day 20: loses $20 (slow decay)
  Day 20 → Day 10: loses $40 (accelerating)
  Day 10 → Day  1: loses $100 (very fast)
  Day  1 → Day  0: loses $40 (last day, either worth something or zero)
```

Decay is **non-linear** — it accelerates near expiry. This is why option sellers love short-dated options (collect theta fast) and buyers prefer long-dated options (give price time to move).

**Yield strategies like Ribbon Finance exploit theta:**

```
Every week:
  1. Hold ETH
  2. Sell 1-week call options (collect theta)
  3. Options expire worthless most weeks
  4. Slowly accumulate premiums
  5. Occasionally get "called away" when ETH rallies hard
```

---

### Vega (ν) — Sensitivity to Volatility

```
Vega = how much option value changes 
       for every 1% change in implied volatility

Both calls and puts have positive vega
(more volatility = more chance of large move = options worth more)
```

**Example:**

```
ETH option, implied vol = 80%, option price = $200, vega = 2.5

Volatility spikes to 90% (news event, market panic):
  New price = $200 + (2.5 × 10) = $225

Volatility drops to 70% (calm market):
  New price = $200 - (2.5 × 10) = $175
```

**Vega is why options get expensive before major events** (Fed announcements, ETH upgrades, etc.) and cheap after. Even if price doesn't move, options lose value when volatility drops — this is called a "volatility crush."

```
Before ETH merge: implied vol = 120%, options expensive
After ETH merge (no drama): implied vol = 60%
Options lost 40% of value even though ETH price barely moved
Option buyers got crushed despite being "right" directionally
```

---

## Black-Scholes Pricing

Black-Scholes gives a theoretical fair price for an option given 5 inputs:

```
C = S·N(d1) - K·e^(-rT)·N(d2)

Where:
  C = call option price
  S = current price of underlying
  K = strike price  
  T = time to expiry (in years)
  r = risk-free rate
  σ = volatility (annualized)
  
  d1 = [ln(S/K) + (r + σ²/2)·T] / (σ·√T)
  d2 = d1 - σ·√T
  
  N() = cumulative normal distribution function
```

**Don't memorize the formula. Understand what it's saying:**

```
The option price = 
  (Expected value if it expires ITM) - (Cost of paying strike at expiry)
  
Both weighted by probability of landing in the money
```

**Black-Scholes assumptions and why they break in crypto:**

```
Assumes:                        Reality in crypto:
─────────────────────────────────────────────────
Constant volatility             Vol changes wildly
Log-normal returns              Fat tails, black swans
Continuous trading              Liquidation gaps
No transaction costs            Gas costs are real
Risk-free rate exists           DeFi rate is variable
```

This is why crypto options are priced with a **volatility smile** — OTM options command higher implied vol than ATM options because the market knows fat tails exist.

---

## Implied Volatility

Implied volatility (IV) is Black-Scholes **inverted.** Instead of inputting vol to get price, you input the market price and solve for vol.

```
Market is trading ETH call at $250
Plug into BS: what volatility makes price = $250?
Answer: σ = 95%

→ Implied volatility = 95%
→ The market is "implying" 95% annualized volatility
```

**IV tells you what the market expects, not what happened:**

```
Historical vol (realized): what ETH actually moved over past 30 days
Implied vol:               what market expects ETH to move next 30 days

If IV > HV → options are "expensive" (market fears big move)
If IV < HV → options are "cheap" (market complacent)

Options traders sell when IV > HV (collect overpriced premium)
Options traders buy when IV < HV (cheap insurance)
```

**The volatility smile/skew:**

```
Strike:     $1000   $1500   $2000   $2500   $3000
             (put)   (put)   (ATM)  (call)  (call)
IV:          110%     95%    80%     85%     92%

         ↑
    IV   |  *               *   *
         |     *         *
         |        *   *
         |___________________________→ Strike
         
Smile: both wings have higher IV than ATM
Skew:  put side often higher (crash protection is expensive)
```

In crypto, the left skew (puts) is usually steeper — downside crashes are feared more than upside runs.

---

## Option Strategies

### Covered Call (Yield Generation)

```
Position: Hold 1 ETH + Sell 1 call option (strike above current price)

ETH = $2000, sell $2500 call, collect $150 premium

Outcome A: ETH stays below $2500
  → Option expires worthless
  → Keep $150 premium
  → Still hold ETH
  → Yield: $150 / $2000 = 7.5% (in 30 days!)

Outcome B: ETH rises to $3000
  → Option exercised, forced to sell ETH at $2500
  → Miss out on $500 of upside
  → But keep $150 premium
  → Net: sold at $2650 effective price

Risk: ETH crashes to $1000
  → Option expires worthless (keep $150)
  → But ETH position lost $1000
  → Premium partially offsets: net loss $850
```

This is exactly what Ribbon Finance vaults automate.

---

### Protective Put (Insurance)

```
Position: Hold 1 ETH + Buy 1 put option (strike below current price)

ETH = $2000, buy $1700 put, pay $100 premium

Outcome A: ETH drops to $1000
  → Exercise put: sell ETH at $1700
  → Loss capped at: $2000 - $1700 + $100 = $400
  → Without put: lost $1000

Outcome B: ETH rises to $3000
  → Put expires worthless
  → Keep ETH gains: $1000 - $100 premium = $900 net
```

---

### Spread (Reduce Cost, Cap Upside)

```
Bull Call Spread:
  Buy  $2000 call (pay $300)
  Sell $2500 call (collect $150)
  Net cost: $150

Payoff:
  ETH < $2000: lose $150
  ETH = $2500: gain $350 ($500 spread - $150 cost)
  ETH > $2500: gain $350 (capped)

Why? You're paying for the $2000-$2500 range only
     Cheaper than outright call, but upside capped
```

---

### Butterfly (Bet on Pinned Price)

```
Bet that ETH stays near $2000 at expiry:

  Buy  1x $1800 call  (pay $400)
  Sell 2x $2000 call  (collect $500)
  Buy  1x $2200 call  (pay $200)
  Net cost: $100

Max profit: if ETH = exactly $2000 at expiry → $100 profit
Max loss:   $100 (if ETH far from $2000 either way)

Used when you think price will be stable
```

---

## Part 2: Perpetual Futures

Perpetuals let you trade with leverage, with no expiry date. They're the backbone of DeFi derivatives — dYdX, GMX, and others process billions daily.

### How Leverage Works

```
You have $1000 USDC
You open a 10x leveraged long on ETH at $2000

Effective position: $10,000 worth of ETH (5 ETH)
Your margin:        $1000

ETH rises to $2200 (+10%):
  Position value: $11,000
  Profit: $1000
  Return on margin: 100% ✅

ETH drops to $1900 (-5%):
  Position value: $9,500
  Loss: $500
  Return on margin: -50% ❌

ETH drops to $1800 (-10%):
  Position value: $9,000
  Loss: $1000 = your entire margin
  → Liquidation ❌💀
```

Leverage amplifies both directions symmetrically. 10x leverage means a 10% adverse move wipes you out.

---

### Funding Rates

Perpetuals have no expiry, so there's no natural force pulling their price toward spot. **Funding rates are the mechanism** that keeps perp price anchored to spot.

```
Every 8 hours (typically):

If perp price > spot price (longs dominating):
  → Longs PAY shorts
  → Makes long positions more expensive → reduces demand
  → Perp price drifts back toward spot

If perp price < spot price (shorts dominating):
  → Shorts PAY longs
  → Makes short positions more expensive → reduces demand
  → Perp price drifts back toward spot
```

**Calculating funding payment:**

```
Funding Rate = (Mark Price - Index Price) / Index Price × Constant

Example:
  Mark price (perp): $2100
  Index price (spot): $2000
  Funding rate: ($2100 - $2000) / $2000 = 0.05% per 8 hours

If you're long $10,000:
  Funding payment = $10,000 × 0.05% = $5 every 8 hours
  = $15/day, $450/month just to hold position
```

**Funding as a yield strategy:**

```
ETH perp funding rate = +0.1% per 8 hours (longs paying shorts)
= 0.3%/day = ~109% APY just from funding

Delta-neutral strategy:
  Buy $50,000 ETH spot
  Short $50,000 ETH perpetual
  
  → No price exposure (spot gain = perp loss, or vice versa)
  → Collect funding rate as pure yield
  → Risk: funding flips negative (pay instead of collect)
  → Risk: exchange getting hacked
```

This is one of the most common "market-neutral" DeFi strategies.

---

### Mark Price vs Index Price

```
Index Price = actual ETH spot price
             (median of major CEX prices: Coinbase, Binance, Kraken)
             
Mark Price  = fair value estimate of the perpetual contract
             = Index Price + EMA of funding basis
```

**Why two prices?**

```
Problem: If liquidations used last trade price (mark = market):
  Attacker could:
  1. Open large short position
  2. Manipulate perp price down with wash trades
  3. Trigger liquidations of longs
  4. Profit from cascading liquidations
  
Solution: Use mark price (oracle-based, manipulation resistant)
  Liquidations only trigger based on mark price
  Short-term perp manipulation doesn't cause liquidations
```

**Practical example:**

```
ETH Index (spot): $2000
ETH Perp (mark): $1980  (perp trading at discount)

Your long position liquidation price: $1800

During a flash crash on a single exchange:
  Perp market drops to $1850 momentarily
  But mark price stays at $1980 (based on multiple oracles)
  → Your position is NOT liquidated
  → Manipulation failed
```

---

### Liquidation Mechanics

```solidity
struct Position {
    uint size;          // Position size in USD
    uint collateral;    // Margin deposited
    uint entryPrice;    // ETH price when opened
    bool isLong;
    uint leverage;
}

function getLiquidationPrice(address trader) public view returns (uint) {
    Position memory pos = positions[trader];
    
    // Maintenance margin = 0.5% of position size (example)
    uint maintenanceMargin = pos.size * 50 / 10000;
    
    if (pos.isLong) {
        // Long liquidated when losses eat collateral down to maintenance margin
        // Loss = (entryPrice - currentPrice) / entryPrice × size
        // Liquidation when: collateral - loss = maintenanceMargin
        // Solving: currentPrice = entryPrice × (1 - (collateral - maintenanceMargin) / size)
        
        return pos.entryPrice * (pos.size - pos.collateral + maintenanceMargin) / pos.size;
    } else {
        // Short: inverse
        return pos.entryPrice * (pos.size + pos.collateral - maintenanceMargin) / pos.size;
    }
}

function liquidate(address trader) external {
    require(
        markPrice <= getLiquidationPrice(trader),
        "Position is healthy"
    );
    
    Position memory pos = positions[trader];
    
    // Liquidator gets small fee (incentive)
    uint liquidatorFee = pos.collateral * 5 / 1000; // 0.5%
    
    // Insurance fund gets remainder
    uint insuranceFund = pos.collateral - liquidatorFee;
    
    // Transfer fee to liquidator
    token.transfer(msg.sender, liquidatorFee);
    
    // Close position at mark price
    delete positions[trader];
}
```

**Liquidation cascade:**

```
ETH drops 15% quickly

Round 1: 10x leveraged longs liquidated
  → Forced selling of ETH → price drops more

Round 2: 8x leveraged longs now liquidated (cascade)
  → More selling → price drops more

Round 3: 5x leveraged longs now liquidated
  → More selling...

Insurance fund depleted → "auto-deleveraging" kicks in:
  → Winning shorts are force-closed to cover losses
  → Profitable traders get their positions closed involuntarily
  
This happened on BitMEX in 2020 multiple times
```

---

### The Virtual AMM (vAMM) Model

Used by Perpetual Protocol. The insight: **use AMM math to price trades, but don't need real liquidity.**

```
Regular AMM: x * y = k
  Real tokens on both sides
  Liquidity providers take risk

vAMM: x * y = k
  No real tokens — it's just math
  Virtual reserves set by protocol
  Actual settlement in USDC collateral pool
```

**How it works:**

```
Protocol sets virtual reserves:
  vETH = 1000, vUSDC = 2,000,000
  k = 2,000,000,000
  Implied price = 2,000,000 / 1000 = $2000/ETH ✅

Trader opens long $10,000 at 10x leverage:
  Trade size = $100,000
  
  New vUSDC = 2,000,000 + 100,000 = 2,100,000
  New vETH  = k / vUSDC = 2,000,000,000 / 2,100,000 = 952.38
  
  ETH received (virtual) = 1000 - 952.38 = 47.62 vETH
  New price = 2,100,000 / 952.38 = $2,205 (price impact!)

Trader closes position:
  Return 47.62 vETH to pool
  Receive vUSDC back
  Profit/loss settled from real USDC collateral pool
```

**The problem with vAMM:**

```
Price drifts from real ETH price over time
No arbitrageurs bring it back (no real tokens to arbitrage)
Protocol must manually reset virtual reserves periodically

→ Leads to "funding rate chaos" when vAMM price diverges widely
→ This is why Perpetual Protocol v2 moved to Uniswap V3 as its engine
```

---

### GMX Model (Real Liquidity, No AMM)

GMX took a different approach — **peer-to-pool** instead of vAMM.

```
GLP Pool: $500M of real assets (ETH, BTC, USDC, etc.)
Traders trade against this pool directly

Long ETH $100,000 at 10x:
  Deposit $10,000 USDC margin
  GLP pool is counterparty to $100,000 ETH exposure
  
  ETH rises 10%:
    Trader profit: $10,000 → taken from GLP pool
    
  ETH falls 10%:
    Trader loss: $10,000 → goes to GLP pool
    
GLP holders earn:
  70% of trading fees
  All trader losses
  
GLP holders lose:
  When traders profit massively
```

**The oracle dependence:**

```
GMX uses Chainlink + custom oracle for mark price
No AMM means no price impact on trades
→ Zero slippage on any trade size (up to open interest caps)

This created an exploit:
  If oracle updates lag real price by even seconds:
  1. See ETH moving up on Binance
  2. Front-run oracle update on GMX
  3. Open long before price update
  4. Close immediately after update
  5. Risk-free profit
  
  GMX patched this with price impact penalties
  and transaction speed limits
```

---

## Learning Path — Executed

### Step 1: Traditional Finance Foundation

Before DeFi derivatives, understand what you're replicating:

```
Traditional options:
  Listed on CBOE (stocks), CME (futures)
  American vs European (exercise anytime vs at expiry)
  Physical vs cash settlement
  
Traditional futures:
  Obligation to buy/sell at set price/date
  Margin requirements and daily mark-to-market
  Contango vs backwardation (futures > or < spot)
  Roll costs (closing expiring contract, opening new one)
```

Perpetuals solve the "roll cost" problem — no expiry means no rolling. Funding rates replaced the natural cost-of-carry that futures embed.

---

### Step 2: [Math Implementation](./black_scholes.py)

```python
# Full Greeks calculator — build and use this

# Exercise: plot how each greek changes as price moves
import numpy as np

prices = np.linspace(1000, 3000, 100)
deltas = [option_greeks(p, 2000, 30/365, 0.05, 0.80)['delta'] for p in prices]
gammas = [option_greeks(p, 2000, 30/365, 0.05, 0.80)['gamma'] for p in prices]

# Plot these. You'll visually understand what the greeks mean.
```

---

### Step 3: Study GMX, dYdX, Squeeth

**Architecture comparison:**

```
dYdX v3:
  Off-chain order book (StarkEx)
  On-chain settlement
  Best liquidity, CEX-like UX
  Decentralization trade-off: sequencer is centralized

dYdX v4:
  Cosmos chain
  Fully decentralized order book
  Each validator runs order matching
  
GMX:
  Peer-to-pool model
  GLP as counterparty
  Zero slippage (until open interest caps)
  Oracle-dependent

Squeeth (Opyn):
  Power perpetual: exposure to ETH²
  Not a futures contract — it's a new derivative
  Long squeeth: profit from volatility (like long gamma)
  Short squeeth: earn funding (like short gamma)
  
  Price of squeeth ≈ ETH² / normFactor
  If ETH doubles: squeeth 4x (squared exposure)
  If ETH halves: squeeth -75%
```

**Squeeth is worth understanding deeply** because it represents DeFi actually innovating beyond replicating TradFi:

```
Traditional options:
  Fixed strike, fixed expiry
  Value depends on where price lands relative to strike
  
Squeeth (power perpetual):
  No strike, no expiry
  Value = ETH² (always)
  Funding pays for this squared exposure continuously
  
  Useful for:
    Hedging impermanent loss (IL ≈ -0.5 × ETH²)
    Long volatility without picking a strike
    Creating option-like payoffs by combining with other primitives
```

---

### Step 4: [Build a Perpetual Protocol](./MiniPerp.sol)

**Test scenarios to run:**

```javascript
// Foundry test
function testLiquidationCascade() public {
    // Open 10 positions at 10x leverage
    // Drop mark price 10%
    // Assert all positions liquidatable
    // Liquidate them one by one
    // Check insurance fund accumulation
}

function testFundingRateConvergence() public {
    // Set mark price > index price
    // Open lots of longs
    // Fast-forward time
    // Check funding payments drain long PnL
    // Assert mark price incentive to short (peg mechanism works)
}
```

---

### Step 5: Paper Trade Options

Use **Deribit** (real CEX) or **Opyn/Lyra** (DeFi) in paper trading mode.

**Trading exercises to run:**

```
Week 1: Buy ATM call, hold to expiry
  → Feel theta decay in real time
  → Watch delta change as price moves

Week 2: Sell OTM call (covered, hold ETH)
  → Collect premium
  → See what happens if price runs through strike

Week 3: Buy put before a major event
  → Experience vega (vol crush if nothing happens)

Week 4: Delta hedge a long call
  → Recalculate delta daily
  → Buy/sell ETH to stay delta neutral
  → Track hedging costs vs option price paid
```

This is irreplaceable. Reading about theta is not the same as watching $50 evaporate from your option overnight while price barely moved.

---

### Step 6: [Model Covered Call Yield](./simulate_covered_call_vault.py)


**What you'll find:** covered calls outperform buy-and-hold in flat/bear markets, underperform in strong bull markets. The "capped upside" is real. This is why Ribbon vaults had $1B+ TVL — they provided consistent yield in non-bull markets.

---

## The Mental Model

```
Options = Insurance contracts
  Buyer:  pays premium, gets protection/leverage
  Seller: collects premium, takes risk
  Price:  function of time + volatility + distance from strike

Perpetuals = Leveraged spot with no expiry
  Funding rate = cost to hold (keeps price anchored)
  Mark price = manipulation-resistant liquidation reference
  Leverage = amplifier (works both ways, equally brutal)

The relationship:
  Options pricing requires volatility estimate
  Perpetuals create realized volatility
  Implied vol from options predicts perp funding rate moves
  They're two sides of the same market
```