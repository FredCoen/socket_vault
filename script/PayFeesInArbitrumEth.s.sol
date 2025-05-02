// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesPlug} from "socket-protocol/protocol/payload-delivery/FeesPlug.sol";
import {ETH_ADDRESS} from "socket-protocol/protocol/utils/common/Constants.sol";

contract DepositFees is Script {
    function run() external {
        vm.createSelectFork(vm.envString("RPC_421614"));

        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        FeesPlug feesPlug = FeesPlug(payable(vm.envAddress("ARBITRUM_FEES_PLUG")));
        address agressiveSolver = vm.envAddress("AGRESSIVE_SOLVER");
        address conservativeSolver = vm.envAddress("CONSERVATIVE_SOLVER");
        address router = vm.envAddress("ROUTER");
        address sender = vm.addr(privateKey);
        uint256 balance = sender.balance;
        console.log("Using address %s with %s balance in wei", sender, balance);

        uint256 feesAmount = 0.005 ether;
        feesPlug.deposit{value: feesAmount}(ETH_ADDRESS, agressiveSolver, feesAmount);
        feesPlug.deposit{value: feesAmount}(ETH_ADDRESS, conservativeSolver, feesAmount);
        feesPlug.deposit{value: feesAmount}(ETH_ADDRESS, router, feesAmount);
        console.log("Added fee balance for Agressive Solver %s", feesAmount, agressiveSolver);
        console.log("Added fee balance for Conservative Solver %s", feesAmount, conservativeSolver);
        console.log("Added fee balance for Router %s", feesAmount, router);
        vm.stopBroadcast();
    }
}
