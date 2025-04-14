// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ETH_ADDRESS} from "socket-protocol/protocol/utils/common/Constants.sol";

import {SolverAppGateway} from "../src/SolverAppGateway.sol";

contract SpokePoolWrapperDeploy is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork(rpc);

        vm.startBroadcast(privateKey);

        SolverAppGateway appGateway = SolverAppGateway(vm.envAddress("APP_GATEWAY"));

        console.log("Deploying SpokePoolWrapper on Base Sepolia...");
        appGateway.deployContracts(84532);
    }
}
