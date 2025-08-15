// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "forge-std/console2.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title CompoundHelpers
 * @notice Helper functions for interacting with Compound V2 protocol during security audits
 * @dev Provides abstracted methods for supply, borrow, liquidate operations
 */

// Compound V2 Interfaces
interface ICToken {
    function mint(uint mintAmount) external returns (uint);
    function redeem(uint redeemTokens) external returns (uint);
    function redeemUnderlying(uint redeemAmount) external returns (uint);
    function borrow(uint borrowAmount) external returns (uint);
    function repayBorrow(uint repayAmount) external returns (uint);
    function liquidateBorrow(address borrower, uint repayAmount, ICToken cTokenCollateral) external returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function balanceOfUnderlying(address owner) external returns (uint);
    function borrowBalanceCurrent(address account) external returns (uint);
    function borrowBalanceStored(address account) external view returns (uint);
    function exchangeRateCurrent() external returns (uint);
    function exchangeRateStored() external view returns (uint);
    function underlying() external view returns (address);
    function getCash() external view returns (uint);
    function totalSupply() external view returns (uint);
    function totalBorrows() external view returns (uint);
    function totalReserves() external view returns (uint);
    function accrueInterest() external returns (uint);
    function supplyRatePerBlock() external view returns (uint);
    function borrowRatePerBlock() external view returns (uint);
}

interface IComptroller {
    function enterMarkets(address[] calldata cTokens) external returns (uint[] memory);
    function exitMarket(address cToken) external returns (uint);
    function getAccountLiquidity(address account) external view returns (uint, uint, uint);
    function liquidationIncentiveMantissa() external view returns (uint);
    function closeFactorMantissa() external view returns (uint);
    function markets(address cToken) external view returns (bool, uint, bool);
    function getAssetsIn(address account) external view returns (address[] memory);
    function checkMembership(address account, ICToken cToken) external view returns (bool);
    function liquidateCalculateSeizeTokens(
        address cTokenBorrowed,
        address cTokenCollateral,
        uint repayAmount
    ) external view returns (uint, uint);
}

interface IPriceOracle {
    function getUnderlyingPrice(ICToken cToken) external view returns (uint);
}

contract CompoundHelpers is Test {
    
    // Note: Protocol contracts are defined in AuditBase.sol
    // Using typed interface wrappers for convenience
    function getComptroller() internal pure returns (IComptroller) {
        return IComptroller(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    }
    
    function getPriceOracle() internal pure returns (IPriceOracle) {
        return IPriceOracle(0x046728da7cb8272284238bD3e47909823d63A58D);
    }
    
    // Error codes from Compound
    uint constant NO_ERROR = 0;
    uint constant INSUFFICIENT_LIQUIDITY = 3;
    uint constant INSUFFICIENT_SHORTFALL = 4;
    uint constant PRICE_ERROR = 13;
    
    /**
     * @notice Supply tokens to Compound and enter the market
     * @dev Handles both ERC20 tokens and ETH
     */
    function supplyToCompound(
        address user,
        ICToken cToken,
        uint256 amount
    ) internal returns (bool success) {
        vm.startPrank(user);
        
        address underlying = getUnderlying(cToken);
        
        if (underlying == address(0)) {
            // Handle ETH (cETH)
            (bool sent, ) = address(cToken).call{value: amount}("");
            require(sent, "Failed to send ETH");
        } else {
            // Handle ERC20 tokens
            IERC20(underlying).approve(address(cToken), amount);
            uint result = cToken.mint(amount);
            require(result == NO_ERROR, "Mint failed");
        }
        
        // Enter market
        address[] memory markets = new address[](1);
        markets[0] = address(cToken);
        uint[] memory results = getComptroller().enterMarkets(markets);
        require(results[0] == NO_ERROR, "Enter market failed");
        
        vm.stopPrank();
        return true;
    }
    
    /**
     * @notice Borrow tokens from Compound
     */
    function borrowFromCompound(
    address user,
    ICToken cToken,
    uint256 amount
) internal returns (bool success) {
    vm.startPrank(user);
    
    uint result = cToken.borrow(amount);
    
    vm.stopPrank();
    
    if (result == NO_ERROR) {
        return true;
    } else {
        console2.log("Borrow failed with error:", result);
        console2.log("Error meaning:", debugBorrowFailure(result));
        return false;
    }
}

    
    /**
     * @notice Redeem tokens from Compound
     */
    function redeemFromCompound(
        address user,
        ICToken cToken,
        uint256 amount,
        bool redeemTokens // true = redeem cTokens, false = redeem underlying
    ) internal returns (bool success) {
        vm.startPrank(user);
        
        uint result;
        if (redeemTokens) {
            result = cToken.redeem(amount);
        } else {
            result = cToken.redeemUnderlying(amount);
        }
        require(result == NO_ERROR, "Redeem failed");
        
        vm.stopPrank();
        return true;
    }
    
    /**
     * @notice Repay borrowed tokens
     */
    function repayToCompound(
        address user,
        ICToken cToken,
        uint256 amount
    ) internal returns (bool success) {
        vm.startPrank(user);
        
        address underlying = getUnderlying(cToken);
        
        if (underlying != address(0)) {
            IERC20(underlying).approve(address(cToken), amount);
        }
        
        uint result = cToken.repayBorrow(amount);
        require(result == NO_ERROR, "Repay failed");
        
        vm.stopPrank();
        return true;
    }
    
    /**
     * @notice Liquidate an undercollateralized position
     */
    function liquidatePosition(
    address liquidator,
    address borrower,
    ICToken cTokenBorrowed,
    uint256 repayAmount,
    ICToken cTokenCollateral
) internal returns (uint256 seizeTokens) {
    vm.startPrank(liquidator);
    
    address underlying = getUnderlying(cTokenBorrowed);
    
    if (underlying != address(0)) {
        IERC20(underlying).approve(address(cTokenBorrowed), repayAmount);
    }
    
    uint result = cTokenBorrowed.liquidateBorrow(borrower, repayAmount, cTokenCollateral);
    
    vm.stopPrank();
    
    if (result == NO_ERROR) {
        // Calculate seized tokens
        (, seizeTokens) = getComptroller().liquidateCalculateSeizeTokens(
            address(cTokenBorrowed),
            address(cTokenCollateral),
            repayAmount
        );
        return seizeTokens;
    } else {
        console2.log("Liquidation failed with error:", result);
        console2.log("Error meaning:", debugBorrowFailure(result));
        return 0;
    }
}

    
    /**
     * @notice Get account liquidity information
     */
    function getAccountLiquidity(address user) internal view returns (
        uint256 liquidity,
        uint256 shortfall
    ) {
        (uint error, uint _liquidity, uint _shortfall) = getComptroller().getAccountLiquidity(user);
        require(error == NO_ERROR, "Failed to get account liquidity");
        
        return (_liquidity, _shortfall);
    }
    
    /**
     * @notice Check if account is liquidatable
     */
    function isLiquidatable(address user) internal view returns (bool) {
        (, uint shortfall) = getAccountLiquidity(user);
        return shortfall > 0;
    }
    
    /**
     * @notice Calculate maximum liquidation amount
     */
    function getMaxLiquidationAmount(
        address borrower,
        ICToken cTokenBorrowed
    ) internal returns (uint256 maxRepay) {
        uint borrowBalance = cTokenBorrowed.borrowBalanceCurrent(borrower);
        uint closeFactor = getComptroller().closeFactorMantissa();
        
        // Max liquidation is close factor * borrow balance
        maxRepay = (borrowBalance * closeFactor) / 1e18;
        
        return maxRepay;
    }
    
    /**
     * @notice Get underlying token address (returns 0x0 for ETH)
     */
    function getUnderlying(ICToken cToken) internal view returns (address) {
        // For cETH, this call will revert, so we catch it
        try cToken.underlying() returns (address underlying) {
            return underlying;
        } catch {
            return address(0); // ETH
        }
    }
    
    /**
     * @notice Get current exchange rate for cToken
     */
    function getExchangeRate(ICToken cToken) internal returns (uint256) {
        return cToken.exchangeRateCurrent();
    }
    
    /**
     * @notice Get token price from oracle
     */
    function getTokenPrice(ICToken cToken) internal view returns (uint256) {
        return getPriceOracle().getUnderlyingPrice(cToken);
    }
    
    /**
     * @notice Calculate collateral value in USD
     */
    function calculateCollateralValue(
        address user,
        ICToken cToken
    ) internal returns (uint256 valueUSD) {
        uint cTokenBalance = cToken.balanceOf(user);
        uint exchangeRate = getExchangeRate(cToken);
        uint price = getTokenPrice(cToken);
        
        // Convert cToken balance to underlying amount
        uint underlyingAmount = (cTokenBalance * exchangeRate) / 1e18;
        
        // Calculate USD value (price is scaled by 1e18)
        valueUSD = (underlyingAmount * price) / 1e18;
        
        return valueUSD;
    }
    
    /**
     * @notice Calculate borrow value in USD
     */
    function calculateBorrowValue(
        address user,
        ICToken cToken
    ) internal returns (uint256 valueUSD) {
        uint borrowBalance = cToken.borrowBalanceCurrent(user);
        uint price = getTokenPrice(cToken);
        
        // Calculate USD value
        valueUSD = (borrowBalance * price) / 1e18;
        
        return valueUSD;
    }
    
    /**
     * @notice Get all markets a user has entered
     */
    function getUserMarkets(address user) internal view returns (address[] memory) {
        return getComptroller().getAssetsIn(user);
    }
    
    /**
     * @notice Accrue interest on cToken before operations
     */
    function accrueInterest(ICToken cToken) internal {
        uint result = cToken.accrueInterest();
        require(result == NO_ERROR, "Failed to accrue interest");
    }
    
    /**
     * @notice Emergency function to exit all markets (for testing cleanup)
     */
    function exitAllMarkets(address user) internal {
        vm.startPrank(user);
        
        address[] memory markets = getUserMarkets(user);
        for (uint i = 0; i < markets.length; i++) {
            getComptroller().exitMarket(markets[i]);
        }
        
        vm.stopPrank();
    }
    
    /**
     * @notice Debug helper to interpret Compound error codes
     */
    function debugBorrowFailure(uint errorCode) internal pure returns (string memory) {
        if (errorCode == 0) return "NO_ERROR";
        if (errorCode == 1) return "UNAUTHORIZED";
        if (errorCode == 2) return "BAD_INPUT";
        if (errorCode == 3) return "COMPTROLLER_REJECTION";
        if (errorCode == 4) return "COMPTROLLER_CALCULATION_ERROR";
        if (errorCode == 5) return "INTEREST_RATE_MODEL_ERROR";
        if (errorCode == 6) return "INVALID_ACCOUNT_PAIR";
        if (errorCode == 7) return "INVALID_CLOSE_AMOUNT_REQUESTED";
        if (errorCode == 8) return "INVALID_COLLATERAL_FACTOR";
        if (errorCode == 9) return "MATH_ERROR";
        if (errorCode == 10) return "MARKET_NOT_FRESH";
        if (errorCode == 11) return "MARKET_NOT_LISTED";
        if (errorCode == 12) return "TOKEN_INSUFFICIENT_ALLOWANCE";
        if (errorCode == 13) return "TOKEN_INSUFFICIENT_BALANCE";
        if (errorCode == 14) return "TOKEN_INSUFFICIENT_CASH";
        if (errorCode == 15) return "TOKEN_TRANSFER_IN_FAILED";
        if (errorCode == 16) return "TOKEN_TRANSFER_OUT_FAILED";
        return "UNKNOWN_ERROR";
    }

    /**
     * @notice Print detailed account information for debugging
     */
    function printAccountInfo(address user, string memory label) internal {
        console2.log("=== Account Info:", label, "===");
        console2.log("Address:", user);
        
        (uint liquidity, uint shortfall) = getAccountLiquidity(user);
        console2.log("Liquidity:", liquidity);
        console2.log("Shortfall:", shortfall);
        console2.log("Is Liquidatable:", isLiquidatable(user));
        
        address[] memory markets = getUserMarkets(user);
        console2.log("Markets entered:", markets.length);
        
        for (uint i = 0; i < markets.length; i++) {
            ICToken cToken = ICToken(markets[i]);
            console2.log("Market:", markets[i]);
            console2.log("  cToken Balance:", cToken.balanceOf(user));
            console2.log("  Borrow Balance:", cToken.borrowBalanceStored(user));
        }
        
        console2.log("==============================");
    }
}