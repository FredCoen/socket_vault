// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ETH_ADDRESS} from "socket-protocol/protocol/utils/common/Constants.sol";
import {SolverAppGateway} from "../src/SolverAppGateway.sol";

contract DeployOnChainContracts is Script {
        mapping(uint256 => address) public wethAddresses;


        function setUp() public {
        wethAddresses[421614] = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;
        wethAddresses[84532] = 0x4200000000000000000000000000000000000006; 
    }
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork(rpc);
        vm.startBroadcast(privateKey);

        SolverAppGateway appGateway = SolverAppGateway(vm.envAddress("APP_GATEWAY"));

        // appGateway.deployContracts(84532, ETH_ADDRESS, "WETH", "WETH");
        // console.log("Deploying Contracts on Arbitrum Sepolia.");
        appGateway.deployContracts(421614,  wethAddresses[421614], "WETH", "WETH");
        vm.stopBroadcast();
    }
}
