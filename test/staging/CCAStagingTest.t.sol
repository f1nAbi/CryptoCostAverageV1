// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {Test, console} from "forge-std/Test.sol";
import {DeployCryptoCostAverage} from "../../../script/DeployCryptoCostAverage.s.sol";
import {CryptoCostAverage} from "../../../src/CryptoCostAverage.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {HelperConfig} from "../../../script/HelperConfig.s.sol";

contract CCAStagingTest is Test {
    DeployCryptoCostAverage deployer;
    CryptoCostAverage cca;
    HelperConfig helperConfig;
    HelperConfig.NetworkConfig config;

    uint256 public constant INITIAL_USER_BALANCE = 100 ether;
    uint256 public constant INITIAL_USER_BALANCE2 = 50 ether;
    uint256 public constant WITHDRAW_AMOUNT = 10 ether;
    uint256 constant SWAP_AMOUNT = 10 ether;
    uint256 constant SWAP_AMOUNT2 = 20 ether;
    address public USER = makeAddr("user");
    address public USER2 = makeAddr("user2");

    address public s_testToken;
    address public s_testToken2;

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

    function testPerformUpkeepAndSwap2UsersAnd2Tokens() public {
        address owner = cca.owner();
        vm.prank(owner);
        cca.addToken(s_testToken2);

        vm.deal(USER, INITIAL_USER_BALANCE);
        vm.deal(USER2, INITIAL_USER_BALANCE2);

        vm.prank(USER);
        cca.depositEther{value: INITIAL_USER_BALANCE}();

        vm.prank(USER2);
        cca.depositEther{value: INITIAL_USER_BALANCE2}();

        vm.prank(USER);
        cca.setTokenForSwap(s_testToken, SWAP_AMOUNT);
        vm.prank(USER);
        cca.setTokenForSwap(s_testToken2, SWAP_AMOUNT);

        vm.prank(USER2);
        cca.setTokenForSwap(s_testToken, SWAP_AMOUNT);
        vm.prank(USER2);
        cca.setTokenForSwap(s_testToken2, SWAP_AMOUNT);

        address[] memory activeUsersBefore = cca.getActiveUsers();

        vm.warp(block.timestamp + cca.getInterval() + 1);
        cca.performUpkeep("");

        vm.warp(block.timestamp + cca.getInterval() + 1);
        cca.performUpkeep("");

        uint256 user2Token2BalanceBefore = IERC20(s_testToken2).balanceOf(USER2);
        vm.warp(block.timestamp + cca.getInterval() + 1);
        cca.performUpkeep("");

        uint256 user2Token2BalanceAfter = IERC20(s_testToken2).balanceOf(USER2);
        address[] memory activeUsersAfter = cca.getActiveUsers();

        assertEq(activeUsersBefore.length, 2);
        assertEq(activeUsersAfter.length, 1);
        assertEq(user2Token2BalanceAfter, user2Token2BalanceBefore);
    }
}
