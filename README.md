# ZLend 
## DeFi Over/Under/Un Collaterized Lending 
DeFi Lending platform which lets you lend, borrow crypto assets and helps you earn some passive income as interest on your deposits. 

ZK Proofs store your credit rating

Depositors are rewarded with zLend tokens for depositing into the Lending Pool. Depositors will also be able to share from the interest made on the platforms from loans.

### Screenshot
![Home](https://github.com/layinka/zLend/assets/629572/685ce6ce-ac1b-4174-bc37-f95e230e700e)


### Demo Video
[Youtube Demo ](https://youtu.be/S8yzoSFpWs8)

## Networks supported
zLend is supported on
- Base Sepolia Testnet

- Base Sepolia Faucet @ 0xB962512F44a667e09770964e00eeAc47a9E6Fb74


# Features
1. Supported tokens are dependent on Network
2. Depositors supply some tokens to the pool to provide liquidity or collateral for loans.
3. Depositors get rewarded with ZLend token when they supply to the pool. Reward is calculated based on the token amount in dollars users supplied to the pool.
4. To borrow from the pool, User has to deposit collateral. Loans are over collaterized, and LTV (Loan To Value) ratio varies from coin to coin and user to user
5. The contract currently supports only stable APY rate for all tokens that can be borrowed.
6. On debt repayment, the interest and token borrowed is retrieved from the user. Interest is calculated based on stable APY rate. 
7. After repayment, user can withdraw the tokens staked as collateral from lending pool.
8. On withdrawal from lending pool, contract also collects some ZLend tokens rewarded to the user. The ZLend token that will be collected from the user is equivalent in value to the amount of token user wants to withdraw.

# Tools
1. **Open Zeppelin**
2. **Chainlink/Redstone**
3. **Hardhat**
4. **Ethers Js/WAGMI/VIEM** 
5. **Wallet Connect/ Coinbase wallet/ Web3Modal**



