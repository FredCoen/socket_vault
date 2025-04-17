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
        address forwarderAddressSpokePoolWrapper = appGateway.forwarderAddresses(appGateway.spokePoolWrapper(), 421614);
        address onChainSpokePoolWrapper = IForwarder(forwarderAddressSpokePoolWrapper).getOnChainAddress();
        console.log("Arbitrum Sepolia On chain SpokePoolWrapper: %s", onChainSpokePoolWrapper);
        address forwarderAddressVault = appGateway.forwarderAddresses(appGateway.wethVault(),84532 );
        address onChainVault = IForwarder(forwarderAddressVault).getOnChainAddress();
        console.log("Base Sepolia On chain WETH Vault: %s", onChainVault);
    }
}