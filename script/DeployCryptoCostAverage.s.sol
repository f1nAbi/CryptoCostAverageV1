// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";
import {CryptoCostAverage} from "../src/CryptoCostAverage.sol";
import {HelperConfig} from "./HelperConfig.s.sol";

contract DeployCryptoCostAverage is Script {
    CryptoCostAverage cca;

    address public s_deployer;

    function deployCryptoCostAverage() public returns (CryptoCostAverage) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getDeployConfigByChainId();
        vm.startBroadcast(s_deployer);
        cca = new CryptoCostAverage(config.swapRouter, config.weth, config.supportedTokens, msg.sender);
        vm.stopBroadcast();
        return cca;
    }

    function run() public returns (CryptoCostAverage) {
        s_deployer = msg.sender;
        cca = deployCryptoCostAverage();
        return cca;
    }

    function getDeployer() public view returns (address) {
        return s_deployer;
    }
}
