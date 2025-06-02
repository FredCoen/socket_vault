// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "socket-protocol/protocol/base/PlugBase.sol";
import {V3SpokePoolInterface} from "./interfaces/across/V3SpokePoolInterface.sol";
import {IVault} from "./interfaces/IVault.sol";
import {Executor} from "./Executor.sol";

contract WETHVault is IVault, ERC4626, PlugBase {
    using SafeERC20 for IERC20;

    uint256 public totalGrossFeesEarned;
    Executor public immutable executor;
    V3SpokePoolInterface public immutable spokePool;

    error InsufficientAssets();
    error NegativeFee();

    event IntentExecuted(uint256 outputAmount, uint256 inputAmount, uint256 depositId, uint256 originChainId);

    constructor(IERC20 _weth, string memory _name, string memory _symbol, address _spokePool, address _executor)
        ERC4626(_weth)
        ERC20(_name, _symbol)
    {
        executor = Executor(_executor);
        spokePool = V3SpokePoolInterface(_spokePool);
    }

    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

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
