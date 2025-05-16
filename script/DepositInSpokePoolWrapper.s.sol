// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {SpokePoolWrapper} from "../src/SpokePoolWrapper.sol";
import {Strings} from "openzeppelin/contracts/utils/Strings.sol";

/**
 * @title DepositInSpokePoolWrapper
 * @notice Foundry script to deposit WETH into SpokePoolWrapper
 * @dev Takes source and destination chain IDs as arguments and configures the deposit accordingly
 */
contract DepositInSpokePoolWrapper is Script {
    using Strings for uint256;

    mapping(uint256 => address) public wethAddresses;

    function setUp() public {
        wethAddresses[421614] = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;
        wethAddresses[84532] = 0x4200000000000000000000000000000000000006;
        wethAddresses[11155420] = 0x4200000000000000000000000000000000000006;
    }

    function run(uint256 sourceChainId, uint256 destinationChainId) external {
        string memory rpcEnvVar = string.concat("RPC_", sourceChainId.toString());
        string memory rpc = vm.envString(rpcEnvVar);
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork(rpc);
        vm.startBroadcast(privateKey);
        address spokePoolWrapperAddress = vm.envAddress(string.concat("SPOKE_POOL_WRAPPER_", sourceChainId.toString()));
        SpokePoolWrapper spokePoolWrapper = SpokePoolWrapper(spokePoolWrapperAddress);

        address depositor = vm.addr(privateKey);
        bytes32 depositorBytes32 = bytes32(uint256(uint160(depositor)));
        bytes32 recipientBytes32 = depositorBytes32;
        bytes32 inputTokenBytes32 = bytes32(uint256(uint160(wethAddresses[sourceChainId])));
        bytes32 outputTokenBytes32 = bytes32(uint256(uint160(wethAddresses[destinationChainId])));
        uint256 inputAmount = 0.02 ether;
        uint256 outputAmount = 0.01 ether;
        bytes32 exclusiveRelayerBytes32 = bytes32(uint256(uint160(vm.envAddress("AGRESSIVE_VAULT"))));
        uint32 quoteTimestamp = uint32(block.timestamp);
        uint32 fillDeadline = uint32(block.timestamp) + 15 minutes;
        uint32 exclusivityParameter = uint32(block.timestamp) + 15 minutes;
        bytes memory message = "";

        console.log("Depositing %s WETH from chain %s to chain %s", inputAmount, sourceChainId, destinationChainId);

        spokePoolWrapper.deposit{value: inputAmount}(
            depositorBytes32,
            recipientBytes32,
            inputTokenBytes32,
            outputTokenBytes32,
            inputAmount,
            outputAmount,
            destinationChainId,
            exclusiveRelayerBytes32,
            quoteTimestamp,
            fillDeadline,
            exclusivityParameter,
            message
        );
        // depositor = vm.addr(privateKey);
        // depositorBytes32 = bytes32(uint256(uint160(depositor)));
        // recipientBytes32 = depositorBytes32;
        // inputTokenBytes32 = bytes32(uint256(uint160(wethAddresses[sourceChainId])));
        // outputTokenBytes32 = bytes32(uint256(uint160(wethAddresses[destinationChainId])));
        // inputAmount = 0.06 ether;
        // outputAmount = 0.04 ether;
        // exclusiveRelayerBytes32 = bytes32(uint256(uint160(vm.envAddress("CONSERVATIVE_VAULT"))));
        // quoteTimestamp = uint32(block.timestamp);
        // fillDeadline = uint32(block.timestamp) + 15 minutes;
        // exclusivityParameter = uint32(block.timestamp) + 15 minutes;
        // message = "";

        // console.log("Depositing %s WETH from chain %s to chain %s", inputAmount, sourceChainId, destinationChainId);

        // spokePoolWrapper.deposit{value: inputAmount}(
        //     depositorBytes32,
        //     recipientBytes32,
        //     inputTokenBytes32,
        //     outputTokenBytes32,
        //     inputAmount,
        //     outputAmount,
        //     destinationChainId,
        //     exclusiveRelayerBytes32,
        //     quoteTimestamp,
        //     fillDeadline,
        //     exclusivityParameter,
        //     message
        // );

        vm.stopBroadcast();
    }
}
