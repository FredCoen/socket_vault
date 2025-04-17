// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {HubPoolInterface} from "../src/interfaces/across/HubPoolInterface.sol";

contract GetAcrossL2TokenAddresses is Script {
    function run(uint256 destinationChainId, address l1Token) external {
        // Get HubPool contract address from environment
        address hubPoolAddress = vm.envAddress("HUB_POOL");
        HubPoolInterface hubPool = HubPoolInterface(hubPoolAddress);

        string memory rpc = vm.envString("RPC_1");
        vm.createSelectFork(rpc);

        address destinationToken = hubPool.poolRebalanceRoute(destinationChainId, l1Token);

        console.log("----- Result -----");
        console.log("Destination token: %s", destinationToken);
    }
}
