// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {V3SpokePoolInterface} from "../src/interfaces/across/V3SpokePoolInterface.sol";
import {ERC20Upgradeable} from "openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";

contract FillRelayInV3SpokePool is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        string memory rpc = vm.envString("RPC_84532");
        vm.createSelectFork(rpc);
        vm.startBroadcast(privateKey);

        address spokePoolAddress = vm.envAddress("SPOKE_POOL_84532");
        V3SpokePoolInterface spokePool = V3SpokePoolInterface(spokePoolAddress);
        uint256 inputAmount = 0.01 ether;

        V3SpokePoolInterface.V3RelayData memory relayData = V3SpokePoolInterface.V3RelayData({
            depositor: bytes32(uint256(uint160(vm.addr(privateKey)))),
            recipient: bytes32(uint256(uint160(vm.addr(privateKey)))),
            exclusiveRelayer: bytes32(uint256(uint160(vm.addr(privateKey)))),
            inputToken: bytes32(uint256(uint160(0x980B62Da83eFf3D4576C647993b0c1D7faf17c73))),
            outputToken: bytes32(uint256(uint160(0x4200000000000000000000000000000000000006))),
            inputAmount: inputAmount,
            outputAmount: 0.009 ether,
            originChainId: 421614,
            depositId: 1000779,
            fillDeadline: 1744881206,
            exclusivityDeadline: 1744881206,
            message: bytes("")
        });

        bytes32 repaymentAddress = bytes32(uint256(uint160(vm.addr(privateKey))));

        address outputToken = vm.envAddress("WETH_ADDRESS_84532");

        (bool success,) =
            outputToken.call(abi.encodeWithSignature("approve(address,uint256)", spokePoolAddress, inputAmount));
        require(success, "Token approval failed");

        spokePool.fillRelay(relayData, 84532, repaymentAddress);

        console.log("Relay filled successfully!");

        vm.stopBroadcast();
    }
}
