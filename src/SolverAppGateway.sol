// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.29;

import "socket-protocol/base/AppGatewayBase.sol";
import {V3SpokePoolInterface} from "./interfaces/across/V3SpokePoolInterface.sol";
import "./SpokePoolWrapper.sol";

contract SolverAppGateway is AppGatewayBase {
    V3SpokePoolInterface spokePoolArbitrum;
    V3SpokePoolInterface spokePoolBase;

    uint32 public constant OP_SEPOLIA_CHAIN_ID = 11155420;
    uint32 public constant BASE_SEPOLIA_CHAIN_ID = 84532;

    address public constant OP_SEPOLIA_SPOKE_POOL = 0x6f26Bf09B1C792e3228e5467807a900A503c0281;
    address public constant BASE_SEPOLIA_SPOKE_POOL = 0x82B564983aE7274c86695917BBf8C99ECb6F0F8F;

    bytes32 public spokePoolWrapper = _createContractId("spokePoolWrapper");

    constructor(address addressResolver_, Fees memory fees_, address spokePoolArbitrum, address spokePoolBase)
        AppGatewayBase(addressResolver_)
    {
        creationCodeWithArgs[spokePoolWrapper] = abi.encodePacked(type(SpokePoolWrapper).creationCode);
        _setOverrides(fees_);
        spokePoolArbitrum = spokePoolArbitrum;
        spokePoolBase = spokePoolBase;
    }

    /**
     * @notice Deploys OnchainTrigger contracts to a specified chain
     * @dev Triggers an asynchronous multi-chain deployment via SOCKET Protocol
     * @param chainSlug_ The identifier of the target chain
     */
    function deployContracts(uint32 chainSlug_) external async {
        _deploy(spokePoolWrapper, chainSlug_, IsPlug.YES);
    }

    /**
     * @notice Initialize function required by AppGatewayBase
     * @dev Sets up the validity of the deployed OnchainTrigger contract on the specified chain
     * @param chainSlug_ The identifier of the chain where the contract was deployed
     */
    function initialize(uint32 chainSlug_) public override {
        address onchainAddress = getOnChainAddress(spokePoolWrapper, chainSlug_);
        address spokePool;
        if (chainSlug_ == BASE_SEPOLIA_CHAIN_ID) {
            spokePool = BASE_SEPOLIA_SPOKE_POOL;
        } else {
            spokePool = OP_SEPOLIA_SPOKE_POOL;
        }
        SpokePoolWrapper(onchainAddress).setSpokePool(spokePool);
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
    function callFromChain(uint32, address, bytes32, bytes calldata payload_)
        external
        override
        async
        onlyWatcherPrecompile
    {
        FundsDepositedParams memory params = abi.decode(payload_, (FundsDepositedParams));
    }

    /**
     * @notice Updates the fee configuration
     * @dev Allows modification of fee settings for onchain operations
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
}
