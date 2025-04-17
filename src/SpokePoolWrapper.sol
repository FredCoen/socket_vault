// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {V3SpokePoolInterface, V3SpokePoolInterfaceExtended} from "./interfaces/across/V3SpokePoolInterface.sol";
import {Bytes32ToAddress} from "./libraries/Bytes32ToAddress.sol";
import "socket-protocol/base/PlugBase.sol";

/**
 * @title SpokePoolWrapper
 * @notice A wrapper contract for the Across Protocol SpokePool that integrates with Socket Protocol
 * @dev Inherits from PlugBase to enable cross-chain communication via Socket Protocol
 */
contract SpokePoolWrapper is PlugBase {
    using Bytes32ToAddress for bytes32;

    /**
     * @notice Data structure to replicate the data emitted by Across Protocol's FundsDeposited event
     * @param inputToken The token deposited on the source chain
     * @param outputToken The token to be received on the destination chain
     * @param inputAmount The amount of input tokens deposited
     * @param outputAmount The amount of output tokens to be received
     * @param destinationChainId The ID of the destination chain
     * @param acrossDepositId The unique ID for this deposit in the Across Protocol
     * @param quoteTimestamp The timestamp when the quote was generated
     * @param fillDeadline The deadline after which the deposit cannot be filled
     * @param exclusivityDeadline The deadline until which only the exclusive relayer can fill
     * @param depositor The address that made the deposit
     * @param recipient The address that will receive the tokens on the destination chain
     * @param exclusiveRelayer The address with exclusive rights to fill the deposit until exclusivityDeadline
     * @param message Additional data passed along with the deposit
     */
    struct FundsDepositedParams {
        bytes32 inputToken;
        bytes32 outputToken;
        uint256 inputAmount;
        uint256 outputAmount;
        uint256 destinationChainId;
        uint256 acrossDepositId;
        uint32 quoteTimestamp;
        uint32 fillDeadline;
        uint32 exclusivityDeadline;
        bytes32 depositor;
        bytes32 recipient;
        bytes32 exclusiveRelayer;
        bytes message;
    }

    /**
     * @dev Error thrown when an exclusive relayer is required but not provided
     */
    error InvalidExclusiveRelayer();

    /**
     * @notice Maximum period in seconds for exclusivity parameter (copy pasta from across protocol)
     */
    uint32 public constant MAX_EXCLUSIVITY_PERIOD_SECONDS = 31_536_000;

    /**
     * @notice The address of the Across Protocol SpokePool contract
     */
    address public spokePool;

    /**
     * @notice Mapping to store all deposits made in a block. Can be queried by the app gateway
     */
    mapping(uint256 => FundsDepositedParams[]) public depositsPerBlock;

    constructor(address _spokePool) {
        spokePool = _spokePool;
    }

    /**
     * @notice Sets the address of the SpokePool contract
     * @dev Can only be called by the Socket contract
     * @param _spokePool The address of the SpokePool contract
     */
    function setSpokePool(address _spokePool) external onlySocket {
        spokePool = _spokePool;
    }

    /**
     * @notice Deposit funds to the Across Protocol
     * @dev Creates a deposit record, notifies the app gateway, and forwards to AcrossSpokePool
     * @param depositor The address that is making the deposit
     * @param recipient The address that will receive the tokens on the destination chain
     * @param inputToken The token being deposited
     * @param outputToken The token to be received on the destination chain
     * @param inputAmount The amount of input tokens being deposited
     * @param outputAmount The amount of output tokens to be received
     * @param destinationChainId The ID of the destination chain
     * @param exclusiveRelayer The address with exclusive rights to fill the deposit until exclusivityDeadline
     * @param quoteTimestamp The timestamp when the quote was generated
     * @param fillDeadline The deadline after which the deposit cannot be filled
     * @param exclusivityParameter Parameter to determine exclusivity period
     * @param message Additional data to be passed along with the deposit
     */
    function deposit(
        bytes32 depositor,
        bytes32 recipient,
        bytes32 inputToken,
        bytes32 outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 destinationChainId,
        bytes32 exclusiveRelayer,
        uint32 quoteTimestamp,
        uint32 fillDeadline,
        uint32 exclusivityParameter,
        bytes calldata message
    ) external payable {
        // @dev exclusivityDeadline is copy pasta from across protocol, so that this wrapper provides identical data to across protocol FundsDeposited event
        uint32 exclusivityDeadline = exclusivityParameter;
        if (exclusivityDeadline > 0) {
            if (exclusivityDeadline <= MAX_EXCLUSIVITY_PERIOD_SECONDS) {
                exclusivityDeadline += uint32(block.timestamp);
            }
            // As a safety measure, prevent caller from inadvertently locking funds during exclusivity period
            //  by forcing them to specify an exclusive relayer.
            if (exclusiveRelayer == bytes32(0)) {
                revert InvalidExclusiveRelayer();
            }
        }

        FundsDepositedParams memory params = FundsDepositedParams({
            inputToken: inputToken,
            outputToken: outputToken,
            inputAmount: inputAmount,
            outputAmount: outputAmount,
            destinationChainId: destinationChainId,
            acrossDepositId: V3SpokePoolInterfaceExtended(spokePool).numberOfDeposits() + 1,
            quoteTimestamp: quoteTimestamp,
            fillDeadline: fillDeadline,
            exclusivityDeadline: exclusivityDeadline,
            depositor: depositor,
            recipient: recipient,
            exclusiveRelayer: exclusiveRelayer,
            message: message
        });
        depositsPerBlock[block.number].push(params);

        _callAppGateway(abi.encode(params), bytes32(0));
        _forwardDeposit(params, msg.value);
    }

    /**
     * @notice Forwards the deposit to the Across SpokePool contract
     */
    function _forwardDeposit(FundsDepositedParams memory params, uint256 value) internal {
        V3SpokePoolInterface(spokePool).deposit{value: value}(
            params.depositor,
            params.recipient,
            params.inputToken,
            params.outputToken,
            params.inputAmount,
            params.outputAmount,
            params.destinationChainId,
            params.exclusiveRelayer,
            params.quoteTimestamp,
            params.fillDeadline,
            params.exclusivityDeadline,
            params.message
        );
    }

    /**
     * @notice Get all deposits stored for a specific block
     * @param blockNumber The block number to query
     * @return Array of deposits made during that block
     */
    function getDepositsAtBlock(uint256 blockNumber) external view returns (FundsDepositedParams[] memory) {
        return depositsPerBlock[blockNumber];
    }

    /**
     * @notice Get number of deposits at a specific block
     * @param blockNumber The block number to query
     * @return Number of deposits
     */
    function getNumberOfDepositsAtBlock(uint256 blockNumber) external view returns (uint256) {
        return depositsPerBlock[blockNumber].length;
    }
}
