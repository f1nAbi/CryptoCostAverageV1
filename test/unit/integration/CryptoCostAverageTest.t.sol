// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DeployCryptoCostAverage} from "../../../script/DeployCryptoCostAverage.s.sol";
import {CryptoCostAverage} from "../../../src/CryptoCostAverage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";

contract CryptoCostAverageTest is Test {
    DeployCryptoCostAverage deployer;
    CryptoCostAverage cca;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;

    uint256 public constant INITIAL_USER_BALANCE = 100 ether;
    uint256 public constant WITHDRAW_AMOUNT = 10 ether;
    uint256 constant SWAP_AMOUNT = 10 ether;
    uint256 constant SWAP_AMOUNT2 = 20 ether;
    address public USER = makeAddr("user");

    address public s_testToken;
    address public s_testToken2;

    modifier ethDeposited() {
        // Deposit Ether by calling depositEther function by test user
        vm.deal(USER, INITIAL_USER_BALANCE);
        vm.prank(USER);
        cca.depositEther{value: INITIAL_USER_BALANCE}();
        _;
    }

    function setUp() public {
        deployer = new DeployCryptoCostAverage();
        cca = deployer.run();
        helperConfig = new HelperConfig();
        config = helperConfig.getDeployConfigByChainId();
        s_testToken = config.supportedTokens[0];
        if (block.chainid == 1) {
            s_testToken2 = 0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599; // WBTC Contract Address on Mainnet
        } else if (block.chainid == 42161) {
            s_testToken2 = 0x2f2a2543B76A4166549F7aaB2e75Bef0aefC5B0f; // WBTC Contract Address on Arbitrum
        } else {
            revert("Chain ID not supported");
        }
    }

    function testDepositEther() public ethDeposited {
        // Test if the user has been added to the s_users array and the user balance has been updated
        assertEq(cca.s_users(0), USER);
        assertEq(cca.getUserBalance(USER), INITIAL_USER_BALANCE);
        assertEq(address(cca).balance, INITIAL_USER_BALANCE);
    }

    function testWithdrawEther() public ethDeposited {
        // Withdraw Ether calling the withdrawEther function as a test user
        uint256 userBalanceBefore = USER.balance;
        vm.prank(USER);
        cca.withdrawEther(WITHDRAW_AMOUNT);
        uint256 userBalanceAfter = USER.balance;

        assertEq(cca.getUserBalance(USER), INITIAL_USER_BALANCE - WITHDRAW_AMOUNT);
        assertEq(userBalanceAfter, userBalanceBefore + WITHDRAW_AMOUNT);
    }

    function testWithdrawEtherFailsWithWrongWithdrawAmount() public ethDeposited {
        // Withdraw Ether by calling the withdrawEther function as a test user
        vm.prank(USER);
        vm.expectRevert();
        cca.withdrawEther(INITIAL_USER_BALANCE + 1);
    }

    function testSetsTokenForSwapToAmount() public ethDeposited {
        // Set swap amount for test token by calling setTokenForSwap function by test user
        vm.prank(USER);
        cca.setTokenForSwap(s_testToken, SWAP_AMOUNT);
        uint256 userSwapAmountTestToken = cca.getUserTokensToSwapAmount(USER, s_testToken);
        address[] memory userTokens = cca.getUserTokens(USER);
        uint256 userFundsInSwaps = cca.getUserFundsInSwaps(USER);
        address[] memory activeUsers = cca.getActiveUsers();

        assertEq(userSwapAmountTestToken, SWAP_AMOUNT);
        assertEq(userTokens[0], s_testToken);
        assertEq(userTokens.length, 1);
        assertEq(userFundsInSwaps, SWAP_AMOUNT);
        assertEq(activeUsers[0], USER);
    }

    function testSetsTokenForSwapToAmountFailsSwapAmountIsAlreadySet() public ethDeposited {
        // Set swap amount for test token by calling setTokenForSwap function by test user
        vm.prank(USER);
        cca.setTokenForSwap(s_testToken, SWAP_AMOUNT);

        vm.prank(USER);
        vm.expectRevert();
        cca.setTokenForSwap(s_testToken, SWAP_AMOUNT);
    }

    function testSetsTokenForSwapToAmountFailsIfTokenIsNotSupported() public ethDeposited {
        // Set swap amount for test token by calling setTokenForSwap function by test user
        vm.prank(USER);
        vm.expectRevert();
        cca.setTokenForSwap(makeAddr("notSupportedToken"), SWAP_AMOUNT);
    }

    function testSetsTokenForSwapToAmountFailsWhenNotEnoughFunds() public ethDeposited {
        // Set swap amount for test token by calling setTokenForSwap function by test user
        vm.prank(USER);
        vm.expectRevert();
        cca.setTokenForSwap(s_testToken, INITIAL_USER_BALANCE + 1);
    }

    function testSetsTokenForSwapToAmountFailsWhenAmountIsZero() public ethDeposited {
        // Set swap amount for test token by calling setTokenForSwap function by test user
        vm.prank(USER);
        vm.expectRevert();
        cca.setTokenForSwap(s_testToken, 0);
    }

    function testRemoveTokenForUserSwap() public ethDeposited {
        vm.prank(USER);
        cca.setTokenForSwap(s_testToken, SWAP_AMOUNT);

        vm.prank(USER);
        cca.removeTokenForUserSwap(s_testToken);
        uint256 userSwapAmountTestTokenAfterRemoval = cca.getUserTokensToSwapAmount(USER, s_testToken);
        uint256 userFundsInSwaps = cca.getUserFundsInSwaps(USER);
        address[] memory userTokens = cca.getUserTokens(USER);
        address[] memory activeUsers = cca.getActiveUsers();

        assertEq(userSwapAmountTestTokenAfterRemoval, 0);
        assertEq(userFundsInSwaps, 0);
        assertEq(userTokens.length, 0);
        assertEq(activeUsers.length, 0);
    }

    function testRemoveTokenForUserSwapFailsSwapAmountIsNotSet() public ethDeposited {
        vm.prank(USER);
        vm.expectRevert();
        cca.removeTokenForUserSwap(s_testToken);
    }

    function testRemoveTokenForUserSwapFailsIfTokenIsNotSupported() public ethDeposited {
        vm.prank(USER);
        vm.expectRevert();
        cca.removeTokenForUserSwap(makeAddr("notSupportedToken"));
    }

    function testAddToken() public {
        address owner = cca.owner();
        vm.prank(owner);
        cca.addToken(s_testToken2);

        address[] memory supportedTokens = cca.getSupportedTokens();

        assertEq(supportedTokens[1], s_testToken2);
        assertEq(supportedTokens.length, 2);
    }

    function testAddTokenFailsIfNotOwner() public {
        vm.prank(USER);
        vm.expectRevert();
        cca.addToken(s_testToken2);
    }

    function testAddTokenFailsIfInvalidToken() public {
        address owner = cca.owner();
        vm.prank(owner);
        vm.expectRevert();
        cca.addToken(makeAddr("invalidToken"));
    }

    function testRemoveToken() public {
        address owner = cca.owner();
        vm.prank(owner);
        cca.addToken(s_testToken2);

        vm.prank(owner);
        cca.removeToken(s_testToken2);

        address[] memory supportedTokens = cca.getSupportedTokens();

        assertEq(supportedTokens.length, 1);
        assertEq(supportedTokens[0], s_testToken);
    }

    function testChangePoolFee() public {
        address owner = cca.owner();
        vm.prank(owner);
        cca.changePoolFee(100);

        uint256 poolFee = cca.getPoolFee();

        assertEq(poolFee, 100);
    }

    function testCheckUpkeepReturnsFalseWhenTimeHasNotPassed() public ethDeposited {
        vm.prank(USER);
        cca.setTokenForSwap(s_testToken, SWAP_AMOUNT);

        (bool upkeepNeeded,) = cca.checkUpkeep("");

        assertEq(upkeepNeeded, false);
    }

    function testCheckUpkeepReturnsFalseWhenNoActiveUsers() public {
        vm.warp(block.timestamp + cca.getInterval() + 1);
        (bool upkeepNeeded,) = cca.checkUpkeep("");

        assertEq(upkeepNeeded, false);
    }

    function testCheckUpkeepReturnsTrueIfTimeHasPassedAndActiveUsers() public ethDeposited {
        vm.prank(USER);
        cca.setTokenForSwap(s_testToken, SWAP_AMOUNT);

        vm.warp(block.timestamp + cca.getInterval() + 1);
        (bool upkeepNeeded,) = cca.checkUpkeep("");

        assertEq(upkeepNeeded, true);
    }

    function testPerformUpkeepAndSwap() public ethDeposited {
        // Add test token 2
        address owner = cca.owner();
        console.log("Owner: ", owner);
        vm.prank(owner);
        cca.addToken(s_testToken2);

        vm.prank(USER);
        cca.setTokenForSwap(s_testToken, SWAP_AMOUNT);
        vm.prank(USER);
        cca.setTokenForSwap(s_testToken2, SWAP_AMOUNT2);

        uint256 lastTimestampBefore = cca.getLastTimestamp();
        uint256 userBalanceBefore = cca.getUserBalance(USER);
        uint256 testTokenBalanceBefore = IERC20(s_testToken).balanceOf(USER);
        uint256 testToken2BalanceBefore = IERC20(s_testToken2).balanceOf(USER);
        vm.warp(block.timestamp + cca.getInterval() + 1);
        cca.performUpkeep("");

        uint256 lastTimestampAfter = cca.getLastTimestamp();
        uint256 userBalanceAfter = cca.getUserBalance(USER);
        uint256 testTokenBalanceAfter = IERC20(s_testToken).balanceOf(USER);
        uint256 testToken2BalanceAfter = IERC20(s_testToken2).balanceOf(USER);

        assertGt(lastTimestampAfter, lastTimestampBefore);
        assertEq(userBalanceAfter, userBalanceBefore - SWAP_AMOUNT - SWAP_AMOUNT2);
        assertGt(testTokenBalanceAfter, testTokenBalanceBefore);
        assertGt(testToken2BalanceAfter, testToken2BalanceBefore);
    }

    function testPerformUpkeepFailsIfNoUpkeepNeeded() public ethDeposited {
        vm.expectRevert();
        cca.performUpkeep("");
    }

    function testPerformUpkeepRemovesActiveUserIfSwapAmountsExceedsUserBalance() public ethDeposited {
        vm.prank(USER);
        cca.setTokenForSwap(s_testToken, SWAP_AMOUNT - 1e18);
        uint256 swaps = 11;

        for (uint256 i = 0; i < swaps; i++) {
            vm.warp(block.timestamp + cca.getInterval() + 1);
            cca.performUpkeep("");
        }

        assertEq(cca.getActiveUsers().length, 0);
    }

    //////////////////////////
    // Test Getter Functions//
    //////////////////////////

    function testGetUserBalance() public ethDeposited {
        // Get the user balance
        uint256 userBalance = cca.getUserBalance(USER);
        assertEq(userBalance, INITIAL_USER_BALANCE);
    }

    function testGetActiveSwaps() public ethDeposited {
        // Set swap amount by calling setTokenForSwap function by test user
        vm.prank(USER);
        cca.setTokenForSwap(s_testToken, SWAP_AMOUNT);

        // Get the active swaps
        address[] memory activeSwaps = cca.getActiveSwaps(USER);
        assertEq(activeSwaps[0], s_testToken);
    }

    function testGetActiveUsers() public ethDeposited {
        // Set swap amount by calling setTokenForSwap function by test user
        vm.prank(USER);
        cca.setTokenForSwap(s_testToken, SWAP_AMOUNT);

        // Get the active users
        address[] memory activeUsers = cca.getActiveUsers();
        assertEq(activeUsers[0], USER);
    }

    function testGetSupportedTokens() public view {
        // Get the supported tokens
        address[] memory supportedTokens = cca.getSupportedTokens();
        assertEq(supportedTokens[0], s_testToken);
    }

    function getUserTokensToSwapAmount() public ethDeposited {
        // Set swap amount by calling setTokenForSwap function by test user
        vm.prank(USER);
        cca.setTokenForSwap(s_testToken, SWAP_AMOUNT);

        // Get the user swap amount
        uint256 userSwapAmount = cca.getUserTokensToSwapAmount(USER, s_testToken);
        assertEq(userSwapAmount, SWAP_AMOUNT);
    }

    function testGetISwapRouter() public view {
        // Get the ISwapRouter address
        address iSwapRouter = cca.getISwapRouter();
        assertEq(iSwapRouter, config.swapRouter);
    }

    function testGetWeth() public view {
        // Get the WETH address
        address weth = cca.getWeth();
        assertEq(weth, config.weth);
    }

    function testGetUserFundsInSwaps() public ethDeposited {
        address owner = cca.owner();
        vm.prank(owner);
        cca.addToken(s_testToken2);

        vm.prank(USER);
        cca.setTokenForSwap(s_testToken, SWAP_AMOUNT);

        vm.prank(USER);
        cca.setTokenForSwap(s_testToken2, SWAP_AMOUNT);

        uint256 userFundsInSwaps = cca.getUserFundsInSwaps(USER);

        assertEq(userFundsInSwaps, SWAP_AMOUNT * 2);
    }

    function testGetInterval() public view {
        // Get the interval
        uint256 expectedInterval = 30 days;
        uint256 interval = cca.getInterval();
        assertEq(interval, expectedInterval);
    }

    function testGetUserTokens() public ethDeposited {
        // Set swap amount by calling setTokenForSwap function by test user
        vm.prank(USER);
        cca.setTokenForSwap(s_testToken, SWAP_AMOUNT);

        // Get the user tokens
        address[] memory userTokens = cca.getUserTokens(USER);
        assertEq(userTokens[0], s_testToken);
    }

    function testGetPoolFee() public view {
        // Get the pool fee
        uint256 expectedPoolFee = 3000;
        uint256 poolFee = cca.getPoolFee();
        assertEq(poolFee, expectedPoolFee);
    }
}
