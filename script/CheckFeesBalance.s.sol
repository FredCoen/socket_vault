    // SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesPlug} from "socket-protocol/protocol/payload-delivery/FeesPlug.sol";
import {FeesManager} from "socket-protocol/protocol/payload-delivery/FeesManager.sol";

import {ETH_ADDRESS} from "socket-protocol/protocol/utils/common/Constants.sol";

contract CheckFeesBalance is Script {
    function run() external {
        vm.createSelectFork(vm.envString("EVMX_RPC"));
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        address appGateway = vm.envAddress("APP_GATEWAY");

        FeesManager feesManager = FeesManager(payable(vm.envAddress("FEES_MANAGER")));

        uint256 availableFeesArbitrum = feesManager.getAvailableFees(421614, appGateway, ETH_ADDRESS);
        uint256 availableFeesBase = feesManager.getAvailableFees(84532, appGateway, ETH_ADDRESS);
        console.log("Fees available to be spent on transactions: %s", availableFeesArbitrum + availableFeesBase);
        console.log("Fees available Arbitrum fees plug: %s", availableFeesArbitrum);
        console.log("Fees available Base fees plug: %s", availableFeesBase);
    }
}
