// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "openzeppelin/contracts/token/ERC20/extensions/ERC4626.sol";
import "openzeppelin/contracts/token/ERC20/IERC20.sol";
import "socket-protocol/base/PlugBase.sol";
import {V3SpokePoolInterface} from "./interfaces/across/V3SpokePoolInterface.sol";

contract WETHVault is ERC4626, PlugBase {
    V3SpokePoolInterface public spokePool;
    uint256 public timelock;

    error TimelockActive();

    constructor(
        IERC20 _weth,
        string memory _name,
        string memory _symbol,
        address _spokePool
    ) ERC4626(_weth) ERC20(_name, _symbol) {
        spokePool = V3SpokePoolInterface(_spokePool);
    }

    function setSpokePool(address _spokePool) external onlySocket {
        spokePool = V3SpokePoolInterface(_spokePool);
    }

    modifier timelockPassed() {
        if (block.timestamp < timelock) {
            revert TimelockActive();
        }
        _;
    }

    function totalAssets() public view override returns (uint256) {
        return IERC20(asset()).balanceOf(address(this));
    }

    function executeIntent(
        V3SpokePoolInterface.V3RelayData memory relayData
    ) external onlySocket {
        require(
            relayData.outputAmount <= IERC20(asset()).balanceOf(address(this)),
            "Not enough assets"
        );
        timelock = block.timestamp + 1 days;
        IERC20(asset()).approve(address(spokePool), relayData.outputAmount);
        spokePool.fillRelay(
            relayData,
            block.chainid,
            bytes32(uint256(uint160(address(this))))
        );
    }

    /**
     * @dev Override deposit function to check timelock
     */
    function deposit(
        uint256 assets,
        address receiver
    ) public override timelockPassed returns (uint256) {
        return super.deposit(assets, receiver);
    }

    /**
     * @dev Override mint function to check timelock
     */
    function mint(
        uint256 shares,
        address receiver
    ) public override timelockPassed returns (uint256) {
        return super.mint(shares, receiver);
    }

    /**
     * @dev Override withdraw function to check timelock
     */
    function withdraw(
        uint256 assets,
        address receiver,
        address owner
    ) public override timelockPassed returns (uint256) {
        return super.withdraw(assets, receiver, owner);
    }

    /**
     * @dev Override redeem function to check timelock
     */
    function redeem(
        uint256 shares,
        address receiver,
        address owner
    ) public override timelockPassed returns (uint256) {
        return super.redeem(shares, receiver, owner);
    }
}
