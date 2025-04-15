// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

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

    // WETH addresses by chain ID
    mapping(uint256 => address) public wethAddresses;
    // Exclusive relayer addresses by chain ID
    mapping(uint256 => address) public exclusiveRelayers;

    function setUp() public {
        // WEHT addresses per chain
        wethAddresses[421614] = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2; // Arbitrum Sepolia
        wethAddresses[84532] = 0x4200000000000000000000000000000000000006; // Base Sepolia
        // Vaults (relayers) per chain
        exclusiveRelayers[421614] = 0x1234567890123456789012345678901234567890; //  Arbitrum Sepolia
        exclusiveRelayers[84532] = 0x9876543210987654321098765432109876543210; //  Base
    }

    function run(uint256 sourceChainId, uint256 destinationChainId) external {

        string memory rpcEnvVar = string.concat("RPC_", sourceChainId.toString());
        string memory rpc = vm.envString(rpcEnvVar);
        uint256 privateKey = vm.envUint("PRIVATE_KEY");

        vm.createSelectFork(rpc);
        vm.startBroadcast(privateKey);
        
        // Get contract address from env var
        address spokePoolWrapperAddress = vm.envAddress("SPOKE_POOL_WRAPPER");
        SpokePoolWrapper spokePoolWrapper = SpokePoolWrapper(spokePoolWrapperAddress);
        
        // Check if WETH addresses are available for the specified chains
        require(wethAddresses[sourceChainId] != address(0), 
            string.concat("WETH address not configured for source chain ID: ", sourceChainId.toString()));
        require(wethAddresses[destinationChainId] != address(0), 
            string.concat("WETH address not configured for destination chain ID: ", destinationChainId.toString()));
        
        // Deposit parameters
        address depositor = vm.addr(privateKey);
        bytes32 depositorBytes32 = bytes32(uint256(uint160(depositor)));
        bytes32 recipientBytes32 = depositorBytes32; 
        bytes32 inputTokenBytes32 = bytes32(uint256(uint160(wethAddresses[sourceChainId])));
        bytes32 outputTokenBytes32 = bytes32(uint256(uint160(wethAddresses[destinationChainId])));
        uint256 inputAmount = 0.02 ether;
        uint256 outputAmount = 0.01 ether;
        bytes32 exclusiveRelayerBytes32 = bytes32(uint256(uint160(exclusiveRelayers[sourceChainId])));
        uint32 quoteTimestamp = uint32(block.timestamp);
        uint32 fillDeadline = uint32(block.timestamp) + 15 minutes; 
        uint32 exclusivityParameter = uint32(block.timestamp) + 15 minutes; 
        bytes memory message = "";
        
        console.log("Depositing %s WETH from chain %s to chain %s", 
            inputAmount, sourceChainId, destinationChainId);
        
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
        
        console.log("Deposited !");
        
        vm.stopBroadcast();
    }
} 