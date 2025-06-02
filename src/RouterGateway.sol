// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "socket-protocol/evmx/base/AppGatewayBase.sol";
import "./SpokePoolWrapper.sol";
import "./interfaces/IStrategy.sol";

contract RouterGateway is AppGatewayBase {
    address public spokePoolArbitrum;
    address public spokePoolOptimism;
    uint32 public constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;
    uint32 public constant OPTIMISM_SEPOLIA_CHAIN_ID = 11155420;
    IStrategy[] public strategies;
    bytes public spokePoolWrapperCreationCode;
    bytes32 public immutable spokePoolWrapper;

    constructor(
        address addressResolver_,
        address spokePoolArbitrum_,
        address spokePoolOptimism_,
        bytes memory spokePoolWrapperCreationCode_,
        uint256 fees_
    ) AppGatewayBase(addressResolver_) {
        spokePoolWrapperCreationCode = spokePoolWrapperCreationCode_;
        spokePoolWrapper = _createContractId("SpokePoolWrapper");
        spokePoolArbitrum = spokePoolArbitrum_;
        spokePoolOptimism = spokePoolOptimism_;
        _setMaxFees(fees_);
    }

    function addStrategy(IStrategy strategy) external {
        strategies.push(IStrategy(strategy));
    }

    function deploySpokePoolWrapper(uint32 chainSlug_) external async(bytes("")) {
        creationCodeWithArgs[spokePoolWrapper] = abi.encodePacked(
            spokePoolWrapperCreationCode,
            abi.encode(
                chainSlug_ == OPTIMISM_SEPOLIA_CHAIN_ID ? address(spokePoolOptimism) : address(spokePoolArbitrum)
            )
        );
        _deploy(spokePoolWrapper, chainSlug_, IsPlug.YES);
    }

    function initialize(uint32 chainSlug_) public override async(bytes("")) {
        address onchainAddress = getOnChainAddress(spokePoolWrapper, chainSlug_);
        watcherPrecompileConfig().setIsValidPlug(chainSlug_, onchainAddress, true);
    }
    
    // Entry point for on chain trigger for intent processing. Forwards intents to registered strategies
    function notifyIntent(bytes calldata payload_, uint32 chainSlug_) external async(bytes("")) onlyWatcherPrecompile {
        for (uint256 i = 0; i < strategies.length; i++) {
            IStrategy(strategies[i]).processIntent(chainSlug_, payload_);
        }
    }
}
