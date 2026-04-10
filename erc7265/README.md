# ERC-7265 Circuit Breaker Standard - Deep Dive

## Table of Contents
1. [Introduction](#introduction)
2. [The Problem ERC-7265 Solves](#the-problem)
3. [What is a Circuit Breaker?](#what-is-a-circuit-breaker)
4. [Core Concepts](#core-concepts)
5. [Technical Architecture](#technical-architecture)
6. [Implementation Details](#implementation-details)
7. [Real-World Examples](#real-world-examples)
8. [Integration Guide](#integration-guide)
9. [Security Considerations](#security-considerations)
10. [Limitations and Trade-offs](#limitations-and-trade-offs)
11. [Comparison with Traditional Finance](#comparison-with-traditional-finance)

---

## Introduction

**ERC-7265** is an Ethereum Improvement Proposal that defines a standard interface for implementing circuit breakers in DeFi protocols. Proposed in July 2023 by developers Diyahir Campos, Meir Bank (Fluid Protocol), and Philippe Dumonet, this standard aims to mitigate the devastating impact of hacks and exploits on decentralized finance applications.

**Key Statistics:**
- **$3 billion+** stolen from DeFi protocols in 2023 alone
- **$6.6 billion** total stolen from DeFi hacks historically
- Approximately **15% of DeFi TVL** has been lost to exploits

The circuit breaker mechanism temporarily halts protocol-wide token outflows when predefined thresholds are exceeded, potentially preventing or minimizing losses during security incidents.

---

## The Problem ERC-7265 Solves

### DeFi Security Landscape

DeFi protocols face numerous attack vectors:

1. **Re-entrancy attacks** (e.g., The DAO hack - $60M, 2016)
2. **Flash loan attacks**
3. **Oracle manipulation**
4. **Logic errors in smart contracts**
5. **Bridge exploits**

### Case Study: Euler Finance Hack (March 2023)

**The Attack:**
- Hackers exploited a vulnerability in Euler Finance's liquidity pool
- Borrowed large amounts of crypto to drain the ETH/USDC pool
- **Total Loss: $195 million**

**How ERC-7265 Could Have Helped:**
A circuit breaker would have detected the abnormally large transaction and paused outflows, potentially saving the majority of funds.

### The Fundamental Challenge

```
Traditional Security Measures:
✓ Audits - Can't catch all bugs
✓ Bug bounties - Reactive, not preventive
✓ Insurance - Expensive, limited coverage
✗ Real-time protection - MISSING

ERC-7265 provides the missing piece: automated, real-time protection
```

---

## What is a Circuit Breaker?

### Concept from Traditional Systems

A circuit breaker is a control mechanism that automatically disables a system when dangerous conditions are detected. Think of it like:

- **Electrical circuit breaker:** Cuts power when current exceeds safe levels
- **Stock market circuit breakers:** Halt trading during extreme volatility
- **DeFi circuit breaker:** Pauses token outflows during suspicious activity

### How It Works in DeFi

```
Normal Operation:
User → Withdraw Request → Protocol → Transfer Tokens → User
                              ↓
                    Circuit Breaker Monitors
                    (Everything Normal ✓)

Attack Detected:
User → Withdraw Request → Protocol → Circuit Breaker TRIGGERED!
                              ↓
                    Token Outflow PAUSED ⏸
                    (Threshold Exceeded ⚠️)
```

---

## Core Concepts

### 1. Rate Limiting Metrics

The circuit breaker monitors specific metrics to detect anomalies:

**Primary Metric: Token Outflow Rate**
- Tracks the **notional amount** of tokens leaving the protocol
- Measured over a **lookback period** (e.g., 1 hour, 24 hours)
- **Price-agnostic** (counts token quantity, not USD value)

### 2. Key Parameters

Every circuit breaker configuration includes:

| Parameter | Description | Example |
|-----------|-------------|---------|
| **Metric** | What to monitor | Token outflow amount |
| **Threshold** | Maximum allowed value | 10% of protocol TVL |
| **Lookback Period** | Time window to measure | 1 hour |
| **Cooldown Period** | How long to pause | Until admin resolves |

### 3. Two Implementation Modes

ERC-7265 offers flexibility in how it handles rate limits:

**Mode 1: Delay Settlement**
```solidity
// Circuit breaker temporarily holds tokens
// Releases after cooldown if legitimate
function onTokenOutflow(address token, uint256 amount) {
    if (exceedsRateLimit(token, amount)) {
        // Hold tokens in escrow
        holdInEscrow(token, amount);
        startCooldown();
    } else {
        // Transfer normally
        transferTo(recipient);
    }
}
```

**Mode 2: Revert Transaction**
```solidity
// Immediately reject transaction
function onTokenOutflow(address token, uint256 amount) {
    if (exceedsRateLimit(token, amount)) {
        revert RateLimitExceeded();
    }
    transferTo(recipient);
}
```

---

## Technical Architecture

### [Interface Definition](./ICircuitBreaker.sol)

### [Storage Structure](./StorageStructure.sol)

## Implementation Details

### [Complete Circuit Breaker Implementation](./CircuitBreaker.sol)

### [Protected Contract Base Class](./ProtectedContract.sol)


---

## Real-World Examples

### [Example 1: Simple Lending Protocol](./SimpleLendingProtocol.sol)

### [Example 2: DEX with Circuit Breaker](./ProtectedDEX.sol)