// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "./AuditBase.sol";

/**
 * @title OracleManipulator
 * @notice Utilities for testing price oracle manipulation vulnerabilities
 * @dev Contains methods to simulate price manipulation attacks for security testing
 */

// Note: IPriceOracle interface is defined in CompoundHelpers.sol

interface IUniswapV2Pair {
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function sync() external;
}

interface IUniswapV2Router {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    
    function getAmountsOut(uint amountIn, address[] calldata path)
        external view returns (uint[] memory amounts);
}

interface IWETH {
    function deposit() external payable;
    function withdraw(uint wad) external;
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);
    function approve(address spender, uint value) external returns (bool);
    function balanceOf(address owner) external view returns (uint);
}

interface IERC20Extended {
    function transfer(address to, uint256 amount) external returns (bool);
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function decimals() external view returns (uint8);
    function symbol() external view returns (string memory);
}

contract OracleManipulator is AuditBase {
    
    // Uniswap V2 Router and Factory addresses
    address constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address constant UNISWAP_V2_FACTORY = 0x5C69bEe701ef814a2B6a3EDD4B1652CB9cc5aA6f;
    
    // Note: Token addresses inherited from AuditBase
    
    // Price manipulation tracking
    struct PriceManipulation {
        address targetToken;
        uint256 originalPrice;
        uint256 manipulatedPrice;
        uint256 priceImpact;
        uint256 blockNumber;
        uint256 timestamp;
    }
    
    PriceManipulation[] public priceManipulations;
    
    event PriceManipulated(
        address indexed token,
        uint256 originalPrice,
        uint256 newPrice,
        uint256 priceImpact,
        string method
    );
    
    /**
     * @notice Simulates a flash loan price manipulation attack
     * @dev This demonstrates how an attacker could manipulate prices using borrowed funds
     * @param targetToken The token whose price to manipulate
     * @param flashLoanAmount The amount to borrow for manipulation
     * @param manipulation True = pump price, False = dump price
     */
    function simulateFlashLoanPriceManipulation(
        address targetToken,
        uint256 flashLoanAmount,
        bool manipulation // true = pump, false = dump
    ) internal returns (uint256 priceImpact) {
        
        console2.log("=== FLASH LOAN PRICE MANIPULATION SIMULATION ===");
        console2.log("Target Token:", targetToken);
        console2.log("Flash Loan Amount:", flashLoanAmount);
        console2.log("Manipulation Type:", manipulation ? "PUMP" : "DUMP");
        
        // Record original price
        uint256 originalPrice = getCurrentPrice(targetToken);
        console2.log("Original Price:", originalPrice);
        
        // Simulate the flash loan by giving the attacker tokens
        if (manipulation) {
            // PUMP: Use WETH to buy target token
            deal(WETH, address(this), flashLoanAmount);
            priceImpact = executePumpAttack(targetToken, flashLoanAmount);
        } else {
            // DUMP: Use target token to sell for WETH
            deal(targetToken, address(this), flashLoanAmount);
            priceImpact = executeDumpAttack(targetToken, flashLoanAmount);
        }
        
        uint256 newPrice = getCurrentPrice(targetToken);
        console2.log("New Price:", newPrice);
        console2.log("Price Impact:", priceImpact);
        
        // Record manipulation
        priceManipulations.push(PriceManipulation({
            targetToken: targetToken,
            originalPrice: originalPrice,
            manipulatedPrice: newPrice,
            priceImpact: priceImpact,
            blockNumber: block.number,
            timestamp: block.timestamp
        }));
        
        emit PriceManipulated(
            targetToken, 
            originalPrice, 
            newPrice, 
            priceImpact, 
            "Flash Loan"
        );
        
        return priceImpact;
    }
    
    /**
     * @notice Execute a pump attack (buy pressure)
     */
    function executePumpAttack(address targetToken, uint256 wethAmount) internal returns (uint256 priceImpact) {
        IUniswapV2Router router = IUniswapV2Router(UNISWAP_V2_ROUTER);
        IWETH weth = IWETH(WETH);
        
        // Approve router to spend WETH
        weth.approve(UNISWAP_V2_ROUTER, wethAmount);
        
        // Create swap path
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = targetToken;
        
        // Get expected output before swap
        uint256[] memory amountsBefore = router.getAmountsOut(wethAmount, path);
        uint256 expectedOutput = amountsBefore[1];
        
        // Execute swap
        router.swapExactTokensForTokens(
            wethAmount,
            0, // Accept any amount of target token
            path,
            address(this),
            block.timestamp + 300
        );
        
        // Calculate price impact
        uint256[] memory amountsAfter = router.getAmountsOut(wethAmount / 10, path);
        priceImpact = ((expectedOutput - amountsAfter[1]) * 10000) / expectedOutput;
        
        return priceImpact;
    }
    
    /**
     * @notice Execute a dump attack (sell pressure)
     */
    function executeDumpAttack(address targetToken, uint256 tokenAmount) internal returns (uint256 priceImpact) {
        IUniswapV2Router router = IUniswapV2Router(UNISWAP_V2_ROUTER);
        IERC20Extended token = IERC20Extended(targetToken);
        
        // Approve router to spend target token
        token.approve(UNISWAP_V2_ROUTER, tokenAmount);
        
        // Create swap path
        address[] memory path = new address[](2);
        path[0] = targetToken;
        path[1] = WETH;
        
        // Get expected output before swap
        uint256[] memory amountsBefore = router.getAmountsOut(tokenAmount, path);
        uint256 expectedOutput = amountsBefore[1];
        
        // Execute swap
        router.swapExactTokensForTokens(
            tokenAmount,
            0, // Accept any amount of WETH
            path,
            address(this),
            block.timestamp + 300
        );
        
        // Calculate price impact
        uint256[] memory amountsAfter = router.getAmountsOut(tokenAmount / 10, path);
        priceImpact = ((expectedOutput - amountsAfter[1]) * 10000) / expectedOutput;
        
        return priceImpact;
    }
    
    /**
     * @notice Simulates sandwich attack around a large transaction
     * @dev This shows how MEV bots can manipulate prices around user transactions
     */
    function simulateSandwichAttack(
        address targetToken,
        uint256 victimTradeAmount,
        uint256 attackerCapital
    ) internal returns (uint256 profit) {
        
        console2.log("=== SANDWICH ATTACK SIMULATION ===");
        console2.log("Target Token:", targetToken);
        console2.log("Victim Trade Amount:", victimTradeAmount);
        console2.log("Attacker Capital:", attackerCapital);
        
        uint256 initialBalance = IERC20Extended(WETH).balanceOf(address(this));
        
        // Step 1: Front-run - Buy before victim
        deal(WETH, address(this), attackerCapital);
        executePumpAttack(targetToken, attackerCapital / 2);
        
        // Step 2: Victim's transaction (simulated)
        address victim = address(0x999);
        deal(WETH, victim, victimTradeAmount);
        vm.startPrank(victim);
        IUniswapV2Router router = IUniswapV2Router(UNISWAP_V2_ROUTER);
        IWETH(WETH).approve(UNISWAP_V2_ROUTER, victimTradeAmount);
        
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = targetToken;
        
        router.swapExactTokensForTokens(
            victimTradeAmount,
            0,
            path,
            victim,
            block.timestamp + 300
        );
        vm.stopPrank();
        
        // Step 3: Back-run - Sell after victim
        uint256 tokenBalance = IERC20Extended(targetToken).balanceOf(address(this));
        executeDumpAttack(targetToken, tokenBalance);
        
        // Calculate profit
        uint256 finalBalance = IERC20Extended(WETH).balanceOf(address(this));
        profit = finalBalance > initialBalance ? finalBalance - initialBalance : 0;
        
        console2.log("Sandwich Attack Profit:", profit);
        console2.log("=====================================");
        
        return profit;
    }
    
    /**
     * @notice Simulates oracle delay exploitation
     * @dev Shows how attackers can exploit oracle update delays
     */
    function simulateOracleDelayExploit(
        address targetToken,
        uint256 delaySeconds
    ) internal returns (uint256 priceDiscrepancy) {
        
        console2.log("=== ORACLE DELAY EXPLOIT SIMULATION ===");
        
        // Record current oracle price
        uint256 oraclePrice = getCurrentPrice(targetToken);
        console2.log("Oracle Price:", oraclePrice);
        
        // Manipulate market price
        deal(WETH, address(this), 1000 ether);
        executePumpAttack(targetToken, 500 ether);
        
        uint256 marketPrice = getCurrentPrice(targetToken);
        console2.log("Market Price after manipulation:", marketPrice);
        
        // Simulate oracle delay - price doesn't update immediately
        skip(delaySeconds);
        
        // Calculate discrepancy
        priceDiscrepancy = marketPrice > oraclePrice ? 
            ((marketPrice - oraclePrice) * 10000) / oraclePrice :
            ((oraclePrice - marketPrice) * 10000) / oraclePrice;
        
        console2.log("Price Discrepancy (bps):", priceDiscrepancy);
        console2.log("=======================================");
        
        return priceDiscrepancy;
    }
    
    /**
     * @notice Gets current price from DEX (simulated oracle)
     * @dev In real scenarios, this would query the actual price oracle
     */
    function getCurrentPrice(address token) internal view returns (uint256) {
        if (token == WETH) return 1e18; // 1 ETH = 1 ETH
        
        // Simulate getting price from DEX
        IUniswapV2Router router = IUniswapV2Router(UNISWAP_V2_ROUTER);
        
        address[] memory path = new address[](2);
        path[0] = token;
        path[1] = WETH;
        
        try router.getAmountsOut(1e18, path) returns (uint256[] memory amounts) {
            return amounts[1]; // Price in WETH
        } catch {
            return 0;
        }
    }
    
    /**
     * @notice Calculates the impact on liquidation threshold from price manipulation
     * @dev Shows how price manipulation can trigger false liquidations
     */
    function calculateLiquidationImpact(
        address user,
        address collateralToken,
        uint256 priceManipulation
    ) internal view returns (bool triggersLiquidation, uint256 healthFactorChange) {
        
        // This is a simplified calculation - real implementation would integrate with Compound
        uint256 originalHealthFactor = 1.2e18; // Assume 120% health factor
        
        // Calculate new health factor after price manipulation
        uint256 priceImpactFactor = priceManipulation < 5000 ? // 50% threshold
            (10000 - priceManipulation) : 5000;
            
        uint256 newHealthFactor = (originalHealthFactor * priceImpactFactor) / 10000;
        
        triggersLiquidation = newHealthFactor < 1e18;
        healthFactorChange = originalHealthFactor > newHealthFactor ?
            originalHealthFactor - newHealthFactor : 0;
            
        return (triggersLiquidation, healthFactorChange);
    }
    
    /**
     * @notice Reverts price manipulation to restore normal conditions
     * @dev Used for test cleanup
     */
    function revertPriceManipulation(address targetToken) internal {
        // In a real scenario, this would involve complex arbitrage
        // For testing, we can simply deal tokens to restore balance
        console2.log("Reverting price manipulation for:", targetToken);
        
        // Reset token balances to simulate arbitrage
        vm.deal(address(this), 0);
        deal(targetToken, address(this), 0);
        deal(WETH, address(this), 0);
    }
    
    /**
     * @notice Generates a comprehensive price manipulation report
     */
    function generatePriceManipulationReport() internal view {
        console2.log("=== PRICE MANIPULATION AUDIT REPORT ===");
        console2.log("Total Manipulations Tested:", priceManipulations.length);
        
        uint256 totalPriceImpact = 0;
        uint256 criticalManipulations = 0;
        
        for (uint i = 0; i < priceManipulations.length; i++) {
            PriceManipulation memory manip = priceManipulations[i];
            
            console2.log("\nManipulation", i + 1, ":");
            console2.log("  Token:", manip.targetToken);
            console2.log("  Price Impact:", manip.priceImpact, "bps");
            console2.log("  Original Price:", manip.originalPrice);
            console2.log("  Manipulated Price:", manip.manipulatedPrice);
            
            totalPriceImpact += manip.priceImpact;
            
            if (manip.priceImpact > 1000) { // > 10% impact
                criticalManipulations++;
            }
        }
        
        if (priceManipulations.length > 0) {
            console2.log("\nSummary:");
            console2.log("  Average Price Impact:", totalPriceImpact / priceManipulations.length, "bps");
            console2.log("  Critical Manipulations (>10%):", criticalManipulations);
        }
        
        console2.log("=======================================");
    }
    
    /**
     * @notice Clean up after price manipulation tests
     */
    function cleanupManipulationTest() internal {
        // Reset all manipulations
        for (uint i = 0; i < priceManipulations.length; i++) {
            revertPriceManipulation(priceManipulations[i].targetToken);
        }
        
        // Clear manipulation history
        delete priceManipulations;
    }
}