# WARNING: THIS CONTRACT WAS NOT AUDITED BY PROFESSIONALS!
# -> USE AT OWN RISK!

# CryptoCostAverage

CryptoCostAverage is a smart contract that swaps ETH for ERC20 Tokens

## Description

Users can deposit ETH into the contract and specify the ERC20 Tokens and the amount of each token they want to automatically swap every 30 days. The contract uses Uniswap V3's SwapRouter and Chainlink Automation to facilitate the swaps. Uniswap is used for the swap calls, while Chainlink Automation ensures the swap function is executed automatically every 30 days. The swap function can only be executed once during each interval. The interval resets upon execution of the swaps.

**View Contract**

View Contract on Arbiscan:

https://arbiscan.io/address/0x90df18eeb8837e001de5f66bd48855f176ccaab5#code

Contract Address: 0x90df18EEb8837e001DE5f66BD48855F176CCaAB5

## Getting Started

### Dependencies
Make sure you have foundry installed:
https://book.getfoundry.sh/getting-started/installation

* **Chainlink Contracts** (for Chainlink Automation)
```
forge install smartcontractkit/chainlink-brownie-contracts --no-commit
```
* **Openzeppelin Contracts** (for ReentrancyGuard and Ownable)
```
forge install OpenZeppelin/openzeppelin-contracts --no-commit
```
* **Uniswap V3 Contracts** (for ISwapRouter)
```
forge install Uniswap/v3-periphery --no-commit
forge install Uniswap/v3-core --no-commit
```

### Testing Locally
* If you want to deploy locally on Anvil, you need to fork a blockchain that supports Uniswap V3 and Chainlink Automation (e.g., ETH Mainnet or Arbitrum One). To do this, you will need an API key from Alchemy (as in the example below) or any other blockchain node service (e.g., Infura).

* **Fork Mainnet**
```
forge test --fork-url https://eth-mainnet.g.alchemy.com/v2/<YOUR_ALCHEMY_API_KEY>
```
* **Fork Arbitrum One**s
```
forge test --fork-url https://arb-mainnet.g.alchemy.com/v2/<YOUR_ALCHEMY_API_KEY>
```

## Author

Name: Fin Nöthen

