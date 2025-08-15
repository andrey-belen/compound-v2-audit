# Contributing to Compound V2 Security Audit Framework

Thank you for your interest in contributing to this educational security research project! 

## 🎯 Project Mission

This framework is designed for **educational and defensive security research only**. All contributions must align with this mission of building better, more secure DeFi protocols through understanding vulnerabilities and developing robust defenses.

## 🛡️ Code of Conduct

- **Educational Purpose Only**: All contributions must be for learning and defensive security
- **No Malicious Content**: Do not contribute attack code intended for malicious use
- **Respectful Collaboration**: Maintain professional and respectful communication
- **Quality Standards**: Follow existing code patterns and documentation standards

## 🚀 How to Contribute

### 1. Fork and Clone
```bash
git clone https://github.com/your-username/compound-v2-audit.git
cd compound-v2-audit
```

### 2. Set Up Development Environment
```bash
# Install Foundry if not already installed
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Copy environment file
cp .env.example .env
# Edit .env with your RPC endpoints

# Install dependencies
forge install

# Run tests to ensure everything works
forge test
```

### 3. Create a Feature Branch
```bash
git checkout -b feature/your-feature-name
```

### 4. Make Your Changes
See the sections below for specific contribution types.

### 5. Test Your Changes
```bash
# Run all tests
forge test

# Run with fork testing
source .env && forge test --fork-url $ETH_RPC_URL

# Check formatting
forge fmt --check

# Run gas analysis
forge test --gas-report
```

### 6. Submit a Pull Request
- Write clear commit messages
- Update documentation if needed
- Ensure all tests pass
- Include a detailed PR description

## 📝 Contribution Types

### 🔍 New Vulnerability Tests
Perfect for adding new educational test cases:

**Example Areas:**
- Historical DeFi exploits recreation
- Edge case testing scenarios
- Cross-protocol interaction vulnerabilities
- MEV (Maximal Extractable Value) demonstrations

**Guidelines:**
- Add tests to appropriate directories (`test/exploits/`, `test/unit/`, etc.)
- Include detailed comments explaining the vulnerability
- Use the established inheritance pattern: `Test, AuditBase, CompoundHelpers`
- Add logging with `withLogging()` modifier
- Document expected vs actual behavior

### 🛠️ Infrastructure Improvements
Help improve the testing framework:

**Areas:**
- Enhanced helper functions in `src/CompoundHelpers.sol`
- Better logging and reporting in `src/AuditBase.sol`
- New oracle manipulation utilities in `src/OracleManipulator.sol`
- CI/CD improvements
- Documentation enhancements

### 📚 Documentation
Improve educational value:

**Areas:**
- Code comments and explanations
- README improvements
- CLAUDE.md updates for better AI assistant guidance
- Tutorial creation
- Vulnerability explanation documentation

### 🧪 Test Coverage
Expand test coverage:

**Areas:**
- Unit tests for helper functions
- Integration tests for complex scenarios
- Fuzz testing for edge cases
- Gas optimization tests

## 📁 Project Structure

```
compound-v2-audit/
├── src/                    # Core audit infrastructure
│   ├── AuditBase.sol      # Base utilities and logging
│   ├── CompoundHelpers.sol # Compound interaction helpers
│   └── OracleManipulator.sol # Price manipulation utilities
├── test/
│   ├── exploits/          # Attack vector test suites
│   ├── unit/              # Unit tests
│   ├── integration/       # Integration tests
│   └── fixtures/          # Test data
├── scripts/               # Deployment and utility scripts
├── audit-reports/         # Generated reports
└── lib/                   # Dependencies
```

## ✅ Pull Request Checklist

Before submitting your PR, ensure:

- [ ] Code compiles without warnings
- [ ] All tests pass
- [ ] New tests added for new functionality
- [ ] Code follows existing patterns and style
- [ ] Documentation updated if needed
- [ ] Commit messages are clear and descriptive
- [ ] Educational purpose is clear and well-documented
- [ ] No malicious code or attack vectors for harmful use

## 🔧 Development Guidelines

### Code Style
- Follow Solidity best practices
- Use clear, descriptive variable names
- Add comprehensive comments
- Maintain consistent formatting (`forge fmt`)

### Testing
- Write descriptive test names: `test_SpecificVulnerabilityDescription()`
- Use the `withLogging()` modifier for audit tests
- Include detailed console output explaining what's happening
- Test both success and failure scenarios

### Documentation
- Document all public functions with NatSpec
- Explain the educational purpose of each test
- Include references to real-world incidents when applicable
- Keep README and CLAUDE.md updated

## 🐛 Reporting Issues

When reporting issues:

1. **Check existing issues** first
2. **Use the issue template** if available
3. **Provide clear reproduction steps**
4. **Include environment details** (Foundry version, OS, etc.)
5. **Label appropriately** (bug, enhancement, documentation, etc.)

## 💡 Feature Requests

For new features:

1. **Open an issue first** to discuss the idea
2. **Explain the educational value**
3. **Describe the proposed implementation**
4. **Consider the scope** and complexity

## 🔒 Security Considerations

This is a security research project, so:

- **Never commit real private keys** or sensitive data
- **Use test accounts only** (like default Anvil keys)
- **Test on forks/testnets only**
- **Document security implications** of new tests
- **Follow responsible disclosure** for any real vulnerabilities found

## 📞 Getting Help

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and general discussion
- **Code Review**: Maintainers will review all PRs

## 🙏 Recognition

Contributors will be recognized in:
- GitHub contributors list
- Release notes for significant contributions
- Project documentation

Thank you for helping make DeFi more secure through education! 🛡️