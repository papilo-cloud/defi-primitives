# Delegatecall: Complete Deep Dive

## Summary

**Delegatecall is powerful but dangerous**:

✅ **Use for**:
- Proxy patterns
- Upgradeable contracts
- Library calls
- Code reuse

⚠️ **Watch out for**:
- Storage collision
- Reentrancy
- Context confusion
- Selfdestruct
- Function selector clashing

🔒 **Security checklist**:
- Match storage layouts
- Use unstructured storage for proxy state
- Validate all inputs
- Protect against reentrancy
- Audit thoroughly
- Test extensively

Delegatecall is the foundation of upgradeable smart contracts and enables powerful patterns, but requires careful implementation to avoid serious vulnerabilities!

### Key Differences

```
CALL:
┌────────┐  call   ┌────────┐
│ Caller │────────>│ Target │
└────────┘         └────────┘
  Storage            Storage
     ↑                  ↑
     │                  │
  Unchanged          Modified
  
DELEGATECALL:
┌────────┐ delegatecall ┌────────┐
│ Caller │─────────────>│Target's│
│        │              │  CODE  │
└────────┘              └────────┘
  Storage                 (code only)
     ↑
     │
  Modified (using Target's code)
```