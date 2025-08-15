# Compound V2 Security Audit Framework

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Foundry](https://img.shields.io/badge/Built%20with-Foundry-FFDB1C.svg)](https://getfoundry.sh/)

A comprehensive security audit framework for analyzing Compound V2 protocol vulnerabilities, designed for educational and defensive security research.

## 🎯 Purpose

This project provides a complete testing environment for:
- **🔍 Security Auditors**: Understanding real-world DeFi attack patterns
- **👨‍💻 DeFi Developers**: Identifying common vulnerability classes  
- **🔬 Security Researchers**: Analyzing historical DeFi incidents
- **🎓 Students**: Learning blockchain security through hands-on testing

## ⚠️ Educational Disclaimer

**This framework is for educational and defensive security research only.**

✅ **Allowed Uses:**
- Learning about vulnerabilities to build better defenses
- Testing on testnets and mainnet forks only
- Security research and education
- Building defensive mechanisms

❌ **Prohibited Uses:**
- Malicious activities or attacks
- Deploying to mainnet with real funds
- Any illegal or unethical activities

## 🏗 Architecture

### Core Components
- **AuditBase.sol** - Base utilities (logging, time manipulation, token dealing)
- **CompoundHelpers.sol** - Compound V2 interaction helpers
- **OracleManipulator.sol** - Price manipulation testing utilities

### Attack Vector Coverage
- **Flash Loan Attacks** - Price manipulation, arbitrage, liquidation exploitation
- **Reentrancy Attacks** - Supply/redeem/borrow/liquidation reentrancy vectors
- **Oracle Manipulation** - Price feed attacks, sandwich attacks, staleness exploitation  
- **Historical Bugs** - Recreation of the $80M Compound bug and others
- **Liquidation Exploits** - Threshold manipulation, edge case testing

## 🚀 Quick Start

### 1. Environment Setup
```bash
# Clone and setup environment
git clone <repository-url>
cd compound-v2-audit

# Run automated setup (recommended)
./scripts/setup-env.sh

# Or manual setup
cp .env.example .env
# Edit .env with your RPC URLs and API keys
source .env
```

### 2. Install Dependencies
```bash
# Install Foundry dependencies
forge install

# Build contracts
forge build
```

### 3. Run Tests
```bash
# Quick security test suite
./scripts/test-quick.sh

# Run specific vulnerability tests
forge test --match-contract FlashLoan --fork-url $ETH_RPC_URL -vv
forge test --match-contract Reentrancy --fork-url $ETH_RPC_URL -vv
forge test --match-contract Historical --fork-url $ETH_RPC_URL -vv

# Full test suite with coverage
./scripts/test-full.sh
```

## 📊 Test Categories

### Flash Loan Attacks (`test/exploits/FlashLoanAttacks.t.sol`)
```bash
forge test --match-contract FlashLoan --fork-url $ETH_RPC_URL -vv
```
- Price manipulation + liquidation attacks
- Cross-protocol arbitrage exploitation  
- Liquidation threshold manipulation

### Reentrancy Tests (`test/exploits/ReentrancyTests.t.sol`)
```bash
forge test --match-contract Reentrancy --fork-url $ETH_RPC_URL -vv
```
- Supply/redeem reentrancy via malicious tokens
- Cross-function reentrancy patterns
- Liquidation callback exploitation

### Historical Bugs (`test/exploits/CompoundHistoricalBugs.t.sol`)
```bash
forge test --match-contract Historical --fork-url $ETH_RPC_URL -vv
```
- The $80M Compound liquidation bug (Proposal 062)
- Interest rate manipulation vulnerabilities
- Oracle staleness exploitation

## 🔧 Development Commands

### Core Testing
```bash
# Run all tests with mainnet fork
forge test --fork-url $ETH_RPC_URL

# Run with gas reporting
forge test --gas-report --fork-url $ETH_RPC_URL

# Maximum verbosity for debugging
forge test --fork-url $ETH_RPC_URL -vvvv

# Run tests with different profiles
forge test --profile ci      # More fuzz runs for CI
forge test --profile intense # Intensive testing
```

### Analysis and Debugging
```bash
# Gas usage analysis
./scripts/analyze-gas.sh

# Coverage analysis  
forge coverage --fork-url $ETH_RPC_URL --report lcov
genhtml lcov.info -o coverage --branch-coverage

# Deploy audit environment
forge script scripts/DeployAuditEnvironment.s.sol --rpc-url $ETH_RPC_URL
```

## 📁 Project Structure

```
compound-v2-audit/
├── src/                    # Core audit infrastructure
│   ├── AuditBase.sol      # Base utilities and logging
│   ├── CompoundHelpers.sol # Compound interaction helpers  
│   └── OracleManipulator.sol # Price manipulation utilities
├── test/
│   ├── exploits/          # Attack vector test suites
│   │   ├── FlashLoanAttacks.t.sol
│   │   ├── ReentrancyTests.t.sol
│   │   └── CompoundHistoricalBugs.t.sol
│   ├── unit/              # Unit tests
│   ├── integration/       # Integration tests
│   └── fixtures/          # Test data
├── scripts/               # Deployment and utility scripts
├── audit-reports/         # Generated reports
├── lib/                   # Dependencies (OpenZeppelin, Compound)
├── foundry.toml          # Foundry configuration
└── CLAUDE.md             # Detailed development guide
```

## ⚙️ Configuration

### Environment Variables (.env)
```bash
ETH_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_API_KEY
POLYGON_RPC_URL=https://polygon-mainnet.alchemyapi.io/v2/YOUR_API_KEY  
ARBITRUM_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/YOUR_API_KEY
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
```

### Fork Configuration
- **Fork Block**: 18,500,000 (before major Compound issues)
- **Gas Limit**: 30M gas for complex simulations
- **Networks**: Mainnet, Polygon, Arbitrum support

## 🔒 Security Features

- **Mainnet Protection**: Chain ID validation prevents mainnet deployment
- **Private Key Safety**: Git hooks prevent committing real private keys
- **Automated Scanning**: Pre-commit hooks scan for vulnerabilities
- **Rate Limiting**: RPC call optimization to avoid API limits

## 📈 Sample Attack Scenarios

### Flash Loan Price Manipulation
```solidity
function test_FlashLoanPriceManipulationLiquidation() public {
    // 1. Flash loan large amount of USDC
    // 2. Dump USDC to manipulate price downward  
    // 3. Liquidate positions that become underwater
    // 4. Restore price through arbitrage
    // 5. Profit from liquidation bonus minus fees
}
```

### Reentrancy via Malicious Token
```solidity  
function test_SupplyReentrancyAttack() public {
    // 1. Deploy malicious ERC20 with transfer hooks
    // 2. Supply malicious token to Compound
    // 3. During transfer, reenter protocol functions
    // 4. Attempt to exploit state inconsistencies
}
```

### Historical Bug Recreation
```solidity
function test_CompoundLiquidationBugReproduction() public {
    // 1. Setup pre-bug state 
    // 2. Simulate buggy COMP distribution calculation
    // 3. Demonstrate excessive reward claiming
    // 4. Calculate impact ($80M+ over-reward)
}
```

## 📊 Test Results

The framework successfully demonstrates several critical vulnerabilities:

| Test | Status | Impact |
|------|--------|--------|
| **Compound Proposal 062 Bug** | ✅ Exploited | 990x reward over-payment |
| **Interest Rate Manipulation** | ✅ Demonstrated | 151 bps rate increase |
| **Oracle Staleness Exploit** | ✅ Exploited | Stale price borrowing |
| **Liquidation Edge Cases** | ✅ Protected | Dust & self-liquidation prevented |
| **Liquidation Incentive Bug** | ✅ Detected | 100% calculation discrepancy |

### Example Output:
```
=== REPRODUCING COMPOUND PROPOSAL 062 BUG ===
Expected COMP reward: 100000000000000000000
Buggy calculation result: 100000000000000000000000
Excessive reward claimed: 99000000000000000000000
Over-reward multiplier: 990
```

## 📊 Gas Analysis

The framework includes detailed gas profiling for:
- Attack transaction costs
- Defense mechanism overhead  
- Optimization opportunities
- Comparative analysis across attack vectors

## 🎓 Educational Value

### For Security Auditors
- Real-world attack pattern recognition
- Vulnerability assessment methodologies
- Impact quantification techniques

### For Developers  
- Common DeFi vulnerability classes
- Defense mechanism implementation
- Secure coding patterns

### For Researchers
- Historical incident analysis
- Attack vector evolution
- Economic impact modeling

## 🤝 Contributing

We welcome contributions to improve this educational security framework! Please see our contribution guidelines:

### How to Contribute
1. **Fork** the repository
2. **Create** a feature branch (`git checkout -b feature/amazing-feature`)
3. **Commit** your changes (`git commit -m 'Add some amazing feature'`)
4. **Push** to the branch (`git push origin feature/amazing-feature`)
5. **Open** a Pull Request

### Contribution Focus Areas
- ✅ New defensive testing scenarios
- ✅ Historical vulnerability recreations
- ✅ Educational documentation improvements
- ✅ Security analysis methodologies
- ✅ Test coverage improvements

### Code of Conduct
- All contributions must be for educational/defensive purposes only
- Maintain high code quality and documentation standards
- Follow existing code patterns and conventions

## 📚 Resources

- [Compound V2 Documentation](https://compound.finance/docs)
- [DeFi Security Best Practices](https://consensys.github.io/smart-contract-best-practices/)
- [Foundry Book](https://book.getfoundry.sh/)
- [OpenZeppelin Security](https://docs.openzeppelin.com/contracts/4.x/security)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Legal Notice

This software is provided for educational and research purposes only. Users are responsible for ensuring their usage complies with applicable laws and regulations. The authors disclaim all liability for any misuse of this software.

## 👨‍💻 Creator

**Created by [Andrey Belen](https://github.com/andrey-belen)**

This project was designed and implemented from scratch as a comprehensive educational security research framework.

## 🙏 Acknowledgments

- Compound Labs for the original Compound V2 protocol
- The DeFi security research community  
- Foundry team for the excellent testing framework

---

**🛡️ Remember**: The goal is to build better, more secure DeFi protocols by understanding how attacks work and developing robust defenses. Use this knowledge responsibly!

⭐ **Star this repo** if you found it helpful for learning DeFi security!
