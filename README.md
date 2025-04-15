# Intent Solver On Socket

This tutorial guides you through building an Intent Solver that runs on Socket's infrastructure while tapping into onchain liquidity vaults.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/getting-started/installation) installed
- An Ethereum wallet with ETH on Arbitrum Sepolia and Base Sepolia

## Environment Setup

Create a `.env` file with with the relevant variables found in `.env.example`

## Step 1: Deploy the SolverAppGateway

The SolverAppGateway contract runs the solver's logic as well as deployments of our onchain liquidity vaults and a wrapper contract around across protocol's SpokePool. Deploying these contracts through the SolverAppGateway allows us to (explain plugs and forward addresses)

```bash
forge script script/DeploySolverAppGateway.s.sol --broadcast --skip-simulation --legacy --with-gas-price 0 --via-ir
```

After deployment, locate the contract address in the console output:

```
SolverAppGateway contract: 0x...
```

Add this address to your environment:

```bash
export APP_GATEWAY=0x... # Your SolverAppGateway address
```

## Step 2: Fund Fee Balance

On chain as well as EVMx operations require fees. Since our system is configured to pay fees through Arbitrum Sepolia, we need to deposit ETH into the fee system:

```bash
forge script script/PayFeesInArbitrumEth.s.sol --broadcast --skip-simulation --via-ir
```

This deposits 0.05 ETH to the fee management system for your app gateway.

To verify your fee balance at any time:

```bash
forge script script/CheckFeesBalance.s.sol --broadcast --skip-simulation --via-ir
```

## Step 3: Deploy Onchain Contracts

Now we'll deploy the Vault as well as the SpokePoolWrapper to our target chains (Arbitrum Sepolia and Base Sepolia):

```bash
forge script script/DeployOnChainContracts.s.sol --broadcast --skip-simulation --legacy --with-gas-price 0 --via-ir
```

