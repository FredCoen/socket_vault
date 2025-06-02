// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import {V3SpokePoolInterface, V3SpokePoolInterfaceExtended} from "./interfaces/across/V3SpokePoolInterface.sol";
import {Bytes32ToAddress} from "./libraries/Bytes32ToAddress.sol";
import "socket-protocol/protocol/base/PlugBase.sol";
import {RouterGateway} from "./RouterGateway.sol";

contract SpokePoolWrapper is PlugBase {
    using Bytes32ToAddress for bytes32;

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

    error InvalidExclusiveRelayer();
    error InvalidInput();

    uint32 public constant MAX_EXCLUSIVITY_PERIOD_SECONDS = 31_536_000;
    address public immutable spokePool;

    constructor(address _spokePool) {
        require(_spokePool != address(0), "SpokePool cannot be zero address");
        spokePool = _spokePool;
    }

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
        uint32 exclusivityDeadline = exclusivityParameter;
        if (exclusivityDeadline > 0) {
            if (exclusivityDeadline <= MAX_EXCLUSIVITY_PERIOD_SECONDS) {
                exclusivityDeadline += uint32(block.timestamp);
            }
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

        RouterGateway(address(socket__)).notifyIntent(abi.encode(params), uint32(block.chainid));
        V3SpokePoolInterface(spokePool).deposit{value: msg.value}(
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
