# Proxy Patterns

There are several proxy patterns, each solving different problems.

## 1. Transparent Proxy Pattern (EIP-1967)

The most widely used pattern, standardized in EIP-1967.

### Implementation [TransparentUpgradeableProxy](TransparentUpgradeableProxy.sol)

#### HOW TO USE:

1. Deploy ImplementationV1
2. Deploy UpgradeableProxy with ImplementationV1 address and admin
3. Call proxy functions - they execute in ImplementationV1 context
4. Deploy ImplementationV2
5. Call proxy.upgradeTo(ImplementationV2 address)
6. Now proxy uses V2 implementation with same storage

---

## 2. UUPS Proxy Pattern (EIP-1822)

**Universal Upgradeable Proxy Standard**

### Key Difference from Transparent

```
Transparent: Upgrade logic in Proxy
UUPS:        Upgrade logic in Implementation
```

### Advantages

- ✅ Lower deployment cost (simpler proxy)
- ✅ More flexible (upgrade logic can evolve)
- ✅ No function selector clashing issues
- ✅ Admin doesn't need special treatment

### Disadvantages

- ⚠️ Upgrade logic can be buggy
- ⚠️ If implementation loses upgrade ability, stuck forever
- ⚠️ More responsibility on implementation

### Implementation [UUPSProxy](UUPSProxy.sol)

---

## 3. Minimal Proxy (EIP-1167)

**ERC-1167** (Minimal Proxy Contract / Clone Contract) is a standard for deploying **extremely cheap proxy contracts** that delegate all calls to a single implementation contract.

### Simple Analogy

**Without Proxies:**
```
Like printing 1000 copies of a book
Each copy: Full book (expensive)
Storage: 1000 × full book size
```

**With ERC-1167:**
```
Like creating 1000 bookmarks pointing to one book
Each bookmark: Just the page reference (cheap!)
Storage: 1 book + 1000 tiny bookmarks
```

### Implementation [MinimalProxy](minimal-proxy/MinimalProxy.sol)

### When to Use:

✅ Multiple instances of same logic  
✅ Low-frequency interactions per instance  
✅ Gas efficiency is priority  
✅ Factory pattern makes sense

### ERC-1167 vs ERC-1967 (UUPS/Transparent)

| Feature | ERC-1167 | ERC-1967 |
|---------|----------|----------|
| **Deployment Cost** | ~41,000 gas | ~200,000 gas |
| **Upgradeability** | ❌ No | ✅ Yes |
| **Runtime Overhead** | ~700 gas/call | ~2,000 gas/call |
| **Use Case** | Many identical contracts | Single upgradeable contract |
| **Complexity** | Very simple | Complex |
| **Security Risk** | Low | Medium-High |

### Detailed Examples

#### **Example 1:** [Simple Token Cloning](minimal-proxy/Example1.sol)
- **Scenario:** Deploy multiple token contracts efficiently.

#### **Example 2:** [NFT Collection Factory](minimal-proxy/Example2.sol)
- **Scenario:** Create multiple NFT collections, each with unique metadata.

#### **Example 3:** [Vault Factory with Different Strategies](minimal-proxy/Example3.sol)
- **Scenario:** DeFi protocol with multiple yield strategies, each as a separate vault.

#### **Example 4:** [Clone with Immutable Args (CREATE2 + Data)](minimal-proxy/Example4.sol)

