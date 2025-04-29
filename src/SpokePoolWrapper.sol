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
     * @dev Error thrown when input validation fails
     */
    error InvalidInput();

    /**
     * @notice Maximum period in seconds for exclusivity parameter
     * @dev Copied from Across protocol to maintain compatibility
     */
    uint32 public constant MAX_EXCLUSIVITY_PERIOD_SECONDS = 31_536_000;

    /**
     * @notice The address of the Across Protocol SpokePool contract
     */
    address public immutable spokePool;

    /**
     * @notice Emitted when a deposit is made through this wrapper
     * @param depositor The address that made the deposit
     * @param recipient The address that will receive the tokens
     * @param inputToken The token deposited
     * @param outputToken The token to be received
     * @param inputAmount The amount deposited
     * @param outputAmount The amount to be received
     * @param destinationChainId The destination chain ID
     * @param depositId The unique ID for this deposit
     */
    event DepositMade(
        bytes32 indexed depositor,
        bytes32 indexed recipient,
        bytes32 inputToken,
        bytes32 outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 indexed destinationChainId,
        uint256 depositId
    );

    /**
     * @notice Constructor sets the SpokePool address
     * @param _spokePool The address of the SpokePool contract
     */
    constructor(address _spokePool) {
        require(_spokePool != address(0), "SpokePool cannot be zero address");
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
        if (depositor == bytes32(0) || recipient == bytes32(0) || inputToken == bytes32(0) || outputToken == bytes32(0))
        {
            revert InvalidInput();
        }
        if (inputAmount == 0 || outputAmount == 0 || destinationChainId == 0) {
            revert InvalidInput();
        }
        if (fillDeadline <= block.timestamp) {
            revert InvalidInput();
        }

        // Calculate exclusivityDeadline based on exclusivityParameter
        // This logic is copied from Across protocol to provide identical data to the FundsDeposited event
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

        _callAppGateway(abi.encode(params), bytes32(0));
        _forwardDeposit(params, msg.value);

        emit DepositMade(
            depositor,
            recipient,
            inputToken,
            outputToken,
            inputAmount,
            outputAmount,
            destinationChainId,
            params.acrossDepositId
        );
    }

    /**
     * @notice Forwards the deposit to the Across SpokePool contract
     * @param params The deposit parameters
     * @param value The ETH value to forward with the call
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
}
