# ERC-7540: Asynchronous ERC-4626 Tokenized Vaults - Complete Guide

## 📚 Table of Contents
1. [What is ERC-7540?](#what-is-erc-7540)
2. [The Problem It Solves](#the-problem-it-solves)
3. [Key Concepts](#key-concepts)
4. [Request Lifecycle](#request-lifecycle)
5. [Code Examples](#code-examples)
6. [Real-World Use Cases](#real-world-use-cases)
7. [Comparison: ERC-4626 vs ERC-7540](#comparison-erc-4626-vs-erc-7540)
8. [Relevance to Flying Tulip](#relevance-to-flying-tulip)

---

## What is ERC-7540?

**ERC-7540** extends ERC-4626 (the standard tokenized vault) by adding support for **asynchronous deposit and redemption flows**. 

### Quick Summary
- **Extends**: ERC-4626
- **Purpose**: Handle delays in deposits/withdrawals
- **Key Feature**: Request-based "pull" system instead of instant "push"
- **Status**: Draft (October 2023)
- **Use Cases**: RWAs, liquid staking, cross-chain vaults, regulated assets

---

## The Problem It Solves

### ERC-4626 Limitation: Synchronous Only

**ERC-4626** assumes **atomic** operations:
```solidity
// User calls deposit
vault.deposit(1000 USDC, user);

// Instantly:
// 1. USDC transferred from user to vault ✓
// 2. Shares minted to user ✓
// 3. Transaction complete ✓
```

**This breaks down when:**
- ❌ Underlying assets settle on T+1, T+2 cycles (bonds, real estate)
- ❌ Vault needs off-chain approval (KYC/AML checks)
- ❌ Liquidity is constrained (can't fulfill all redemptions instantly)
- ❌ Cross-chain operations require finality
- ❌ NAV (Net Asset Value) updates happen periodically, not per-block

### Example: Real Estate Vault Failure

```solidity
// ERC-4626 Real Estate Vault
RealEstateVault vault;

// User wants to deposit $1M
vault.deposit(1_000_000 USDC, alice);

// ❌ REVERTS because:
// - Property appraisal takes 2 weeks
// - Legal custody transfer takes 1 month
// - Can't mint shares instantly without knowing final valuation
```

**ERC-7540 Solution**: Separate the request from fulfillment:

```solidity
// Step 1: Alice requests deposit (instant)
vault.requestDeposit(1_000_000 USDC, alice);
// Assets locked, request is "Pending"

// Step 2: Wait for off-chain process (2 weeks)
// - Property appraised
// - NAV calculated
// - Legal docs signed

// Step 3: Alice claims when ready (she pulls, not vault pushes)
vault.deposit(1_000_000, alice);
// Now shares are minted based on finalized NAV
```

---

## Key Concepts

### 1. Request States

Every request goes through three states:

```
PENDING → CLAIMABLE → CLAIMED
```

| State | Description | User Action |
|-------|-------------|-------------|
| **Pending** | Request submitted, assets locked, awaiting processing | Wait |
| **Claimable** | Request fulfilled, ready to claim | Call `deposit()` or `redeem()` |
| **Claimed** | User received shares/assets | Done |

### 2. Request Types

ERC-7540 supports two async flows:

#### A. Asynchronous Deposit
```solidity
// User wants to deposit assets → get shares

// Step 1: Request
requestDeposit(uint256 assets, address controller) 
// Assets transferred to vault, request marked Pending

// Step 2: Claim (when Claimable)
deposit(uint256 assets, address receiver)
// Shares minted, request marked Claimed
```

#### B. Asynchronous Redemption
```solidity
// User wants to redeem shares → get assets

// Step 1: Request
requestRedeem(uint256 shares, address controller)
// Shares transferred to vault, request marked Pending

// Step 2: Claim (when Claimable)
redeem(uint256 shares, address receiver, address controller)
// Assets transferred out, request marked Claimed
```

### 3. Pull-Based Claims

**Critical Design**: Users MUST pull their funds, vaults MUST NOT push.

```solidity
// ❌ BAD: Vault pushes (not allowed in ERC-7540)
function fulfillRequest(address user) external {
    vault.transfer(user, shares); // Push
}

// ✅ GOOD: User pulls (required by ERC-7540)
function claimRequest() external {
    vault.deposit(amount, msg.sender); // Pull
}
```

**Rationale**: 
- Prevents griefing (malicious contracts can't DOS by reverting on receive)
- Gives users control over gas and timing
- Safer for compliance (user explicitly claims)

---

## Request Lifecycle

### Detailed Flow: Asynchronous Deposit

```
┌─────────────┐
│  User Alice │
└──────┬──────┘
       │
       │ 1. requestDeposit(1000 USDC, alice)
       ▼
┌─────────────────────────────────────┐
│  Vault (Pending State)              │
│  - Transferred: 1000 USDC from Alice│
│  - pendingDepositRequest[alice] += 1000│
│  - Shares NOT minted yet            │
└──────┬──────────────────────────────┘
       │
       │ 2. Off-chain processing
       │    - KYC check ✓
       │    - NAV calculated: $1.05 per share
       │    - Operator marks request as Claimable
       ▼
┌─────────────────────────────────────┐
│  Vault (Claimable State)            │
│  - pendingDepositRequest[alice] = 0 │
│  - claimableDepositRequest[alice] = 952 shares│
│    (1000 USDC / $1.05 = 952 shares) │
└──────┬──────────────────────────────┘
       │
       │ 3. Alice calls deposit(1000, alice)
       ▼
┌─────────────────────────────────────┐
│  Vault (Claimed State)              │
│  - Minted: 952 shares to Alice      │
│  - claimableDepositRequest[alice] = 0│
│  - Alice now owns 952 vault shares  │
└─────────────────────────────────────┘
```

### Detailed Flow: Asynchronous Redemption

```
┌─────────────┐
│  User Bob   │
└──────┬──────┘
       │
       │ 1. requestRedeem(500 shares, bob)
       ▼
┌─────────────────────────────────────┐
│  Vault (Pending State)              │
│  - Transferred: 500 shares from Bob │
│  - pendingRedeemRequest[bob] += 500 │
│  - Assets NOT sent yet              │
└──────┬──────────────────────────────┘
       │
       │ 2. Off-chain processing
       │    - Vault sells underlying assets
       │    - NAV calculated: $1.10 per share
       │    - Liquidity confirmed available
       ▼
┌─────────────────────────────────────┐
│  Vault (Claimable State)            │
│  - pendingRedeemRequest[bob] = 0    │
│  - claimableRedeemRequest[bob] = 550 USDC│
│    (500 shares * $1.10 = 550 USDC)  │
└──────┬──────────────────────────────┘
       │
       │ 3. Bob calls redeem(500, bob, bob)
       ▼
┌─────────────────────────────────────┐
│  Vault (Claimed State)              │
│  - Transferred: 550 USDC to Bob     │
│  - claimableRedeemRequest[bob] = 0  │
│  - Bob's shares burned              │
└─────────────────────────────────────┘
```

---

## Code Examples

### [Example 1: Basic Asynchronous Deposit Vault](./AsyncDepositVault.sol)

### [Example 2: Liquid Staking with Async Redemption](./LiquidStakingVault.sol)

### [Example 3: Real-World Asset (RWA) Vault](./RealEstateVault.sol)

---

## Real-World Use Cases

### 1. **Centrifuge - Invoice Financing** ✅ Live

Centrifuge's Tinlake architecture uses ERC7540-style request queues for invoice financing and credit-backed RWA pools. Redemptions remain in Pending state until borrower payments clear, enabling the system to scale beyond 500 million dollars in AUM without liquidity mismatches.

**Flow**:
```
1. Investor deposits USDC → requestDeposit()
2. Centrifuge deploys to invoice pool
3. Invoices mature (30-90 days)
4. Investor redeems → requestRedeem()
5. Wait for invoice payments
6. Claim USDC → redeem()
```

### 2. **Liquid Staking Tokens**

Example: Lido stETH with ERC-7540

**Current Problem**: 
- Deposit stETH → instant
- Withdraw → 7 day unbonding period → requires custom queue

**With ERC-7540**:
```solidity
// Deposit: Synchronous (ERC-4626)
lido.deposit(1000 ETH, alice); // Instant stETH

// Withdraw: Asynchronous (ERC-7540)
lido.requestRedeem(1000 stETH, alice); // Start unbonding
// ... wait 7 days ...
lido.redeem(1000 stETH, alice); // Claim ETH
```

### 3. **Cross-Chain Vaults**

Vault on Ethereum, assets on Arbitrum:

```
1. User deposits on Ethereum → requestDeposit()
2. Bridge assets to Arbitrum (1 hour)
3. Deploy to Arbitrum yield strategies
4. Bridge back confirmation
5. Mark claimable → deposit()
```

### 4. **Regulated Fund Vaults**

Traditional fund with daily/weekly NAV:

```
Monday 9am: User requests deposit of $100k
Monday-Friday: Fund manager deploys capital
Friday 4pm: NAV calculated at $1.02 per share
Saturday: User claims 98,039 shares ($100k / $1.02)
```

---