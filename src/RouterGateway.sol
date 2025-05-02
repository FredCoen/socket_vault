// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "socket-protocol/base/AppGatewayBase.sol";
import {V3SpokePoolInterface} from "./interfaces/across/V3SpokePoolInterface.sol";
import "./SpokePoolWrapper.sol";
import {WETHVault} from "./Vault.sol";
import {IVault} from "./interfaces/IVault.sol";
import "./interfaces/IStrategy.sol";

/**
 * @title RouterGateway
 */
contract RouterGateway is AppGatewayBase {
    // Addresses of the spoke pools on different chains
    address public spokePoolArbitrum;
    address public spokePoolBase;
    address public spokePoolOptimism;

    /// @notice Chain ID constant for Arbitrum Sepolia
    uint32 public constant ARBITRUM_SEPOLIA_CHAIN_ID = 421614;

    /// @notice Chain ID constant for Base Sepolia
    uint32 public constant BASE_SEPOLIA_CHAIN_ID = 84532;

    uint32 public constant OPTIMISM_SEPOLIA_CHAIN_ID = 11155420;

    IStrategy[] public strategies;

    event ContractDeployed(uint32 indexed chainSlug, address spokePoolWrapperAddress);

    /// @notice Creation code for SpokePoolWrapper
    bytes public spokePoolWrapperCreationCode;

    /// @notice Contract ID for SpokePoolWrapper
    bytes32 public immutable spokePoolWrapper;

    constructor(
        address addressResolver_,
        address spokePoolArbitrum_,
        address spokePoolBase_,
        address spokePoolOptimism_,
        bytes memory spokePoolWrapperCreationCode_,
        Fees memory fees_
    ) AppGatewayBase(addressResolver_) {
        require(spokePoolWrapperCreationCode_.length > 0, "SpokePoolWrapper creation code cannot be empty");
        spokePoolWrapperCreationCode = spokePoolWrapperCreationCode_;
        spokePoolWrapper = _createContractId("SpokePoolWrapper");

        spokePoolArbitrum = spokePoolArbitrum_;
        spokePoolBase = spokePoolBase_;
        spokePoolOptimism = spokePoolOptimism_;

        _setOverrides(fees_);
    }

    function addStrategy(IStrategy strategy) external {
        strategies.push(IStrategy(strategy));
    }

    function deploySpokePoolWrapper(uint32 chainSlug_) external async {
        require(
            chainSlug_ == ARBITRUM_SEPOLIA_CHAIN_ID || chainSlug_ == BASE_SEPOLIA_CHAIN_ID
                || chainSlug_ == OPTIMISM_SEPOLIA_CHAIN_ID,
            "Unsupported chain"
        );

        creationCodeWithArgs[spokePoolWrapper] = abi.encodePacked(
            spokePoolWrapperCreationCode,
            abi.encode(
                chainSlug_ == BASE_SEPOLIA_CHAIN_ID
                    ? address(spokePoolBase)
                    : chainSlug_ == OPTIMISM_SEPOLIA_CHAIN_ID ? address(spokePoolOptimism) : address(spokePoolArbitrum)
            )
        );
        _deploy(spokePoolWrapper, chainSlug_, IsPlug.YES);

        emit ContractDeployed(chainSlug_, forwarderAddresses[spokePoolWrapper][chainSlug_]);
    }

    /**
     * @notice Runs after deployment to give permissions and set post deployment state
     * @dev Gives permission to the SpokePoolWrapper to interact with the Socket
     * @param chainSlug_ The identifier of the chain where the contracts were deployed
     */
    function initialize(uint32 chainSlug_) public override async {
        address onchainAddress = getOnChainAddress(spokePoolWrapper, chainSlug_);
        watcherPrecompileConfig().setIsValidPlug(chainSlug_, onchainAddress, true);
    }

    function callFromChain(uint32 chainSlug_, address, bytes32, bytes calldata payload_)
        external
        override
        async
        onlyWatcherPrecompile
    {
        for (uint256 i = 0; i < strategies.length; i++) {
            IStrategy(strategies[i]).receiveIntent(chainSlug_, payload_);
        }
    }
}
