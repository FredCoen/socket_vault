# Socket Vault Solver Example

A demonstration of building an Intent Solver strategy on the Socket Protocol, using on-chain vault liquidity to fill cross-chain intents. **Not production-ready.**

## Overview

This tutorial implements two solver strategies for filling intents to transfer ETH from Arbitrum Sepolia to Optimism Sepolia. The strategies differ in how quickly they pick up intents (aggressive vs. conservative reorg risk).

## Architecture

The system consists of:

1. **SpokePoolWrapper**: A wrapper around Across Protocol's SpokePool, acting as a Socket Plug.
2. **Vault**: An ERC4626-compliant vault providing liquidity.
3. **Executor**: A centralized executor who acts as the exclusive relayer specified in the intent
3. **SolverAppGateway**: Runs the solver strategy, filling intents using vault liquidity.
5. **RouterGateway**: Forwards intents to solver strategies.

## Project Structure

```
├── src/
│   ├── SpokePoolWrapper.sol  - Wrapper for Across Protocol SpokePool
│   ├── Vault.sol             - ERC4626 vault plug
│   ├── SolverAppGateway.sol  - Gateway for cross chain communication and running solver strategy
│   ├── Executor.sol          - Contract for executing intents from whitelisted vaults
│   ├── RouterGateway.sol     - Router to forward intents to strategies
│   ├── interfaces/           - Contract interfaces
│   │   ├── IVault.sol
│   │   └── across/
│   ├── libraries/            - Utility libraries
├── script/                   - Deployment and read/write scripts
└── foundry.toml              - Foundry configuration
```


## Prerequisites

- [Foundry](https://getfoundry.sh/)
- Testnet ETH on Arbitrum Sepolia and Optimism Sepolia
- WETH on Optimism Sepolia

## Setup

1. **Clone and install dependencies:**
   ```bash
   git clone <repo-url>
   cd socket-vault
   forge install
   ```

2. **Configure environment:**
   ```bash
   cp .env.example .env
   ```
   Edit `.env`:
   ```env
   PRIVATE_KEY=your-private-key
   RPC_421614=arbitrum-sepolia-rpc-url
   RPC_11155420=optimism-sepolia-rpc-url
   ```

## Deployment

### 1. Deploy the Executor contract

```bash
forge script script/DeployExecutor.s.sol --broadcast --skip-simulation --via-ir
```

### 2. Deploy Solvers and Router

```bash
forge script script/DeployGateways.s.sol --broadcast --skip-simulation --legacy --with-gas-price 0 --via-ir --evm-version paris
```

Add contract addresses to `.env`:
```env
CONSERVATIVE_SOLVER=""
AGGRESSIVE_SOLVER=""
ROUTER=""
```

### 2. Fund Fee Balance

Deposit test USDC for each App Gateway:
```bash
forge script script/DepositFees.s.sol --broadcast --skip-simulation --via-ir
```
Check fee balance:
```bash
forge script script/CheckFeesBalance.s.sol --broadcast --skip-simulation --via-ir
```

### 3. Deploy On-Chain Contracts

**On Optimism Sepolia:**
```bash
source .env && cast send $CONSERVATIVE_SOLVER "deployVault(uint32,address,string,string)" 11155420 0x4200000000000000000000000000000000000006 'WETH Vault' 'vWETH' --private-key $PRIVATE_KEY --legacy --gas-price 0 --gas-limit 120000000 --rpc-url $EVMX_RPC
source .env && cast send $AGRESSIVE_SOLVER "deployVault(uint32,address,string,string)" 11155420 0x4200000000000000000000000000000000000006 'WETH Vault' 'vWETH' --private-key $PRIVATE_KEY --legacy --gas-price 0 --gas-limit 120000000 --rpc-url $EVMX_RPC
```

**On Arbitrum Sepolia:**
```bash
source .env && cast send $ROUTER "deploySpokePoolWrapper(uint32)" 421614 --private-key $PRIVATE_KEY --legacy --gas-price 0 --gas-limit 120000000 --rpc-url $EVMX_RPC
```

Get contract addresses:
```bash
forge script script/GetDeployedAddressesAndSetVaultStatus.s.sol --broadcast --skip-simulation --via-ir
```
Add to `.env`:
```env
SPOKE_POOL_WRAPPER_421614=""
CONSERVATIVE_VAULT=""
AGGRESSIVE_VAULT=""
```

## Funding

Seed vaults with some ETH:
```bash
forge script script/FundVaults.s.sol --broadcast --skip-simulation --via-ir
```
Deposit ETH via the [vault_frontend](https://github.com/FredCoen/vault_frontend).

## Submitting an Intent

Submit an intent through the SpokePoolWrapper:
```bash
forge script script/DepositInSpokePoolWrapper.s.sol:DepositInSpokePoolWrapper --sig "run(uint256,uint256)" 421614 11155420 --broadcast
```

## How It Works

1. **Intent Creation:** `deposit` on SpokePoolWrapper creates an intent.
2. **Intent Detection:** RouterGateway forwards the intent to solvers.
3. **Liquidity Provision:** Solvers call the vault to fill the intent.
4. **Intent Execution:** Vault approves tokens and calls `fillRelay` on Across SpokePool.
5. **Completion:** Recipient receives funds; settlement returns funds to the vault.