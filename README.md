# Building an Intent Solver on Socket: Step-by-Step Guide

This guide demonstrates how to build an Intent Solver strategy on Socket Protocol that taps into on-chain vault liquidity to fill cross-chain intents.

## Overview

In this tutorial, we'll implement a solver that:
1. Is hosted by socket's trust minimized infrastructure
2. Listens for intents submitted ot the across protocol
2. Taps into on-chain vault liquidity to fill intents on the destination chain

The purpose of this tutorial is to demonstrate how this can e built on Socket and demonstrate the end to end flow. The supported flow here is an intent issued on Arbitrum Sepolia to send WETH to Base Sepolia.


## Architecture

The system consists of three main components:

1. **SpokePoolWrapper**: A wrapper around Across Protocol's SpokePool that acts as a Socket Plug
2. **WETHVault**: An ERC4626-compliant vault that provides the liquidity needed to fill intents
3. **SolverAppGateway**: The coordinator that runs the solver strategy to match intents with liquidity

## Project Structure

```
├── src/
│   ├── SpokePoolWrapper.sol  - Wrapper for Across Protocol SpokePool
│   ├── Vault.sol             - ERC4626 vault plug
│   ├── SolverAppGateway.sol  - Gateway for cross chain communication and running solver strategy
│   ├── interfaces/           - Contract interfaces
│   │   ├── IVault.sol
│   │   └── across/
│   ├── libraries/            - Utility libraries
├── script/                   - Deployment and interaction scripts
└── foundry.toml              - Foundry configuration
```

## Prerequisites

- [Foundry](https://getfoundry.sh/) installed
- Testnet ETH on Arbitrum Sepolia and Base Sepolia
- A WETH balance on BaseSepolia


## Step 1: Set Up Environment

1. Clone the repository and install dependencies:
   ```bash
   cd socket-vault
   forge install
   ```

2. Copy the `.env.example` file and add your configuration:
   ```bash
   cp .env.example .env
   ```

3. Fill the following variables in your `.env` file:
   ```
   PRIVATE_KEY=<your-private-key>
   RPC_421614=<arbitrum-sepolia-rpc-url>
   RPC_84532=<base-sepolia-rpc-url>
   ```

## Step 2: Deploy the Solver App Gateway

The SolverAppGateway serves as the coordinator for our solver strategy:

```bash
forge script script/DeploySolverAppGateway.s.sol --broadcast --skip-simulation --legacy --with-gas-price 0 --via-ir --evm-version paris
```

After deployment, locate the contract address in the console output and add it to your `.env` file:

```
APP_GATEWAY=<deployed-app-gateway-address>
```

## Step 3: Fund Fee Balance for Socket Operations

Socket operations require fees to be paid. Deposit ETH to the fee management system:

```bash
forge script script/PayFeesInArbitrumEth.s.sol --broadcast --skip-simulation --via-ir
```

This deposits 0.05 ETH to the fee management system for your app gateway.

You can check your fee balance at any time:

```bash
forge script script/CheckFeesBalance.s.sol --broadcast --skip-simulation --via-ir
```

## Step 4: Deploy On-Chain Components

Next, deploy the vault and SpokePoolWrapper on both chains:

1. Deploy on Base Sepolia:
   ```bash
   source .env && cast send $APP_GATEWAY "deployContracts(uint32,address,string,string)" 84532 0x4200000000000000000000000000000000000006 'WETH Vault' 'vWETH' --private-key $PRIVATE_KEY --legacy --gas-price 0 --gas-limit 120000000 --rpc-url $EVMX_RPC
   ```

2. Deploy on Arbitrum Sepolia:
   ```bash
   source .env && cast send $APP_GATEWAY "deployContracts(uint32,address,string,string)" 421614 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73 'WETH Vault' 'vWETH' --private-key $PRIVATE_KEY --legacy --gas-price 0 --gas-limit 120000000 --rpc-url $EVMX_RPC
   ```

3. Get the on-chain addresses of your deployed contracts:
   ```bash
   forge script script/GetOnChainAddress.s.sol --broadcast --skip-simulation --via-ir
   ```

   Take note of the deployed vault addresses and add the Base Sepolia vault address to your `.env` file:
   ```
   VAULT_84532=<base-sepolia-vault-address>
   ```

## Step 5: Fund the Vault with Liquidity

The vault needs funds to be able to fill intents. Deposit WETH into the vault on Base Sepolia:

```bash
forge script script/DepositInVault.s.sol --broadcast --skip-simulation --via-ir
```

This script deposits 0.05 WETH into your vault, which will be used to fill  intents.

## Step 6: Submit an Intent (Test the Flow)

Now, let's test the full flow by submitting an intent through the SpokePoolWrapper:

```bash
forge script script/DepositInSpokePoolWrapper.s.sol:DepositInSpokePoolWrapper --sig "run(uint256,uint256)" 421614 84532 --broadcast
```

This command:
1. Creates a deposit (intent) on Arbitrum Sepolia (chain ID 421614)
2. Targets Base Sepolia (chain ID 84532) as the destination

## Under the Hood - How It Works

When you submit an intent through the SpokePoolWrapper, the following sequence occurs:

1. **Intent Creation**: 
   - The `deposit` function on SpokePoolWrapper is called with parameters specifying the Arbitrum to Sepolia WETH transfer
   - SpokePoolWrapper forwards this to Across Protocol's SpokePool
   - It also notifies the SolverAppGateway via Socket Protocol

2. **Intent Detection**:
   - The SolverAppGateway receives the notification via Socket's `callFromChain` function
   - It decodes the payload to extract the deposit parameters
   - The gateway validates that this is an intent it can fill

3. **Liquidity Provision**:
   - The gateway calls the WETHVault on the destination chain
   - The vault's `executeIntent` function is triggered
   - The vault checks that it has sufficient liquidity

4. **Intent Execution**:
   - The vault approves tokens for the Across SpokePool
   - It calls `fillRelay` on the SpokePool to complete the transfer

5. **Completion**:
   - The recipient receives their funds on the destination chain
   - The intent gets settled via across protocol settlement mechanism

## Step 8: Verify the Transaction

You can verify the transaction by:

1. Checking the events emitted in the transaction logs
2. Looking for the `IntentExecuted` event from the SolverAppGateway
3. Verifying the destination account received the funds on Base Sepolia


