pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SolverAppGateway} from "../src/SolverAppGateway.sol";
import {IForwarder} from "lib/socket-protocol/contracts/interfaces/IForwarder.sol";

contract GetOnChainAddress is Script {
    function run() external {
        vm.createSelectFork(vm.envString("EVMX_RPC"));
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        SolverAppGateway appGateway = SolverAppGateway(vm.envAddress("APP_GATEWAY"));
        address forwarderAddress = appGateway.forwarderAddresses(appGateway.spokePoolWrapper(), 421614);
        address onChainSpokePoolWrapper = IForwarder(forwarderAddress).getOnChainAddress();
        console.log("Arbitrum Sepolia On chain SpokePoolWrapper: %s", onChainSpokePoolWrapper);
    }
}