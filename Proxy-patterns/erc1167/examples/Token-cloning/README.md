# Simple Token Cloning

**Scenario:** Deploy multiple token contracts efficiently.

## Step 1: Create Implementation
## Step 2: Create Factory
## Step 3: Usage

```javascript
// Deploy factory
const factory = await TokenFactory.deploy();

// Create token 1
const tx1 = await factory.createToken("Alpha Token", "ALPHA", 1000000);
// Cost: ~41,000 gas ✅

// Create token 2
const tx2 = await factory.createToken("Beta Token", "BETA", 2000000);
// Cost: ~41,000 gas ✅

// Create token 3
const tx3 = await factory.createToken("Gamma Token", "GAMMA", 3000000);
// Cost: ~41,000 gas ✅

// Total: ~123,000 gas for 3 tokens!
// Traditional deployment: ~9,000,000 gas
// SAVINGS: 98.6% 🎉
```
