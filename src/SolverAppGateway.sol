// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "socket-protocol/evmx/base/AppGatewayBase.sol";
import {V3SpokePoolInterface} from "./interfaces/across/V3SpokePoolInterface.sol";
import "./SpokePoolWrapper.sol";
import {WETHVault} from "./Vault.sol";
import {IVault} from "./interfaces/IVault.sol";
import "./interfaces/IStrategy.sol";

/**
 * @title SolverAppGateway
 * @notice Solver App Gateway running a Across protocol solver strategy
 * @dev Handles deployment SpokePoolWrappers and WETHVaults and executes the Intent filling strategy
 */
contract SolverAppGateway is IStrategy, AppGatewayBase {
    address public immutable router;
    uint256 public fillDelayInSeconds;
    V3SpokePoolInterface public immutable spokePoolArbitrum;
    V3SpokePoolInterface public immutable spokePoolOptimism;
    uint32 public constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    uint32 public constant OPTIMISM_SEPOLIA_CHAIN_ID = 11155420;
    address public constant WETH_BASE = 0x4200000000000000000000000000000000000006;
    address public constant WETH_OPTIMISM = 0x4200000000000000000000000000000000000006;
    bytes32 public immutable wethVault;
    bytes public wethVaultCreationCode;

    error InvalidIntent(string reason);

    event IntentExecuted(uint256 indexed originChainId, uint256 indexed depositId);
    event IntentExecutionScheduled(uint256 indexed originChainId, uint256 indexed depositId);

    constructor(
        address addressResolver_,
        uint256 fees_,
        address spokePoolArbitrum_,
        address spokePoolOptimism_,
        bytes memory wethVaultCreationCode_,
        address router_,
        uint256 fillDelayInSeconds_
    ) AppGatewayBase(addressResolver_) {
        wethVaultCreationCode = wethVaultCreationCode_;
        wethVault = _createContractId("WETHVault");
        _setMaxFees(fees_);
        spokePoolArbitrum = V3SpokePoolInterface(spokePoolArbitrum_);
        spokePoolOptimism = V3SpokePoolInterface(spokePoolOptimism_);
        router = router_;
        fillDelayInSeconds = fillDelayInSeconds_;
    }

    function deployVault(uint32 chainSlug_, address weth_, string memory name_, string memory symbol_)
        external
        async(bytes(""))
    {
        creationCodeWithArgs[wethVault] = abi.encodePacked(
            wethVaultCreationCode,
            abi.encode(
                weth_,
                name_,
                symbol_,
                chainSlug_ == OPTIMISM_SEPOLIA_CHAIN_ID ? address(spokePoolOptimism) : address(spokePoolArbitrum)
            )
        );
        _deploy(wethVault, chainSlug_, IsPlug.YES);
    }

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

    function processIntent(uint32 chainSlug_, bytes calldata payload_) external {
        FundsDepositedParams memory params = abi.decode(payload_, (FundsDepositedParams));
        if (
            uint32(uint256(params.destinationChainId)) == OPTIMISM_SEPOLIA_CHAIN_ID
                && toAddressUnchecked(params.outputToken) == WETH_BASE && chainSlug_ == ARBITRUM_SEPOLIA_CHAIN_ID
        ) {
            V3SpokePoolInterface.V3RelayData memory relayData = V3SpokePoolInterface.V3RelayData({
                depositor: params.depositor,
                recipient: params.recipient,
                exclusiveRelayer: params.exclusiveRelayer,
                inputToken: params.inputToken,
                outputToken: params.outputToken,
                inputAmount: params.inputAmount,
                outputAmount: params.outputAmount,
                originChainId: chainSlug_,
                depositId: params.acrossDepositId,
                fillDeadline: params.fillDeadline,
                exclusivityDeadline: params.exclusivityDeadline,
                message: params.message
            });
            bytes memory payload = abi.encodeWithSelector(this.fillIntent.selector, relayData);
            watcherPrecompile__().setTimeout(fillDelayInSeconds, payload);
            emit IntentExecutionScheduled(chainSlug_, params.acrossDepositId);
        } else {
            revert InvalidIntent("Unsupported intent");
        }
    }

    function fillIntent(V3SpokePoolInterface.V3RelayData memory relayData) public async(bytes("")) {
        IVault(forwarderAddresses[wethVault][OPTIMISM_SEPOLIA_CHAIN_ID]).executeIntent(relayData);
        emit IntentExecuted(relayData.originChainId, relayData.depositId);
    }

    function toAddressUnchecked(bytes32 _bytes32) internal pure returns (address) {
        return address(uint160(uint256(_bytes32)));
    }
}
