#!/bin/bash

# Compound V2 Audit Environment Setup Script
# This script sets up the complete audit environment with all necessary configurations

echo "=== Compound V2 Audit Environment Setup ==="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_header() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Check if required tools are installed
check_requirements() {
    print_header "Checking Requirements"
    
    # Check for Foundry
    if ! command -v forge &> /dev/null; then
        print_error "Foundry is not installed. Please install from https://getfoundry.sh/"
        exit 1
    fi
    print_status "Foundry found: $(forge --version | head -n1)"
    
    # Check for Git
    if ! command -v git &> /dev/null; then
        print_error "Git is not installed"
        exit 1
    fi
    print_status "Git found: $(git --version)"
    
    # Check for Node.js (optional, for additional tooling)
    if command -v node &> /dev/null; then
        print_status "Node.js found: $(node --version)"
    else
        print_warning "Node.js not found (optional for additional tooling)"
    fi
}

# Setup environment variables
setup_env_vars() {
    print_header "Setting up Environment Variables"
    
    # Create .env file if it doesn't exist
    if [ ! -f .env ]; then
        print_status "Creating .env file..."
        cat > .env << EOF
# Compound V2 Audit Environment Configuration

# RPC URLs (replace with your actual endpoints)
ETH_RPC_URL=https://eth-mainnet.alchemyapi.io/v2/YOUR_API_KEY_HERE
POLYGON_RPC_URL=https://polygon-mainnet.alchemyapi.io/v2/YOUR_API_KEY_HERE
ARBITRUM_RPC_URL=https://arb-mainnet.g.alchemy.com/v2/YOUR_API_KEY_HERE

# Private key for deployment (use test key only!)
PRIVATE_KEY=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Etherscan API keys (for contract verification)
ETHERSCAN_API_KEY=YOUR_ETHERSCAN_API_KEY_HERE

# Security settings
ENABLE_SAFETY_CHECKS=true
MAX_GAS_LIMIT=30000000

# Test configuration
FORK_BLOCK_NUMBER=18500000
TEST_ACCOUNT_FUNDING=100000000000000000000  # 100 ETH in wei

# Logging configuration
VERBOSE_LOGGING=true
GENERATE_GAS_REPORTS=true
SAVE_AUDIT_LOGS=true
EOF
        print_status ".env file created with default values"
        print_warning "Please update .env with your actual RPC URLs and API keys"
    else
        print_status ".env file already exists"
    fi
    
    # Load environment variables
    source .env
}

# Setup Git hooks for security
setup_git_hooks() {
    print_header "Setting up Git Hooks"
    
    mkdir -p .git/hooks
    
    # Pre-commit hook to prevent committing private keys
    cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash

# Check for potential private key leaks
if git diff --cached --name-only | xargs grep -l "PRIVATE_KEY\|private.*key\|0x[a-f0-9]\{64\}" | grep -v ".example\|README"; then
    echo "Error: Potential private key found in staged files"
    echo "Please remove private keys before committing"
    exit 1
fi

# Check for API key leaks  
if git diff --cached --name-only | xargs grep -l "API_KEY.*[a-zA-Z0-9]\{20,\}" | grep -v ".example\|README"; then
    echo "Warning: Potential API key found in staged files"
    echo "Please review and remove if necessary"
fi

# Run tests before commit
echo "Running security tests..."
forge test --no-match-test "test_mainnet" -q
EOF
    
    chmod +x .git/hooks/pre-commit
    print_status "Git pre-commit hook installed"
}

# Install additional dependencies
install_dependencies() {
    print_header "Installing Dependencies"
    
    # Update Foundry
    print_status "Updating Foundry..."
    foundryup
    
    # Install/update dependencies
    print_status "Installing Forge dependencies..."
    forge install --no-commit
    
    # Build contracts to check everything works
    print_status "Building contracts..."
    forge build
    
    if [ $? -eq 0 ]; then
        print_status "Build successful"
    else
        print_error "Build failed - please check your contracts"
        exit 1
    fi
}

# Setup test data and fixtures
setup_test_data() {
    print_header "Setting up Test Data"
    
    # Create test fixtures directory
    mkdir -p test/fixtures
    
    # Create sample test data
    cat > test/fixtures/test-accounts.json << EOF
{
  "accounts": {
    "admin": "0x0000000000000000000000000000000000000001",
    "user1": "0x0000000000000000000000000000000000000002", 
    "user2": "0x0000000000000000000000000000000000000003",
    "liquidator": "0x0000000000000000000000000000000000000004",
    "attacker": "0x0000000000000000000000000000000000000005",
    "whale": "0x0000000000000000000000000000000000000006"
  },
  "funding": {
    "eth_amount": "100000000000000000000",
    "token_amounts": {
      "usdc": "100000000000",
      "dai": "100000000000000000000000",
      "comp": "1000000000000000000000"
    }
  }
}
EOF
    
    print_status "Test fixtures created"
}

# Create useful scripts
create_scripts() {
    print_header "Creating Utility Scripts"
    
    # Quick test runner
    cat > scripts/test-quick.sh << 'EOF'
#!/bin/bash
echo "Running quick security tests..."
forge test --match-contract FlashLoan --fork-url $ETH_RPC_URL -vv
forge test --match-contract Reentrancy --fork-url $ETH_RPC_URL -vv
forge test --match-contract Historical --fork-url $ETH_RPC_URL -vv
EOF
    
    # Full test suite
    cat > scripts/test-full.sh << 'EOF'
#!/bin/bash
echo "Running full audit test suite..."
echo "This may take several minutes..."

# Set RPC URL
if [ -z "$ETH_RPC_URL" ]; then
    echo "Error: ETH_RPC_URL not set in .env"
    exit 1
fi

# Run all tests with coverage
forge test --fork-url $ETH_RPC_URL --gas-report --coverage -vvv

# Generate coverage report
echo "Generating coverage report..."
forge coverage --fork-url $ETH_RPC_URL --report lcov
genhtml lcov.info -o coverage --branch-coverage

echo "Coverage report generated in ./coverage/index.html"
EOF
    
    # Gas analysis script
    cat > scripts/analyze-gas.sh << 'EOF'
#!/bin/bash
echo "Analyzing gas usage patterns..."

# Run specific gas-intensive tests
forge test --fork-url $ETH_RPC_URL --gas-report --match-test "test_.*[Aa]ttack" > gas-analysis.txt

echo "Gas analysis saved to gas-analysis.txt"

# Extract high gas usage patterns
echo "High gas usage operations:"
grep -E "test_.*[Aa]ttack.*[0-9]{7,}" gas-analysis.txt || echo "No high gas usage found"
EOF
    
    # Make scripts executable
    chmod +x scripts/*.sh
    print_status "Utility scripts created and made executable"
}

# Security validation
validate_security() {
    print_header "Security Validation"
    
    # Check for common security issues
    print_status "Running security checks..."
    
    # Check for hardcoded private keys (excluding examples)
    if grep -r "0x[a-f0-9]\{64\}" src/ test/ --exclude-dir=".git" | grep -v "example\|test.*key\|mock" | head -1; then
        print_error "Found potential hardcoded private keys in source code"
        print_warning "Please review and remove any real private keys"
    else
        print_status "No hardcoded private keys found"
    fi
    
    # Check RPC URL configuration
    if grep -q "YOUR_API_KEY_HERE" .env; then
        print_warning "Please update your RPC URLs in .env file"
    else
        print_status "RPC URLs appear to be configured"
    fi
    
    # Test basic functionality
    print_status "Testing basic functionality..."
    if forge test --no-match-test "test_.*fork\|test_.*mainnet" -q; then
        print_status "Basic tests passed"
    else
        print_error "Basic tests failed - please review contract code"
    fi
}

# Generate documentation
generate_docs() {
    print_header "Generating Documentation"
    
    # Create audit report template
    mkdir -p audit-reports/templates
    
    cat > audit-reports/templates/audit-report-template.md << 'EOF'
# Compound V2 Security Audit Report

## Executive Summary
- **Protocol**: Compound V2
- **Audit Date**: [DATE]
- **Auditor**: [YOUR_NAME]
- **Scope**: [SCOPE_DESCRIPTION]

## Methodology
1. Automated vulnerability scanning
2. Manual code review
3. Attack vector simulation
4. Historical vulnerability analysis

## Findings Summary
| Severity | Count | Description |
|----------|-------|-------------|
| Critical | 0     | Issues that could lead to loss of funds |
| High     | 0     | Issues that could significantly impact protocol |
| Medium   | 0     | Issues with moderate impact |
| Low      | 0     | Minor issues and improvements |

## Detailed Findings

### [FINDING-001] Title
- **Severity**: [LEVEL]
- **Description**: [DESCRIPTION]
- **Impact**: [IMPACT]
- **Recommendation**: [RECOMMENDATION]

## Test Results
[INSERT_TEST_RESULTS]

## Gas Analysis
[INSERT_GAS_ANALYSIS]

## Conclusion
[CONCLUSION]
EOF
    
    print_status "Documentation templates created"
}

# Main setup function
main() {
    print_header "Compound V2 Audit Environment Setup"
    
    check_requirements
    setup_env_vars
    setup_git_hooks
    install_dependencies
    setup_test_data
    create_scripts
    validate_security
    generate_docs
    
    print_header "Setup Complete!"
    
    echo ""
    print_status "Your Compound V2 audit environment is ready!"
    echo ""
    print_status "Next steps:"
    echo "1. Update .env file with your RPC URLs and API keys"
    echo "2. Run: source .env"
    echo "3. Test the setup: forge test --no-match-test fork"
    echo "4. Run full test suite: ./scripts/test-full.sh"
    echo "5. Start your security audit!"
    echo ""
    print_status "Available commands:"
    echo "- forge test --fork-url \$ETH_RPC_URL  # Run all tests"
    echo "- ./scripts/test-quick.sh              # Quick security tests"
    echo "- ./scripts/test-full.sh               # Full test suite with coverage"
    echo "- ./scripts/analyze-gas.sh             # Gas usage analysis"
    echo ""
    print_warning "Remember: Only use test private keys and never commit real secrets!"
}

# Run main function
main "$@"