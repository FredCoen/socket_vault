// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "socket-protocol/protocol/base/PlugBase.sol";
import {V3SpokePoolInterface} from "./interfaces/across/V3SpokePoolInterface.sol";
import {IVault} from "./interfaces/IVault.sol";
import {Executor} from "./Executor.sol";

/**
 * @title WETHVault
 * @notice An ERC4626 compliant vault for WETH that interacts with Across Protocol
 */
contract WETHVault is IVault, ERC4626, PlugBase {
    using SafeERC20 for IERC20;

    uint256 public totalGrossFeesEarned;
    Executor public immutable executor;
    V3SpokePoolInterface public immutable spokePool;

     /**
     * @dev Error thrown when there are insufficient assets to execute an intent
     */
    error InsufficientAssets();

    /**
     * @dev Error thrown when the fee is negative
     */
    error NegativeFee();

    /**
     * @notice Emitted when an intent is executed through this vault
     * @param outputAmount The amount of tokens used to fill the relay
     * @param depositId The deposit ID being filled
     * @param originChainId The chain ID where the deposit originated
     */
    event IntentExecuted(uint256 outputAmount, uint256 inputAmount, uint256 depositId, uint256 originChainId);

    /**
     * @notice Constructor sets initial parameters
     * @param _weth The WETH token address
     * @param _name The name of the vault token
     * @param _symbol The symbol of the vault token
     * @param _spokePool The address of the Across SpokePool
     * @param _executor The address of the Executor contract
     */
    constructor(IERC20 _weth, string memory _name, string memory _symbol, address _spokePool, address _executor)
        ERC4626(_weth)
        ERC20(_name, _symbol)
    {   
        executor = Executor(_executor);
        spokePool = V3SpokePoolInterface(_spokePool);
     }



    /**
     * @notice Returns the total assets held by the vault
     * @return The total asset amount
     */
    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    /**
     * @notice Executes an intent by filling a relay through the SpokePool
     * @param relayData The relay data for the transaction
     * @dev Can only be called by the Socket contract
     */
    function executeIntent(V3SpokePoolInterface.V3RelayData memory relayData) external override onlySocket {
         uint256 assetBalance = IERC20(asset()).balanceOf(address(this));
        if (relayData.outputAmount > assetBalance) {
            revert InsufficientAssets();
        }

        IERC20(asset()).transfer(address(executor), relayData.outputAmount);

        executor.executeIntent(relayData);
        if (relayData.outputAmount > relayData.inputAmount) {
            revert NegativeFee();
        }
        totalGrossFeesEarned += relayData.inputAmount - relayData.outputAmount;
        emit IntentExecuted(relayData.outputAmount, relayData.inputAmount, relayData.depositId, relayData.originChainId);
    }
}
