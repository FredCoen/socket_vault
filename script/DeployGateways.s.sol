// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SpokePoolWrapper} from "../src/SpokePoolWrapper.sol";
import {WETHVault} from "../src/Vault.sol";
import {SolverAppGateway} from "../src/SolverAppGateway.sol";
import {RouterGateway} from "../src/RouterGateway.sol";

// source .env && forge script script/DeploySolverAppGateway.s.sol --broadcast --skip-simulation --legacy --gas-price 0
contract DeployGateways is Script {
    function run() external {
        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        address spokePoolArbitrum = vm.envAddress("SPOKE_POOL_421614");
        address spokePoolOptimism = vm.envAddress("SPOKE_POOL_11155420");

        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        uint256 maxFees = 10 ether;

        RouterGateway router = new RouterGateway(
            addressResolver,
            spokePoolArbitrum,
            spokePoolOptimism,
            abi.encodePacked(type(SpokePoolWrapper).creationCode),
            maxFees
        );

        SolverAppGateway agressiveSolver = new SolverAppGateway(
            addressResolver,
            maxFees,
            spokePoolArbitrum,
            spokePoolOptimism,
            abi.encodePacked(type(WETHVault).creationCode),
            address(router),
            5
        );

        SolverAppGateway conservativeSolver = new SolverAppGateway(
            addressResolver,
            maxFees,
            spokePoolArbitrum,
            spokePoolOptimism,
            abi.encodePacked(type(WETHVault).creationCode),
            address(router),
            30
        );

        router.addStrategy(agressiveSolver);
        router.addStrategy(conservativeSolver);

        console.log("ConservativeSolver contract:", address(conservativeSolver));
        console.log(
            "See ConservativeSolver on EVMx: https://evmx.cloud.blockscout.com/address/%s", address(conservativeSolver)
        );
        console.log("AgressiveSolver contract:", address(agressiveSolver));
        console.log(
            "See AgressiveSolver on EVMx: https://evmx.cloud.blockscout.com/address/%s", address(agressiveSolver)
        );
        console.log("RouterGateway contract:", address(router));
        console.log("See RouterGateway on EVMx: https://evmx.cloud.blockscout.com/address/%s", address(router));
    }
}
