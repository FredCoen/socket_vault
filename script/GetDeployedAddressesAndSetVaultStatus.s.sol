pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SolverAppGateway} from "../src/SolverAppGateway.sol";
import {Executor} from "../src/Executor.sol";
import {IForwarder} from "socket-protocol/evmx/interfaces/IForwarder.sol";
import {RouterGateway} from "../src/RouterGateway.sol";

contract GetDeployedAddressesAndSetVaultStatus is Script {
    function run() external {
        vm.createSelectFork(vm.envString("EVMX_RPC"));
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        SolverAppGateway agressiveSolver = SolverAppGateway(vm.envAddress("AGRESSIVE_SOLVER"));
        SolverAppGateway conservativeSolver = SolverAppGateway(vm.envAddress("CONSERVATIVE_SOLVER"));
        RouterGateway router = RouterGateway(vm.envAddress("ROUTER"));
        Executor executor = Executor(vm.envAddress("EXECUTOR"));

        address forwarderAddressSpokePoolWrapper = router.forwarderAddresses(router.spokePoolWrapper(), 421614);
        address onChainSpokePoolWrapper = IForwarder(forwarderAddressSpokePoolWrapper).getOnChainAddress();
        console.log("Arbitrum Sepolia On chain SpokePoolWrapper: %s", onChainSpokePoolWrapper);

        address forwarderAddressVault = agressiveSolver.forwarderAddresses(agressiveSolver.wethVault(), 11155420);
        address aggressiveOnChainVault = IForwarder(forwarderAddressVault).getOnChainAddress();
        console.log("Optimism Sepolia On chain WETH agressive solver Vault: %s", aggressiveOnChainVault);

        forwarderAddressVault = conservativeSolver.forwarderAddresses(conservativeSolver.wethVault(), 11155420);
        address conservativeOnChainVault = IForwarder(forwarderAddressVault).getOnChainAddress();
                console.log("Optimism Sepolia On chain WETH conservative solver Vault: %s", conservativeOnChainVault);

                        vm.createSelectFork(vm.envString("RPC_11155420"));

        vm.startBroadcast(privateKey);




        
        executor.setVaultStatus(aggressiveOnChainVault, true);
        executor.setVaultStatus(conservativeOnChainVault, true);
    }
}
