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
        address assetAddress = vaultConservative.asset();
        IERC20 asset = IERC20(assetAddress);
        asset.approve(conservativeVault, type(uint256).max);
        asset.approve(agressiveVault, type(uint256).max);
        vm.stopBroadcast();
    }
}
