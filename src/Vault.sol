// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "socket-protocol/protocol/base/PlugBase.sol";
import {V3SpokePoolInterface} from "./interfaces/across/V3SpokePoolInterface.sol";
import {IVault} from "./interfaces/IVault.sol";

/**
 * @title WETHVault
 * @notice An ERC4626 compliant vault for WETH that interacts with Across Protocol
 * @dev Implements a simplified timelock mechanism to uphold accounting during cross-chain operations
 *      This is an mvp to show end to end flow. Deposits and withdrawals can be DoSed
 */
contract WETHVault is IVault, ERC4626, PlugBase {
    using SafeERC20 for IERC20;

    uint256 public totalGrossFeesEarned;


    /**
     * @notice The Across Protocol SpokePool contract
     */
    V3SpokePoolInterface public immutable spokePool;

    /**
     * @notice Timestamp until which deposits and withdrawals are locked
     * @dev Set after executing an intent to prevent front-running
     */
    uint256 public timelock;

    /**
     * @dev Error thrown when an operation is attempted while the timelock is active
     */
    error TimelockActive();

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
     */
    constructor(IERC20 _weth, string memory _name, string memory _symbol, address _spokePool)
        ERC4626(_weth)
        ERC20(_name, _symbol)
    {
        spokePool = V3SpokePoolInterface(_spokePool);
    }

    /**
     * @notice Modifier to ensure the timelock period has passed
     * @dev Reverts if the current timestamp is less than the timelock
     */
    modifier timelockPassed() {
        if (block.timestamp < timelock) {
            revert TimelockActive();
        }
        _;
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
        // give time for intent to settle
        timelock = block.timestamp + 1 hours;
        IERC20(asset()).approve(address(spokePool), relayData.outputAmount);
        spokePool.fillRelay(relayData, block.chainid, bytes32(uint256(uint160(address(this)))));
        if (relayData.outputAmount > relayData.inputAmount) {
            revert NegativeFee();
        }
        totalGrossFeesEarned += relayData.inputAmount - relayData.outputAmount;
        emit IntentExecuted(relayData.outputAmount, relayData.inputAmount, relayData.depositId, relayData.originChainId);
    }

    /**
     * @dev Override deposit function to check timelock
     * @param assets The amount of assets to deposit
     * @param receiver The address that will receive the shares
     * @return shares The amount of shares minted
     */
    function deposit(uint256 assets, address receiver) public override timelockPassed returns (uint256) {
        return super.deposit(assets, receiver);
    }

    /**
     * @dev Override mint function to check timelock
     * @param shares The amount of shares to mint
     * @param receiver The address that will receive the shares
     * @return assets The amount of assets deposited
     */
    function mint(uint256 shares, address receiver) public override timelockPassed returns (uint256) {
        return super.mint(shares, receiver);
    }

    /**
     * @dev Override withdraw function to check timelock
     * @param assets The amount of assets to withdraw
     * @param receiver The address that will receive the assets
     * @param owner The address that owns the shares
     * @return shares The amount of shares burned
     */
    function withdraw(uint256 assets, address receiver, address owner)
        public
        override
        timelockPassed
        returns (uint256)
    {
        return super.withdraw(assets, receiver, owner);
    }

    /**
     * @dev Override redeem function to check timelock
     * @param shares The amount of shares to redeem
     * @param receiver The address that will receive the assets
     * @param owner The address that owns the shares
     * @return assets The amount of assets withdrawn
     */
    function redeem(uint256 shares, address receiver, address owner) public override timelockPassed returns (uint256) {
        return super.redeem(shares, receiver, owner);
    }
}
