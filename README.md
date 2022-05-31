## NFTPool.Exchange

Uniswap style AMM pools for ERC-1155 NFTs & aDAI Pairs, making NFT Market more liquid!

---

### For Traders:

* Traditionally with order-book system, the bids take long to fill out. But here the trade happens instantly and the arbitrageurs are incentivized to keep the pool prices in sync.
* Specially useful for blockchain-based games where the accessories are NFTs and users just want to trade them directly.

### For Liquidity Providers:

* Deposit ERC1155 NFT and DAI in equal values to the pool
* AaveHelper Contract takes care of Depositing DAI into Aave, minting aDAI and then Depositing NFT & aDAI into the Pool. LP tokens are minted and sent to the user.
* Liquidity providers earn 0.3% on all trades on top of the Lending interest from Aave.
* As the LP tokens are liquid ERC20s, so this opens up a whole new set of opportunities like yield-farming, using it as collateral and more!

---
_(Not Audited. Only suitable for testnet deployments)_
