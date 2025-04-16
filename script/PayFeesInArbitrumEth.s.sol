// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesPlug} from "socket-protocol/protocol/payload-delivery/FeesPlug.sol";
import {ETH_ADDRESS} from "socket-protocol/protocol/utils/common/Constants.sol";

// source .env && forge script script/PayFeesInArbitrumEth.s.sol  --broadcast --skip-simulation --legacy --gas-price 0
contract DepositFees is Script {
    function run() external {
        vm.createSelectFork(vm.envString("RPC_421614"));

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        FeesPlug feesPlug = FeesPlug(
            payable(vm.envAddress("ARBITRUM_FEES_PLUG"))
        );
        address appGateway = vm.envAddress("APP_GATEWAY");

        address sender = vm.addr(privateKey);
        uint256 balance = sender.balance;
        console.log("Using address %s with %s balance in wei", sender, balance);

        uint256 feesAmount = 0.005 ether;
        feesPlug.deposit{value: feesAmount}(
            ETH_ADDRESS,
            appGateway,
            feesAmount
        );
        console.log(
            "Added fee balance for AppGateway %s",
            feesAmount,
            appGateway
        );
        vm.stopBroadcast();
    }
}
