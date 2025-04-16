// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ETH_ADDRESS} from "socket-protocol/protocol/utils/common/Constants.sol";
import {SolverAppGateway} from "../src/SolverAppGateway.sol";

contract DeployOnChainContracts is Script {
    function run() external {
        console.log("Deploying contracts on Base Sepolia");

        string memory rpc = vm.envString("EVMX_RPC");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        console.log("Deploying contracts on Base Sepolia");

        vm.createSelectFork(rpc);
        vm.startBroadcast(privateKey);
        console.log("Deploying contracts on Base Sepolia111");

        SolverAppGateway appGateway = SolverAppGateway(
            vm.envAddress("APP_GATEWAY")
        );

        console.log("Deploying contracts on Base Sepolia11111");
        appGateway.deployContracts(84532, ETH_ADDRESS, "WETH", "WETH");
        // console.log("Deploying Contracts on Arbitrum Sepolia.");
        // appGateway.deployContracts(421614);
        // vm.stopBroadcast();
    }
}
