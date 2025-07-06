-include .env

deploy:
	forge create src$(dir)/$(contract).sol:$(contract) \
		--rpc-url $(ZKSEPOLIA_RPC_URL) \
		--account myKey \
		--zksync \
		--constructor-args $(or $(args), "")

verify:
	forge verify-contract $(addr) src$(dir)/$(contract).sol:$(contract) \
		--verifier zksync \
		--verifier-url $(ZKSYNC_SEPOLIA_VERIFIER_API_KEY) \
		--zksync \
		--constructor-args $(shell cast abi-encode "constructor($(params))" $(args))
