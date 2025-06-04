# Building a filler strategy/vault on SOCKET

This tutorial demonstrates how to build an Intent Filler strategy on the Socket Protocol, using on-chain vault liquidity to fill cross-chain intents. **Not production-ready.**

## Overview

This tutorial implements two filler strategies for filling intents to transfer ETH from Arbitrum Sepolia to Optimism Sepolia. The strategies differ in how quickly they pick up intents (aggressive vs. conservative reorg risk tolerance).

## System Components

Let's understand each component we'll build:

1. **Vault (Vault.sol)**
   - An ERC4626-compliant vault that holds WETH open for permissionless deposits
   - Provides liquidity for filler strategies
   - Earns fees from facilitating transfers
   - For simplicity purposes does not currently implement a working redemption mechanism

2. **SpokePoolWrapper (SpokePoolWrapper.sol)**
   - Wraps Across Protocol's SpokePool in order to notify Socket about new intents

3. **FillerStrategy (FillerStrategy.sol)**
   - Implements the filler strategy
   - Decides when to fill intents
   - Sends payloads to execute intents to connected on chain vault

4. **Router Gateway (RouterGateway.sol)**
   - Receives and forwards intents to relevant filler strategies

5. **Executor (Executor.sol)**
   - Handles the actual execution of intents
   - Acts as the exclusive relayer specified in the intent

## Tutorial Steps

### 1. Setup Development Environment

```bash
# Install Foundry if you haven't already
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone the repository
git clone <repo-url>
cd socket-vault
forge install

# Setup environment variables
cp .env.example .env
# Edit .env with your values:
# PRIVATE_KEY=your-private-key
# RPC_421614=arbitrum-sepolia-rpc-url
# RPC_11155420=optimism-sepolia-rpc-url
```

## Deployment


#### Vault.sol
- Implements ERC4626 standard for tokenized vault shares
- Holds WETH as the underlying asset
- Executes cross-chain intents using vault liquidity

#### SpokePoolWrapper.sol
- Creates intents when users want to transfer tokens
- Interfaces with Across Protocol's SpokePool
- Handles deposit and relay mechanics

#### FillerStrategy.sol
- Implements two strategies:
  1. Conservative: Waits for more confirmations
  2. Aggressive: Fills intents quickly
- Manages vault deployments and intent filling

### 3. Deployment Process

Deploy contracts in this order:

```bash
forge script script/DeployExecutor.s.sol --broadcast --skip-simulation --via-ir
```

### 2. Deploy Fillers and Router

```bash
forge script script/DeployGateways.s.sol --broadcast --skip-simulation --legacy --with-gas-price 0 --via-ir --evm-version paris
```

Add contract addresses to `.env`:
```env
CONSERVATIVE_FILLER=""
AGGRESSIVE_FILLER=""
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
source .env && cast send $CONSERVATIVE_FILLER "deployVault(uint32,address,string,string)" 11155420 0x4200000000000000000000000000000000000006 'WETH Vault' 'vWETH' --private-key $PRIVATE_KEY --legacy --gas-price 0 --gas-limit 120000000 --rpc-url $EVMX_RPC
source .env && cast send $AGGRESSIVE_FILLER "deployVault(uint32,address,string,string)" 11155420 0x4200000000000000000000000000000000000006 'WETH Vault' 'vWETH' --private-key $PRIVATE_KEY --legacy --gas-price 0 --gas-limit 120000000 --rpc-url $EVMX_RPC
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

Seed vaults with some ETH (amend as needed):
```bash
forge script script/FundVaults.s.sol --broadcast --skip-simulation --via-ir
```

## Submitting an Intent

Submit an intent through the SpokePoolWrapper (amend as needed):
```bash
forge script script/DepositInSpokePoolWrapper.s.sol:DepositInSpokePoolWrapper --sig "run(uint256,uint256)" 421614 11155420 --broadcast
```

Alternatively fire auction off an intent via the [vault_frontend](https://github.com/FredCoen/vault_frontend).


## How It Works

1. **Intent Creation:** `deposit` on SpokePoolWrapper creates an intent.
2. **Intent Detection:** RouterGateway forwards the intent to fillers.
3. **Liquidity Provision:** FIllers call the vault to fill the intent.
4. **Intent Execution:** Vault approves tokens and calls `fillRelay` via the Executor contract on Across SpokePool.
5. **Completion:** Recipient receives funds; settlement returns funds to the vault.