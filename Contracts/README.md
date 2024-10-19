# ZLend Contracts


Try running some of the following tasks:

```shell
npx hardhat accounts --network dchain_t
npx hardhat compile
npx hardhat help
npx hardhat test
npx hardhat test --network localhost

npx hardhat node
npx hardhat coverage
npx hardhat run scripts/deploy.ts --network localhost
npx hardhat run scripts/deploy-zlend2.ts --network localhost
npx hardhat run scripts/deploy-zlend2.ts --network base_t
npx hardhat run scripts/deploy-zlend2.ts --network dchain_t

npx hardhat run scripts/deploy-faucet.ts --network base_t

GAS_REPORT=true npx hardhat test
npx hardhat node
npx hardhat run scripts/deploy.ts
```

- Base Sepolia Faucet @ 0xB962512F44a667e09770964e00eeAc47a9E6Fb74

# Static Analysis 
```
slither .
```

# Deploy

You can deploy in the localhost network following these steps:

    Start a local node

    npx hardhat node

    Open a new terminal and deploy the smart contract in the localhost network

    npx hardhat run --network localhost scripts/deploy.ts

As general rule, you can target any network configured in the hardhat.config.js

npx hardhat run --network <your-network> scripts/deploy.ts


