// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesManager} from "socket-protocol/evmx/payload-delivery/FeesManager.sol";

contract CheckFeesBalance is Script {
    function run() external {
        vm.createSelectFork(vm.envString("EVMX_RPC"));
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.startBroadcast(privateKey);
        address agressiveSolver = vm.envAddress("AGRESSIVE_SOLVER");
        address conservativeSolver = vm.envAddress("CONSERVATIVE_SOLVER");
        FeesManager feesManager = FeesManager(payable(vm.envAddress("FEES_MANAGER")));
        address router = vm.envAddress("ROUTER");

        uint256 availableFeesAgressive = feesManager.getAvailableCredits(agressiveSolver);
        uint256 availableFeesConservative = feesManager.getAvailableCredits(conservativeSolver);
        uint256 availableFeesRouter = feesManager.getAvailableCredits(router);
        console.log("Fees available Arbitrum fees plug on AgressiveSolver: %s", availableFeesAgressive);
        console.log("Fees available Arbitrum fees plug on ConservativeSolver: %s", availableFeesConservative);
        console.log("Fees available Arbitrum fees plug on Router: %s", availableFeesRouter);
    }
}
