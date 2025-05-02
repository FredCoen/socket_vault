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
contract DepositInVault is Script {
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
        IERC4626 vaultAgressive = IERC4626(agressiveVault);

        // Get the underlying asset of the vault
        address assetAddress = vaultConservative.asset();
        IERC20 asset = IERC20(assetAddress);

        // Set the amount to deposit (in this case 0.01 ETH or equivalent)
        // uint256 depositAmount = 0.05 ether;

        asset.approve(conservativeVault, type(uint256).max);

        asset.approve(agressiveVault, type(uint256).max);

        // // Get balance before deposit
        // uint256 balanceBefore = asset.balanceOf(vm.addr(privateKey));
        // console.log("Balance before deposit: %s", balanceBefore);

        // // If we're dealing with WETH, we might need to wrap ETH first
        // // This assumes asset is WETH with a deposit function
        // // If deposit function is not available, this will revert
        // try asset.balanceOf(vm.addr(privateKey)) returns (uint256 balance) {
        //     if (balance < depositAmount) {
        //         console.log("Wrapping ETH to WETH");
        //         (bool success,) = assetAddress.call{value: depositAmount}("");
        //         require(success, "Failed to wrap ETH");
        //     }
        // } catch {
        //     console.log("Asset is not WETH or does not support direct deposits");
        // }

        // Deposit assets to the vault
        // uint256 sharesReceived = vault.deposit(depositAmount, vm.addr(privateKey));

        // console.log("Deposit completed successfully!");
        // console.log("Shares received: %s", sharesReceived);

        // // Get balance after deposit
        // uint256 balanceAfter = asset.balanceOf(vm.addr(privateKey));
        // console.log("Balance after deposit: %s", balanceAfter);
        // console.log("Vault token balance: %s", vault.balanceOf(vm.addr(privateKey)));

        vm.stopBroadcast();
    }
}
