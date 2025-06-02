// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC4626} from "openzeppelin/contracts/interfaces/IERC4626.sol";
import {Vm} from "forge-std/Vm.sol";

/**
 * @title DepositInVault
 * @notice Foundry script to deposit funds into the Vault contract
 */
interface IWETH is IERC20 {
    function deposit() external payable;
    function withdraw(uint256) external;
}

contract FundVaults is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        string memory rpc = vm.envString("RPC_11155420");
        vm.createSelectFork(rpc);

        // Start recording logs
        vm.recordLogs();

        vm.startBroadcast(privateKey);

        address conservativeVault = vm.envAddress("CONSERVATIVE_VAULT");
        address agressiveVault = vm.envAddress("AGRESSIVE_VAULT");
        IERC4626 vaultConservative = IERC4626(conservativeVault);
        IERC4626 vaultAggressive = IERC4626(agressiveVault);
        address assetAddress = vaultConservative.asset();
        IWETH weth = IWETH(assetAddress);

        // Mint 0.02 WETH by depositing ETH
        weth.deposit{value: 0.2 ether}();

        // Approve spending for both vaults
        weth.approve(conservativeVault, type(uint256).max);
        weth.approve(agressiveVault, type(uint256).max);

        // Deposit 0.02 WETH into conservative vault
        // vaultConservative.deposit(0.15 ether, address(this));

        vaultAggressive.deposit(0.05 ether, address(this));

        vm.stopBroadcast();
    }
}
