// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {Script} from "forge-std/Script.sol";

contract HelperConfig is Script {
    error HelperConfig__InvalidChainId();

    struct NetworkConfig {
        address swapRouter;
        address weth;
        address[] supportedTokens;
    }

    uint256 public constant ANVIL_FORK_CHAIN_ID = 1;
    uint256 public constant ARBITRUM_CHAIN_ID = 42161;

    address public constant SWAP_ROUTER_MAINNET = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant WETH_MAINNET = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;
    address public constant LINK_TOKEN_MAINNET = 0x514910771AF9Ca656af840dff83E8264EcF986CA;
    address[] public s_supportedTokensMainnet = [LINK_TOKEN_MAINNET];

    address public constant SWAP_ROUTER_ARBITRUM = 0xE592427A0AEce92De3Edee1F18E0157C05861564;
    address public constant WETH_ARBITRUM = 0x82aF49447D8a07e3bd95BD0d56f35241523fBab1;
    address public constant LINK_TOKEN_ARBITRUM = 0xf97f4df75117a78c1A5a0DBb814Af92458539FB4;
    address[] public s_supportedTokensArbitrum = [LINK_TOKEN_ARBITRUM];

    function getDeployConfigByChainId() public view returns (NetworkConfig memory) {
        if (block.chainid == ANVIL_FORK_CHAIN_ID) {
            return AnvilDeployConfig();
        } else if (block.chainid == ARBITRUM_CHAIN_ID) {
            return ArbitrumDeployConfig();
        } else {
            revert HelperConfig__InvalidChainId();
        }
    }

    function AnvilDeployConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory anvilConfig = NetworkConfig({
            swapRouter: SWAP_ROUTER_MAINNET,
            weth: WETH_MAINNET,
            supportedTokens: s_supportedTokensMainnet
        });
        return anvilConfig;
    }

    function ArbitrumDeployConfig() public view returns (NetworkConfig memory) {
        NetworkConfig memory arbitrumConfig = NetworkConfig({
            swapRouter: SWAP_ROUTER_ARBITRUM,
            weth: WETH_ARBITRUM,
            supportedTokens: s_supportedTokensArbitrum
        });
        return arbitrumConfig;
    }
}
