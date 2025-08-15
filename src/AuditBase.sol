// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title AuditBase
 * @notice Base contract for Compound V2 security audits with common utilities
 * @dev Provides helper functions for token manipulation, time control, and logging
 */
abstract contract AuditBase is Test {
    
    // Common Ethereum mainnet addresses
    address constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;  
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address constant DAI = 0x6B175474E89094C44Da98b954EedeAC495271d0F;
    address constant USDT = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    
    // Common test accounts with different roles
    address constant ADMIN = address(0x1);
    address constant USER1 = address(0x2);
    address constant USER2 = address(0x3);
    address constant LIQUIDATOR = address(0x4);
    address constant ATTACKER = address(0x5);
    address constant WHALE = address(0x6);
    
    // Compound V2 Protocol addresses (mainnet)
    address constant COMPTROLLER = 0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B;
    address constant CUSDC = 0x39AA39c021dfbaE8faC545936693aC917d5E7563;
    address constant CDAI = 0x5d3a536E4D6DbD6114cc1Ead35777bAB948E3643;
    address constant CETH = 0x4Ddc2D193948926D02f9B1fE9e1daa0718270ED5;
    address constant CUSDT = 0xF650c3D88D12DB4dD56F8D26EaB1EbDd99A3A4F1;
    address constant COMP_TOKEN = 0xc00e94Cb662C3520282E6f5717214004A7f26888;
    address constant PRICE_ORACLE = 0x046728da7cb8272284238bD3e47909823d63A58D;
    
    // Logging and reporting
    struct AuditLog {
        string testName;
        address user;
        string action;
        uint256 amount;
        uint256 gasUsed;
        uint256 timestamp;
        bool success;
        string notes;
    }
    
    AuditLog[] public auditLogs;
    uint256 public totalGasUsed;
    
    // Events for detailed tracking
    event AuditStep(
        string indexed testName, 
        address indexed user, 
        string action, 
        uint256 amount, 
        uint256 gasUsed
    );
    
    event VulnerabilityDetected(
        string indexed vulnerability,
        address indexed target,
        uint256 severity, // 1=Low, 2=Medium, 3=High, 4=Critical
        string description
    );
    
    modifier withLogging(string memory testName, string memory action) {
        uint256 gasBefore = gasleft();
        
        _;
        uint256 gasUsed = gasBefore - gasleft();
        totalGasUsed += gasUsed;
        
        auditLogs.push(AuditLog({
            testName: testName,
            user: msg.sender,
            action: action,
            amount: 0,
            gasUsed: gasUsed,
            timestamp: block.timestamp,
            success: true,
            notes: ""
        }));
        
        emit AuditStep(testName, msg.sender, action, 0, gasUsed);
    }
    
    /**
     * @notice Setup function to be called before each test
     * @dev Configures test environment with proper block number and accounts
     */
    function setUpAudit() internal {
        // Fork mainnet at a specific block
        uint256 forkId = vm.createFork(vm.envString("ETH_RPC_URL"), 18500000);
        vm.selectFork(forkId);
        
        // Make contracts persistent across forks
        vm.makePersistent(COMPTROLLER);
        vm.makePersistent(CUSDC);
        vm.makePersistent(CDAI);
        vm.makePersistent(CETH);
        vm.makePersistent(CUSDT);
        vm.makePersistent(COMP_TOKEN);
        vm.makePersistent(PRICE_ORACLE);
        vm.makePersistent(USDC);
        vm.makePersistent(WETH);
        vm.makePersistent(DAI);
        vm.makePersistent(USDT);
        
        // Label addresses for better trace readability
        vm.label(ADMIN, "Admin");
        vm.label(USER1, "User1");
        vm.label(USER2, "User2");
        vm.label(LIQUIDATOR, "Liquidator");
        vm.label(ATTACKER, "Attacker");
        vm.label(WHALE, "Whale");
        vm.label(COMPTROLLER, "Comptroller");
        vm.label(CUSDC, "cUSDC");
        vm.label(CDAI, "cDAI");
        vm.label(CETH, "cETH");
        vm.label(COMP_TOKEN, "COMP");
        
        // Setup initial balances for test accounts
        setupTestAccounts();
    }
    
    /**
     * @notice Provides test accounts with realistic token balances
     */
    function setupTestAccounts() internal {
        // Give accounts ETH for gas
        vm.deal(ADMIN, 100 ether);
        vm.deal(USER1, 50 ether);
        vm.deal(USER2, 50 ether);
        vm.deal(LIQUIDATOR, 20 ether);
        vm.deal(ATTACKER, 10 ether);
        vm.deal(WHALE, 1000 ether);
        
        // Distribute realistic token amounts
        dealToken(USDC, USER1, 100000e6);    // $100k USDC
        dealToken(USDC, USER2, 50000e6);     // $50k USDC
        dealToken(USDC, LIQUIDATOR, 500000e6); // $500k USDC
        dealToken(USDC, WHALE, 10000000e6);  // $10M USDC
        
        dealToken(DAI, USER1, 100000e18);    // $100k DAI
        dealToken(DAI, USER2, 50000e18);     // $50k DAI
        dealToken(DAI, WHALE, 5000000e18);   // $5M DAI
        
        dealToken(COMP_TOKEN, USER1, 1000e18);  // 1000 COMP
        dealToken(COMP_TOKEN, WHALE, 50000e18); // 50k COMP
    }
    
    /**
     * @notice Safely deals tokens to an address using vm.deal or token-specific methods
     */
    function dealToken(address token, address to, uint256 amount) internal {
    if (token == USDC || token == USDT) {
        // USDC/USDT have 6 decimals
        deal(token, to, amount);
    } else {
        // Most other tokens have 18 decimals  
        deal(token, to, amount);
    }

    }
    
    /**
     * @notice Time manipulation utilities for testing time-dependent logic
     */
    function skipTime(uint256 seconds_) internal {
        vm.warp(block.timestamp + seconds_);
    }
    
    function skipBlocks(uint256 blocks) internal {
        vm.roll(block.number + blocks);
    }
    
    /**
     * @notice Creates a realistic flash loan scenario
     * @dev Sets up conditions for flash loan attacks testing
     */
    function setupFlashLoanScenario() internal {
        // Ensure there's sufficient liquidity in the protocol
        vm.startPrank(WHALE);
        dealToken(USDC, WHALE, 50000000e6); // $50M USDC
        dealToken(DAI, WHALE, 50000000e18);  // $50M DAI
        vm.stopPrank();
    }
    
    /**
     * @notice Logs a vulnerability finding
     */
    function logVulnerability(
        string memory name,
        address target,
        uint256 severity,
        string memory description
    ) internal {
        emit VulnerabilityDetected(name, target, severity, description);
        console2.log("=== VULNERABILITY DETECTED ===");
        console2.log("Name:", name);
        console2.log("Target:", target);
        console2.log("Severity:", severity);
        console2.log("Description:", description);
        console2.log("==============================");
    }
    
    /**
     * @notice Calculates the health factor for a user
     * @param user The user address to calculate health factor for
     * @return healthFactor The health factor (1.5 as placeholder)
     */
    function calculateHealthFactor(address user) internal pure returns (uint256 healthFactor) {
        // This would integrate with Compound's comptroller
        // Simplified implementation for demo purposes
        user; // Suppress unused parameter warning
        return 1.5e18; // Placeholder value
    }
    
    
    /**
     * @notice Generates detailed gas report
     */
    function generateGasReport() internal view {
        console2.log("=== GAS USAGE REPORT ===");
        console2.log("Total Gas Used:", totalGasUsed);
        console2.log("Average Gas per Transaction:", totalGasUsed / auditLogs.length);
        console2.log("Number of Operations:", auditLogs.length);
        console2.log("========================");
    }
    
    /**
     * @notice Safety check to prevent accidental mainnet operations
     */
    modifier onlyTestEnvironment() {
        require(block.chainid != 1, "Cannot run on mainnet");
        _;
    }
}