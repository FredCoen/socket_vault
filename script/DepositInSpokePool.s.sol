// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {V3SpokePoolInterface} from "../src/interfaces/across/V3SpokePoolInterface.sol";
import {Vm} from "forge-std/Vm.sol";

/**
 * @title DepositInV3SpokePool
 * @notice Foundry script to deposit directly into a V3SpokePool contract
 * @dev Uses dummy variables for demonstration purposes
 */
contract DepositInV3SpokePool is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        string memory rpc = vm.envString("RPC_421614");
        vm.createSelectFork(rpc);

        // Start recording logs before broadcasting
        vm.recordLogs();

        vm.startBroadcast(privateKey);

        address spokePoolAddress = vm.envAddress("SPOKE_POOL_421614");
        V3SpokePoolInterface spokePool = V3SpokePoolInterface(spokePoolAddress);

        bytes32 depositor = bytes32(uint256(uint160(vm.addr(privateKey))));
        bytes32 recipient = depositor;
        bytes32 inputToken = bytes32(uint256(uint160(0x980B62Da83eFf3D4576C647993b0c1D7faf17c73)));
        bytes32 outputToken = bytes32(uint256(uint160(0x4200000000000000000000000000000000000006)));
        uint256 inputAmount = 0.01 ether;
        uint256 outputAmount = 0.009 ether;
        uint256 destinationChainId = 84532;
        bytes32 exclusiveRelayer = depositor;
        uint32 quoteTimestamp = uint32(block.timestamp);
        uint32 fillDeadline = uint32(block.timestamp) + 30 minutes;
        uint32 exclusivityDeadline = uint32(block.timestamp) + 30 minutes;
        bytes memory message = "";

        console.log("Depositing %s ETH from address %s", inputAmount, vm.addr(privateKey));
        console.log("Deposit parameters:");
        console.log("  Destination chain: %s", destinationChainId);
        console.log("  Fill deadline: %s", fillDeadline);
        console.log("  Exclusivity deadline: %s", exclusivityDeadline);

        spokePool.deposit{value: inputAmount}(
            depositor,
            recipient,
            inputToken,
            outputToken,
            inputAmount,
            outputAmount,
            destinationChainId,
            exclusiveRelayer,
            quoteTimestamp,
            fillDeadline,
            exclusivityDeadline,
            message
        );

        console.log("Deposit completed successfully!");

        vm.stopBroadcast();

        // Retrieve recorded logs
        Vm.Log[] memory entries = vm.getRecordedLogs();

        // Print the events to console
        console.log("\n----- Emitted Events -----");

        for (uint256 i = 0; i < entries.length; i++) {
            Vm.Log memory entry = entries[i];

            // Check if this is a FundsDeposited event by matching the event signature
            bytes32 fundsDepositedSignature = keccak256(
                "FundsDeposited(bytes32,bytes32,uint256,uint256,uint256,uint256,uint32,uint32,uint32,bytes32,bytes32,bytes32,bytes)"
            );

            if (entry.topics[0] == fundsDepositedSignature) {
                console.log("Found FundsDeposited event:");

                // Extract indexed parameters from topics
                uint256 _destinationChainId = uint256(entry.topics[1]);
                uint256 _depositId = uint256(entry.topics[2]);
                bytes32 _depositorFromEvent = bytes32(entry.topics[3]);

                console.log("  Destination Chain ID: %s", _destinationChainId);
                console.log("  Deposit ID: %s", _depositId);
                console.log("  Depositor: %s", address(uint160(uint256(_depositorFromEvent))));

                // Decode the non-indexed parameters from data
                (
                    bytes32 inputTokenFromEvent,
                    bytes32 outputTokenFromEvent,
                    uint256 inputAmountFromEvent,
                    uint256 outputAmountFromEvent,
                    uint32 quoteTimestampFromEvent,
                    uint32 fillDeadlineFromEvent,
                    uint32 exclusivityDeadlineFromEvent,
                    bytes32 recipientFromEvent,
                    bytes32 exclusiveRelayerFromEvent,
                ) = abi.decode(
                    entry.data, (bytes32, bytes32, uint256, uint256, uint32, uint32, uint32, bytes32, bytes32, bytes)
                );

                console.log("  Input Token: %s", address(uint160(uint256(inputTokenFromEvent))));
                console.log("  Output Token: %s", address(uint160(uint256(outputTokenFromEvent))));
                console.log("  Input Amount: %s", inputAmountFromEvent);
                console.log("  Output Amount: %s", outputAmountFromEvent);
                console.log("  Quote Timestamp: %s", quoteTimestampFromEvent);
                console.log("  Fill Deadline: %s", fillDeadlineFromEvent);
                console.log("  Exclusivity Deadline: %s", exclusivityDeadlineFromEvent);
                console.log("  Recipient: %s", address(uint160(uint256(recipientFromEvent))));
                console.log("  Exclusive Relayer: %s", address(uint160(uint256(exclusiveRelayerFromEvent))));
            }
        }
    }
}
