// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Fees} from "socket-protocol/protocol/utils/common/Structs.sol";
import {ETH_ADDRESS} from "socket-protocol/protocol/utils/common/Constants.sol";

import {SolverAppGateway} from "../src/SolverAppGateway.sol";

import {SpokePoolWrapper} from "../src/SpokePoolWrapper.sol";
import {WETHVault} from "../src/Vault.sol";

// source .env && forge script script/DeploySolverAppGateway.s.sol --broadcast --skip-simulation --legacy --gas-price 0
contract SolverAppGatewayDeploy is Script {
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

        SolverAppGateway appGateway = new SolverAppGateway(
            addressResolver,
            fees,
            spokePoolArbitrum,
            spokePoolBase,
            spokePoolOptimism, 
            abi.encodePacked(type(SpokePoolWrapper).creationCode),
            abi.encodePacked(type(WETHVault).creationCode)
        );

        console.log("SolverAppGateway contract:", address(appGateway));
        console.log("See SolverAppGateway on EVMx: https://evmx.cloud.blockscout.com/address/%s", address(appGateway));
    }
}
