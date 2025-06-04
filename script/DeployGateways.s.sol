// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SpokePoolWrapper} from "../src/SpokePoolWrapper.sol";
import {WETHVault} from "../src/Vault.sol";
import {FillerStrategy} from "../src/FillerStrategy.sol";
import {RouterGateway} from "../src/RouterGateway.sol";

// source .env && forge script script/DeployFillerStrategy.s.sol --broadcast --skip-simulation --legacy --gas-price 0
contract DeployGateways is Script {
    function run() external {
        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        address executor = vm.envAddress("EXECUTOR");
        address spokePoolArbitrum = vm.envAddress("SPOKE_POOL_421614");
        address spokePoolOptimism = vm.envAddress("SPOKE_POOL_11155420");

        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        uint256 maxFees = 10 ether;

        console.log("Executor:", executor);

        RouterGateway router = new RouterGateway(
            addressResolver,
            spokePoolArbitrum,
            spokePoolOptimism,
            abi.encodePacked(type(SpokePoolWrapper).creationCode),
            maxFees
        );

        FillerStrategy agressiveFiller = new FillerStrategy(
            addressResolver,
            maxFees,
            spokePoolArbitrum,
            spokePoolOptimism,
            abi.encodePacked(type(WETHVault).creationCode),
            address(router),
            2,
            executor
        );

        FillerStrategy conservativeFiller = new FillerStrategy(
            addressResolver,
            maxFees,
            spokePoolArbitrum,
            spokePoolOptimism,
            abi.encodePacked(type(WETHVault).creationCode),
            address(router),
            30,
            executor
        );

        router.addStrategy(agressiveFiller);
        router.addStrategy(conservativeFiller);

        console.log("ConservativeFiller contract:", address(conservativeFiller));
        console.log(
            "See ConservativeFiller on EVMx: https://evmx.cloud.blockscout.com/address/%s", address(conservativeFiller)
        );
        console.log("AgressiveFiller contract:", address(agressiveFiller));
        console.log(
            "See AgressiveFiller on EVMx: https://evmx.cloud.blockscout.com/address/%s", address(agressiveFiller)
        );
        console.log("RouterGateway contract:", address(router));
        console.log("See RouterGateway on EVMx: https://evmx.cloud.blockscout.com/address/%s", address(router));
    }
}
