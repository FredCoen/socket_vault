// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Executor} from "../src/Executor.sol";
import {V3SpokePoolInterface} from "../src/interfaces/across/V3SpokePoolInterface.sol";

/**
 * @title DeployExecutor
 * @notice Foundry script to deploy the Executor contract and approve two vaults
 */
contract DeployExecutor is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        string memory rpc = vm.envString("RPC_11155420"); // Optimism Sepolia RPC
        vm.createSelectFork(rpc);

        vm.startBroadcast(privateKey);
        address spokePool = vm.envAddress("SPOKE_POOL_11155420");
        Executor executor = new Executor(V3SpokePoolInterface(spokePool));
        vm.stopBroadcast();

        console.log("Executor deployed at:", address(executor));
    }
}
