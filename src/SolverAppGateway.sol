// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "socket-protocol/base/AppGatewayBase.sol";
import {V3SpokePoolInterface} from "./interfaces/across/V3SpokePoolInterface.sol";
import "./SpokePoolWrapper.sol";
import {WETHVault} from "./Vault.sol";
import {IVault} from "./interfaces/IVault.sol";

interface ISpokePoolWrapper {
    function setSpokePool(address spokePool_) external;
}

contract SolverAppGateway is AppGatewayBase {
    V3SpokePoolInterface spokePoolArbitrum;
    V3SpokePoolInterface spokePoolBase;

    uint32 public constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    uint32 public constant BASE_SEPOLIA_CHAIN_ID = 84532;
    address public constant WETH_ARBITRUM = 0x980B62Da83eFf3D4576C647993b0c1D7faf17c73;
    address public constant WETH_BASE = 0x4200000000000000000000000000000000000006;
    bytes32 public spokePoolWrapper = _createContractId("SpokePoolWrapper");
    bytes32 public wethVault = _createContractId("WETHVault");
    bytes wethVaultCreationCode;
    bytes spokePoolWrapperCreationCode;

    constructor(
        address addressResolver_,
        Fees memory fees_,
        address spokePoolArbitrum_,
        address spokePoolBase_,
        bytes memory spokePoolWrapperCreationCode_,
        bytes memory wethVaultCreationCode_
    ) AppGatewayBase(addressResolver_) {
        spokePoolWrapperCreationCode = spokePoolWrapperCreationCode_;
        wethVaultCreationCode = wethVaultCreationCode_;

        _setOverrides(fees_);
        spokePoolArbitrum = V3SpokePoolInterface(spokePoolArbitrum_);
        spokePoolBase = V3SpokePoolInterface(spokePoolBase_);
    }

    function deployContracts(uint32 chainSlug_, address weth_, string memory name_, string memory symbol_)
        external
        async
    {
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
    }

    /**
     * @notice Initialize function required by AppGatewayBase
     * @dev Sets up the validity of the deployed OnchainTrigger contract on the specified chain
     * @param chainSlug_ The identifier of the chain where the contract was deployed
     */
    function initialize(uint32 chainSlug_) public override async {
        ISpokePoolWrapper(forwarderAddresses[spokePoolWrapper][chainSlug_]).setSpokePool(
            chainSlug_ == BASE_SEPOLIA_CHAIN_ID ? address(spokePoolBase) : address(spokePoolArbitrum)
        );

        IVault(forwarderAddresses[wethVault][chainSlug_]).setSpokePool(
            chainSlug_ == BASE_SEPOLIA_CHAIN_ID ? address(spokePoolBase) : address(spokePoolArbitrum)
        );
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

    /**
     * @notice Serves as a notifier for the AppGatway that an intent needs to be filled
     *
     * @param payload_ The encoded message contains all the relevant information to fill the intent.
     *        It contains identical data to the Across SpokePool emitted events to solvers
     */
    function callFromChain(uint32 chainSlug_, address, bytes32, bytes calldata payload_)
        external
        override
        async
        onlyWatcherPrecompile
    {
        FundsDepositedParams memory params = abi.decode(payload_, (FundsDepositedParams));
        if (
            uint32(uint256(params.destinationChainId)) == ARBITRUM_SEPOLIA_CHAIN_ID
                && toAddressUnchecked(params.outputToken) == WETH_ARBITRUM
                && toAddressUnchecked(params.inputToken) == WETH_BASE && chainSlug_ == BASE_SEPOLIA_CHAIN_ID
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
            IVault(forwarderAddresses[wethVault][chainSlug_]).executeIntent(relayData);
        }
    }

    /**
     * @notice Updates the fee configuration
     * @dev Allows modification of fee settings for onchain operations
     *  /**
     * @param fees_ New fee configuration
     */
    function setFees(Fees memory fees_) public {
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

    function toAddressUnchecked(bytes32 _bytes32) internal pure returns (address) {
        return address(uint160(uint256(_bytes32)));
    }
}
