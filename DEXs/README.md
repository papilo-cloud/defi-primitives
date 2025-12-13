# Decentralized Exchanges (DEXs) - Complete Deep Dive

From basic concepts to advanced mathematics, implementation, and real-world examples.

---

## 🎯 What are DEXs?

### Centralized Exchange (CEX) vs Decentralized Exchange (DEX)

**Centralized Exchange (Coinbase, Binance):**
```
User → Deposit to exchange → Order book matching → Withdraw
       ↑ You don't own these coins (custodial)
       ↑ Exchange can freeze your account
       ↑ Can be hacked (Mt. Gox, FTX)
```

**Decentralized Exchange (Uniswap, Curve):**
```
User → Swap directly from wallet → Smart contract executes → Done
       ↑ You always own your coins (non-custodial)
       ↑ No one can freeze your account
       ↑ No counterparty risk
```

### Types of DEXs

| Type | Example | Mechanism | Best For |
|------|---------|-----------|----------|
| **Constant Product AMM** | Uniswap V2 | x × y = k | General tokens |
| **Concentrated Liquidity** | Uniswap V3 | x × y = k (in ranges) | Capital efficiency |
| **Stableswap** | Curve | Hybrid curve | Stablecoins |
| **Order Book** | dYdX, Serum | Traditional matching | Advanced traders |
| **Aggregator** | 1inch, Matcha | Route optimization | Best prices |