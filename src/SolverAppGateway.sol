// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "socket-protocol/base/AppGatewayBase.sol";
import {V3SpokePoolInterface} from "./interfaces/across/V3SpokePoolInterface.sol";
import "./SpokePoolWrapper.sol";
import {WETHVault} from "./Vault.sol";
import {IVault} from "./interfaces/IVault.sol";
import "./interfaces/IStrategy.sol";
/**
 * @title ISpokePoolWrapper
 * @notice Interface for SpokePoolWrapper contract interaction
 */

interface ISpokePoolWrapper {
    /**
     * @notice Sets the SpokePool address
     * @param spokePool_ The new SpokePool address
     */
    function setSpokePool(address spokePool_) external;
}

/**
 * @title SolverAppGateway
 * @notice Solver App Gateway running a Across protocol solver strategy
 * @dev Handles deployment SpokePoolWrappers and WETHVaults and executes the Intent filling strategy
 */
contract SolverAppGateway is IStrategy, AppGatewayBase {
    address public immutable router;
    uint256 public fillDelayInSeconds;
    /// @notice Across V3 SpokePool on Arbitrum
    V3SpokePoolInterface public immutable spokePoolArbitrum;

    /// @notice Across V3 SpokePool on Base
    V3SpokePoolInterface public immutable spokePoolBase;

    /// @notice Across V3 SpokePool on Optimism
    V3SpokePoolInterface public immutable spokePoolOptimism;

    /// @notice Chain ID constant for Arbitrum Sepolia
    uint32 public constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;

    /// @notice Chain ID constant for Base Sepolia
    uint32 public constant BASE_SEPOLIA_CHAIN_ID = 84532;

    uint32 public constant OPTIMISM_SEPOLIA_CHAIN_ID = 11155420;

    /// @notice WETH address on Arbitrum
    address public constant WETH_ARBITRUM = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;

    /// @notice WETH address on Base
    address public constant WETH_BASE = 0x4200000000000000000000000000000000000006;

    /// @notice WETH address on Optimism
    address public constant WETH_OPTIMISM = 0x4200000000000000000000000000000000000006;

    /// @notice Contract ID for WETHVault
    bytes32 public immutable wethVault;

    /// @notice Creation code for WETHVault
    bytes public wethVaultCreationCode;

    /**
     * @dev Error thrown when an intent is invalid
     * @param reason The reason why the intent is invalid
     */
    error InvalidIntent(string reason);


    event ContractDeployed(uint32 indexed chainSlug, address wethVaultAddress);

    /**
     * @notice Emitted when an intent is executed
     * @param originChainId The chain ID where the deposit originated
     * @param depositId The deposit ID in the Across protocol
     */
    event IntentExecuted(uint256 indexed originChainId, uint256 indexed depositId);

    /**
     * @notice Emitted when an intent execution is scheduled
     * @param originChainId The chain ID where the deposit originated
     * @param depositId The deposit ID in the Across protocol
     */
    event IntentExecutionScheduled(uint256 indexed originChainId, uint256 indexed depositId);
 
    constructor(
        address addressResolver_,
        Fees memory fees_,
        address spokePoolArbitrum_,
        address spokePoolBase_,
        address spokePoolOptimism_,
        bytes memory wethVaultCreationCode_,
        address router_,
        uint256 fillDelayInSeconds_
    ) AppGatewayBase(addressResolver_) {
        require(addressResolver_ != address(0), "Address resolver cannot be zero");
        require(spokePoolArbitrum_ != address(0), "Arbitrum SpokePool cannot be zero");
        require(spokePoolBase_ != address(0), "Base SpokePool cannot be zero");
        require(wethVaultCreationCode_.length > 0, "WETHVault creation code cannot be empty");

        wethVaultCreationCode = wethVaultCreationCode_;
        wethVault = _createContractId("WETHVault");

        _setOverrides(fees_);
        spokePoolArbitrum = V3SpokePoolInterface(spokePoolArbitrum_);
        spokePoolBase = V3SpokePoolInterface(spokePoolBase_);
        spokePoolOptimism = V3SpokePoolInterface(spokePoolOptimism_);
        router = router_;
        fillDelayInSeconds = fillDelayInSeconds_;
    }

    /**
     * @notice Deploy SpokePoolWrapper and WETHVault contracts to a chain
     * @param chainSlug_ The chain ID where to deploy the contracts
     * @param weth_ The WETH token address on the target chain
     * @param name_ The name for the vault token
     * @param symbol_ The symbol for the vault token
     */
    function deployVault(uint32 chainSlug_, address weth_, string memory name_, string memory symbol_)
        external
        async
    {
        require(
            chainSlug_ == ARBITRUM_SEPOLIA_CHAIN_ID || chainSlug_ == BASE_SEPOLIA_CHAIN_ID
                || chainSlug_ == OPTIMISM_SEPOLIA_CHAIN_ID,
            "Unsupported chain"
        );
        require(weth_ != address(0), "WETH address cannot be zero");
        require(bytes(name_).length > 0, "Name cannot be empty");
        require(bytes(symbol_).length > 0, "Symbol cannot be empty");

        creationCodeWithArgs[wethVault] = abi.encodePacked(
            wethVaultCreationCode,
            abi.encode(
                weth_,
                name_,
                symbol_,
                chainSlug_ == BASE_SEPOLIA_CHAIN_ID
                    ? address(spokePoolBase)
                    : chainSlug_ == OPTIMISM_SEPOLIA_CHAIN_ID ? address(spokePoolOptimism) : address(spokePoolArbitrum)
            )
        );

        _deploy(wethVault, chainSlug_, IsPlug.YES);

        emit ContractDeployed(chainSlug_, forwarderAddresses[wethVault][chainSlug_]);
    }

    /**
     * @dev Replication of the FundsDeposited event emitted by Across protocol Spoke Pool
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

    error OnlyRouter(address caller);

    modifier onlyRouter() {
        if (msg.sender != router) revert OnlyRouter(msg.sender);
        _;
    }

    /**
     * @notice Handles eth transfer intents with destination chain being Optimism Sepolia source chain being arbitrum sepolia
     * @param chainSlug_ The chain ID
     * @param payload_ The encoded message containing deposit information
     */
    function receiveIntent(uint32 chainSlug_, bytes calldata payload_) external onlyRouter {
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

    function fillIntent(V3SpokePoolInterface.V3RelayData memory relayData) public async {
        IVault(forwarderAddresses[wethVault][OPTIMISM_SEPOLIA_CHAIN_ID]).executeIntent(relayData);
        emit IntentExecuted(relayData.originChainId, relayData.depositId);
    }

    /**
     * @notice Updates the fee configuration
     * @param fees_ New fee configuration
     */
    function setFees(Fees memory fees_) external {
        fees = fees_;
    }

    /**
     * @notice Withdraws fee tokens from the SOCKET Protocol
     * @dev Allows withdrawal of accumulated fees to a specified receiver
     * @param chainSlug_ The chain from which to withdraw fees
     * @param token_ The token address to withdraw
     * @param amount_ The amount to withdraw
     * @param receiver_ The address that will receive the withdrawn fees
     */
    function withdrawFeeTokens(uint32 chainSlug_, address token_, uint256 amount_, address receiver_) external {
        _withdrawFeeTokens(chainSlug_, token_, amount_, receiver_);
    }

    /**
     * @notice Converts bytes32 to address without validation
     * @param _bytes32 The bytes32 to convert
     * @return The resulting address
     */
    function toAddressUnchecked(bytes32 _bytes32) internal pure returns (address) {
        return address(uint160(uint256(_bytes32)));
    }
}
