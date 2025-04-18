// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "socket-protocol/base/AppGatewayBase.sol";
import {V3SpokePoolInterface} from "./interfaces/across/V3SpokePoolInterface.sol";
import "./SpokePoolWrapper.sol";
import {WETHVault} from "./Vault.sol";
import {IVault} from "./interfaces/IVault.sol";

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
contract SolverAppGateway is AppGatewayBase {
    /// @notice Across V3 SpokePool on Arbitrum
    V3SpokePoolInterface public immutable spokePoolArbitrum;
    
    /// @notice Across V3 SpokePool on Base
    V3SpokePoolInterface public immutable spokePoolBase;

    /// @notice Chain ID constant for Arbitrum Sepolia
    uint32 public constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    
    /// @notice Chain ID constant for Base Sepolia
    uint32 public constant BASE_SEPOLIA_CHAIN_ID = 84532;
    
    /// @notice WETH address on Arbitrum
    address public constant WETH_ARBITRUM = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;
    
    /// @notice WETH address on Base
    address public constant WETH_BASE = 0x4200000000000000000000000000000000000006;
    
    /// @notice Contract ID for SpokePoolWrapper
    bytes32 public immutable spokePoolWrapper;
    
    /// @notice Contract ID for WETHVault
    bytes32 public immutable wethVault;
    
    /// @notice Creation code for WETHVault
    bytes public immutable wethVaultCreationCode;
    
    /// @notice Creation code for SpokePoolWrapper
    bytes public immutable spokePoolWrapperCreationCode;

    /**
     * @dev Error thrown when an intent is invalid
     * @param reason The reason why the intent is invalid
     */
    error InvalidIntent(string reason);

    /**
     * @notice Emitted when contracts are deployed to a chain
     * @param chainSlug The chain ID where contracts were deployed
     * @param spokePWrapperAddress The deployed SpokePoolWrapper address
     * @param wethVaultAddress The deployed WETHVault address
     */
    event ContractsDeployed(
        uint32 indexed chainSlug,
        address spokePWrapperAddress,
        address wethVaultAddress
    );

    /**
     * @notice Emitted when an intent is executed
     * @param originChainId The chain ID where the deposit originated
     * @param depositId The deposit ID in the Across protocol
     * @param amount The amount being relayed
     */
    event IntentExecuted(
        uint32 indexed originChainId,
        uint256 indexed depositId,
        uint256 amount
    );

    /**
     * @notice Constructor sets initial parameters for the gateway
     * @param addressResolver_ The address resolver for Socket Protocol
     * @param fees_ The fee configuration
     * @param spokePoolArbitrum_ The Across SpokePool address on Arbitrum
     * @param spokePoolBase_ The Across SpokePool address on Base
     * @param spokePoolWrapperCreationCode_ The creation code for SpokePoolWrapper
     * @param wethVaultCreationCode_ The creation code for WETHVault
     */
    constructor(
        address addressResolver_,
        Fees memory fees_,
        address spokePoolArbitrum_,
        address spokePoolBase_,
        bytes memory spokePoolWrapperCreationCode_,
        bytes memory wethVaultCreationCode_
    ) AppGatewayBase(addressResolver_) {
        require(addressResolver_ != address(0), "Address resolver cannot be zero");
        require(spokePoolArbitrum_ != address(0), "Arbitrum SpokePool cannot be zero");
        require(spokePoolBase_ != address(0), "Base SpokePool cannot be zero");
        require(spokePoolWrapperCreationCode_.length > 0, "SpokePoolWrapper creation code cannot be empty");
        require(wethVaultCreationCode_.length > 0, "WETHVault creation code cannot be empty");
        
        spokePoolWrapperCreationCode = spokePoolWrapperCreationCode_;
        wethVaultCreationCode = wethVaultCreationCode_;
        spokePoolWrapper = _createContractId("SpokePoolWrapper");
        wethVault = _createContractId("WETHVault");

        _setOverrides(fees_);
        spokePoolArbitrum = V3SpokePoolInterface(spokePoolArbitrum_);
        spokePoolBase = V3SpokePoolInterface(spokePoolBase_);
    }

    /**
     * @notice Deploy SpokePoolWrapper and WETHVault contracts to a chain
     * @param chainSlug_ The chain ID where to deploy the contracts
     * @param weth_ The WETH token address on the target chain
     * @param name_ The name for the vault token
     * @param symbol_ The symbol for the vault token
     */
    function deployContracts(uint32 chainSlug_, address weth_, string memory name_, string memory symbol_)
        external
        async
    {
        require(chainSlug_ == ARBITRUM_SEPOLIA_CHAIN_ID || chainSlug_ == BASE_SEPOLIA_CHAIN_ID, "Unsupported chain");
        require(weth_ != address(0), "WETH address cannot be zero");
        require(bytes(name_).length > 0, "Name cannot be empty");
        require(bytes(symbol_).length > 0, "Symbol cannot be empty");
        
        creationCodeWithArgs[wethVault] = abi.encodePacked(
            wethVaultCreationCode,
            abi.encode(
                weth_,
                name_,
                symbol_,
                chainSlug_ == BASE_SEPOLIA_CHAIN_ID ? address(spokePoolBase) : address(spokePoolArbitrum)
            )
        );

        creationCodeWithArgs[spokePoolWrapper] = abi.encodePacked(
            spokePoolWrapperCreationCode,
            abi.encode(chainSlug_ == BASE_SEPOLIA_CHAIN_ID ? address(spokePoolBase) : address(spokePoolArbitrum))
        );
        _deploy(spokePoolWrapper, chainSlug_, IsPlug.YES);
        _deploy(wethVault, chainSlug_, IsPlug.YES);
        
        emit ContractsDeployed(
            chainSlug_,
            forwarderAddresses[spokePoolWrapper][chainSlug_],
            forwarderAddresses[wethVault][chainSlug_]
        );
    }

    /**
     * @notice Runs after deployment to give permissions and set post deployment state
     * @dev Gives permission to the SpokePoolWrapper to interact with the Socket
     * @param chainSlug_ The identifier of the chain where the contracts were deployed
     */
    function initialize(uint32 chainSlug_) public override async {

        
        address spokePoolAddress = chainSlug_ == BASE_SEPOLIA_CHAIN_ID 
            ? address(spokePoolBase) 
            : address(spokePoolArbitrum);
        
        address onchainAddress = getOnChainAddress(spokePoolWrapper, chainSlug_);
        watcherPrecompileConfig().setIsValidPlug(chainSlug_, onchainAddress, true);
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

    /**
     * @notice Handles intents being submitted 
     * @param chainSlug_ The chain ID
     * @param payload_ The encoded message containing deposit information
     */
    function callFromChain(uint32 chainSlug_, address, bytes32, bytes calldata payload_)
        external
        override
        async
        onlyWatcherPrecompile
    {
        FundsDepositedParams memory params = abi.decode(payload_, (FundsDepositedParams));
        if (
            uint32(uint256(params.destinationChainId)) == BASE_SEPOLIA_CHAIN_ID
                && toAddressUnchecked(params.outputToken) == WETH_BASE
                && toAddressUnchecked(params.inputToken) == WETH_ARBITRUM 
                && chainSlug_ == ARBITRUM_SEPOLIA_CHAIN_ID
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
            IVault(forwarderAddresses[wethVault][BASE_SEPOLIA_CHAIN_ID]).executeIntent(relayData);
            
            emit IntentExecuted(
                chainSlug_,
                params.acrossDepositId,
                params.outputAmount
            );
        } else {
    
                revert InvalidIntent("Unsupported intent");
            }
        }
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
