// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Fees} from "socket-protocol/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS} from "socket-protocol/protocol/utils/common/Constants.sol";

import {SpokePoolWrapper} from "../src/SpokePoolWrapper.sol";
import {WETHVault} from "../src/Vault.sol";
import {SolverAppGateway} from "../src/SolverAppGateway.sol";
import {RouterGateway} from "../src/RouterGateway.sol";

// source .env && forge script script/DeploySolverAppGateway.s.sol --broadcast --skip-simulation --legacy --gas-price 0
contract DeployGateways is Script {
    function run() external {
        address addressResolver = vm.envAddress("ADDRESS_RESOLVER");
        address spokePoolArbitrum = vm.envAddress("SPOKE_POOL_421614");
        address spokePoolBase = vm.envAddress("SPOKE_POOL_84532");
        address spokePoolOptimism = vm.envAddress("SPOKE_POOL_11155420");

        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        Fees memory fees = Fees({feePoolChain: 421614, feePoolToken: ETH_ADDRESS, amount: 0.001 ether});

        RouterGateway router = new RouterGateway(
            addressResolver,
            spokePoolArbitrum,
            spokePoolBase,
            spokePoolOptimism,
            abi.encodePacked(type(SpokePoolWrapper).creationCode),
            fees
        );

        SolverAppGateway agressiveSolver = new SolverAppGateway(
            addressResolver,
            fees,
            spokePoolArbitrum,
            spokePoolBase,
            spokePoolOptimism,
            abi.encodePacked(type(WETHVault).creationCode),
            address(router),
            10
        );

        SolverAppGateway conservativeSolver = new SolverAppGateway(
            addressResolver,
            fees,
            spokePoolArbitrum,
            spokePoolBase,
            spokePoolOptimism,
            abi.encodePacked(type(WETHVault).creationCode),
            address(router),
            100
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
