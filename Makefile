-include .env

deploy:
	forge create src/$(contract).sol:$(contract) \
		--rpc-url $(ZKSEPOLIA_RPC_URL) \
		--account myKey \
		--zksync \
		--constructor-args $(args)

verify:
	forge verify-contract $(addr) src/$(contract).sol:$(contract) \
		--verifier zksync \
		--verifier-url $(ZKSYNC_SEPOLIA_VERIFIER_API_KEY) \
		--zksync \
		--constructor-args $(shell cast abi-encode "constructor($(params))" $(args))
