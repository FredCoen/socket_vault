// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesPlug} from "socket-protocol/protocol/payload-delivery/FeesPlug.sol";
import {FeesManager} from "socket-protocol/protocol/payload-delivery/FeesManager.sol";

import {ETH_ADDRESS} from "socket-protocol/protocol/utils/common/Constants.sol";

contract DepositFees is Script {
    function run() external {
        vm.createSelectFork(vm.envString("ARBITRUM_SEPOLIA_RPC"));

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        FeesPlug feesPlug = FeesPlug(payable(vm.envAddress("ARBITRUM_FEES_PLUG")));
        address appGateway = vm.envAddress("APP_GATEWAY");

        address sender = vm.addr(privateKey);
        uint256 balance = sender.balance;
        console.log("Using address %s with %s balance in wei", sender, balance);

        uint256 feesAmount = 0.05 ether;
        feesPlug.deposit{value: feesAmount}(ETH_ADDRESS, appGateway, feesAmount);
        console.log("Added fee balance for AppGateway %s", feesAmount, appGateway);
        vm.stopBroadcast();
    }
}
