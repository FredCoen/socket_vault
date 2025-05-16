// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesPlug} from "socket-protocol/evmx/payload-delivery/FeesPlug.sol";
import {TestUSDC} from "socket-protocol/evmx/helpers/TestUSDC.sol";

contract DepositFees is Script {
    function run() external {
        uint256 feesAmount = 100000000;

        vm.createSelectFork(vm.envString("RPC_421614"));
        TestUSDC testUSDCContract = TestUSDC(vm.envAddress("ARBITRUM_TEST_USDC"));
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        FeesPlug feesPlug = FeesPlug(payable(vm.envAddress("ARBITRUM_FEES_PLUG")));
        address agressiveSolver = vm.envAddress("AGRESSIVE_SOLVER");
        address conservativeSolver = vm.envAddress("CONSERVATIVE_SOLVER");
        address router = vm.envAddress("ROUTER");
        testUSDCContract.mint(vm.addr(privateKey), feesAmount * 3);
        testUSDCContract.approve(address(feesPlug), feesAmount * 3);

        address sender = vm.addr(privateKey);
        feesPlug.depositToFeeAndNative(address(testUSDCContract), agressiveSolver, feesAmount);
        feesPlug.depositToFeeAndNative(address(testUSDCContract), conservativeSolver, feesAmount);
        feesPlug.depositToFeeAndNative(address(testUSDCContract), router, feesAmount);
        console.log("Added fee balance for Agressive Solver %s", feesAmount, agressiveSolver);
        console.log("Added fee balance for Conservative Solver %s", feesAmount, conservativeSolver);
        console.log("Added fee balance for Router %s", feesAmount, router);
        vm.stopBroadcast();
    }
}
