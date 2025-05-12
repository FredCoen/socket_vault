pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SolverAppGateway} from "../src/SolverAppGateway.sol";
import {IForwarder} from "socket-protocol/evmx/interfaces/IForwarder.sol";
import {RouterGateway} from "../src/RouterGateway.sol";

contract GetOnChainAddress is Script {
    function run() external {
        vm.createSelectFork(vm.envString("EVMX_RPC"));
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(privateKey);
        SolverAppGateway agressiveSolver = SolverAppGateway(vm.envAddress("AGRESSIVE_SOLVER"));
        SolverAppGateway conservativeSolver = SolverAppGateway(vm.envAddress("CONSERVATIVE_SOLVER"));
        RouterGateway router = RouterGateway(vm.envAddress("ROUTER"));

        address forwarderAddressSpokePoolWrapper = router.forwarderAddresses(router.spokePoolWrapper(), 421614);
        address onChainSpokePoolWrapper = IForwarder(forwarderAddressSpokePoolWrapper).getOnChainAddress();
        console.log("Arbitrum Sepolia On chain SpokePoolWrapper: %s", onChainSpokePoolWrapper);

        address forwarderAddressVault = agressiveSolver.forwarderAddresses(agressiveSolver.wethVault(), 11155420);
        address onChainVault = IForwarder(forwarderAddressVault).getOnChainAddress();
        console.log("Optimism Sepolia On chain WETH agressive solver Vault: %s", onChainVault);

        forwarderAddressVault = conservativeSolver.forwarderAddresses(conservativeSolver.wethVault(), 11155420);
        onChainVault = IForwarder(forwarderAddressVault).getOnChainAddress();
        console.log("Optimism Sepolia On chain WETH conservative solver Vault: %s", onChainVault);
    }
}
