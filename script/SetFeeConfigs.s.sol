// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {FeesPlug} from "socket-protocol/protocol/payload-delivery/FeesPlug.sol";
import {FeesManager} from "socket-protocol/protocol/payload-delivery/FeesManager.sol";
import {Fees} from "socket-protocol/protocol/utils/common/Structs.sol";
import {SolverAppGateway} from "../src/SolverAppGateway.sol";

import {ETH_ADDRESS} from "socket-protocol/protocol/utils/common/Constants.sol";

contract DepositFees is Script {
    function run() external {
        string memory rpc = vm.envString("EVMX_RPC");
        vm.createSelectFork(rpc);

        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);

        address appGateway = vm.envAddress("APP_GATEWAY");

        Fees memory fees = Fees({feePoolChain: 421614, feePoolToken: ETH_ADDRESS, amount: 0.01 ether});

        SolverAppGateway(appGateway).setFees(fees);
    }
}
