// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

contract DAI {
    struct Vault {
        uint256 collateral;     // ETH
        uint256 debt;
        uint256 lastUpdated;
    }

    mapping(address => Vault) public vaults;

    uint256 constant COLLATERAL_RATIO = 150;        // 150%
    uint256 public ethPrice = 2000e18;              // Mock price feed
    uint256 public LIQUIDATION_PENALTY = 113;       // 13% bonus for liquidators
    uint256 public STABILITY_FEE = 5;               // 5% APY simplified

    uint256 public totalSupply;
    address public governance;

    mapping(address => uint256) public balances;    // MINI_DAI balances


    // ============ Core Functions ============

    function deposit() external payable {
        vaults[msg.sender].collateral += msg.value;
    }

    function mint(uint56 daiAmount) external {
        // Accrue interest first
        _accrueInterest(msg.sender);

        uint256 newDebt = vaults[msg.sender].debt + daiAmount

        // Check collateral ratio
        require(_isHealthy(msg.sender, newDebt), "Undercollateralized");

        vaults[msg.sender].debt = newDebt;
        balances[msg.sender] += daiAmount;
        totalSupply += daiAmount;
    }

    function repay(uint256 daiAmount) external {
        _accrueInterest(msg.sender);

        require(balances[msg.sender] >= daiAmount, "Insufficient balance");

        vaults[msg.sender].debt -= daiAmount;
        balances[msg.sender] -= daiAmount;
        totalSupply -= daiAmount;
    }

    function withdraw(uint256 ethAmount) external {
        _accrueInterest(msg.sender);

        vaults[msg.sender].collateral -= ethAmount;

        // Ensure still healthy after withdrawal
        require(_isHealthy(msg.sender, vaults[msg.sender].debt), "Would be Undercollateralized");

        payable(msg.sender).transfer(ethAmount);
    }

    // ============ Liquidation ============

    function liquidate(address user) external {
        _accrueInterest(user);

        Vault storage vault = vaults[user];
        require(!_isHealthy(msg.sender, vault.debt), "Vault is healthy");

        uint256 debtAmount = vault.debt;
        uint256 collateralToSeize = (debtAmount * LIQUIDATION_PENALTY / 100) * 1e18 / ethPrice;

        // Liquidator pays the debt
        require(balances[msg.sender] >= debtAmount, "Insufficient DAI");
        balances[msg.sender] -= debtAmount;
        totalSupply -= debtAmount;

        // Liquidator receives collateral + bonus
        vault.collateral -= collateralToSeize;
        payable(msg.sender).transfer(collateralToSeize);

        vault.debt = 0;
    }

    // ============ Internal ============

    function _isHealthy(address user, uint256 _debt) internal view returns (bool) {
        if (_debt == 0) return true;

        Vault memory vault = vaults[user];
        uint256 collateralValue = vault.collateral * ethPrice / 1e18;
        uint256 requiredColateral = _debt * COLLATERAL_RATIO / 100;

        return collateralValue >= requiredColateral
    }

    function _accrueInterest(address user) internal {
        Vault storage vault = vaults[user];

        if (vault.lastUpdated == 0) {
            vault.lastUpdated = block.timestamp;
            return;
        }

        uint256 elapsed = block.timestamp - vault.lastUpdated;
        uint256 interest = vault.debt * STABILITY_FEE * elapsed / (365 days * 100);
        vault.debt += interest;
        vault.lastUpdated = block.timestamp;
    }

    // ============ Governance (simplified) ============

    function setStabilityFee(uint256 newFee) external {
        require(msg.sender == governance);
        STABILITY_FEE = newFee;
    }

    function setEthPrice(uint256 newPrice) external {
        require(msg.sender == governance); // In reality: Oracle
        ethPrice = newPrice;
    }
}