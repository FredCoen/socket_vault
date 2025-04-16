// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.29;

// import {Script} from "forge-std/Script.sol";
// import {console} from "forge-std/console.sol";
// import {V3SpokePoolInterface} from "../src/interfaces/across/V3SpokePoolInterface.sol";

// /**
//  * @title DepositInV3SpokePool
//  * @notice Foundry script to deposit directly into a V3SpokePool contract
//  * @dev Uses dummy variables for demonstration purposes
//  */
// contract DepositInV3SpokePool is Script {
//     function run() external {
//         // Load private key from environment
//         uint256 privateKey = vm.envUint("PRIVATE_KEY");
        
//         // RPC endpoint from environment
//         string memory rpc = vm.envString("RPC_421614");
        
//         // Create and select fork
//         vm.createSelectFork(rpc);
//         vm.startBroadcast(privateKey);

//         // Get SpokePool contract address from environment
//         address spokePoolAddress = vm.envAddress("SPOKE_POOL_421614");
//         V3SpokePoolInterface spokePool = V3SpokePoolInterface(spokePoolAddress);

//         // Dummy deposit parameters
//         bytes32 depositor = bytes32(uint256(uint160(vm.addr(privateKey)))); // Caller's address as bytes32
//         bytes32 recipient = depositor; // Same as depositor for this example
//         bytes32 inputToken = bytes32(uint256(uint160(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2))); // WETH address as bytes32
//         bytes32 outputToken = bytes32(uint256(uint160(0x4200000000000000000000000000000000000006))); // WETH on destination as bytes32
//         uint256 inputAmount = 0.01 ether;
//         uint256 outputAmount = 0.009 ether; 
//         uint256 destinationChainId = 84532; 
//         bytes32 exclusiveRelayer = bytes32(0); // Dummy exclusive relayer
//         uint32 quoteTimestamp = uint32(block.timestamp);
//         uint32 fillDeadline = uint32(block.timestamp) + 30 minutes;
//         uint32 exclusivityDeadline = 0; // 5 minutes exclusivity window
//         bytes memory message = ""; // Empty message for this example

//         console.log("Depositing %s ETH from address %s", inputAmount, vm.addr(privateKey));
//         console.log("Deposit parameters:");
//         console.log("  Destination chain: %s", destinationChainId);
//         console.log("  Fill deadline: %s", fillDeadline);
//         console.log("  Exclusivity deadline: %s", exclusivityDeadline);

//         // Make the deposit
//         spokePool.deposit{value: inputAmount}(
//             depositor,
//             recipient,
//             inputToken,
//             outputToken,
//             inputAmount,
//             outputAmount,
//             destinationChainId,
//             exclusiveRelayer,
//             quoteTimestamp,
//             fillDeadline,
//             exclusivityDeadline,
//             message
//         );

//         console.log("Deposit completed successfully!");

//         vm.stopBroadcast();
//     }
// } 