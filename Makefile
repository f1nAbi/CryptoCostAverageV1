.PHONY: all test clean deploy fund help install snapshot format anvil zktest cast

ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

anvil:
	@anvil --fork-url https://arb-mainnet.g.alchemy.com/v2/qsvFzQM1p5j57CKLsxmepjUJTYJREPkV
deploy:
	@forge script script/DeployCryptoCostAverage.s.sol:DeployCryptoCostAverage --rpc-url http://127.0.0.1:8545 --private-key $(ANVIL_KEY) --broadcast