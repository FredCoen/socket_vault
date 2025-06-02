// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {V3SpokePoolInterface} from "./interfaces/across/V3SpokePoolInterface.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

library Bytes32ToAddress {
    function toAddress(bytes32 _bytes) internal pure returns (address) {
        return address(uint160(uint256(_bytes)));
    }
}

contract Executor {
    using Bytes32ToAddress for bytes32;

    V3SpokePoolInterface public immutable spokePool;
    address public owner;

    mapping(address => bool) public whitelistedVaults;

    event VaultWhitelisted(address indexed vault, bool status);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    modifier onlyOwner() {
        require(msg.sender == owner, "Executor: caller is not the owner");
        _;
    }

    modifier onlyWhitelistedVault() {
        require(whitelistedVaults[msg.sender], "Executor: caller is not a whitelisted vault");
        _;
    }

    constructor(V3SpokePoolInterface _spokePool) {
        spokePool = _spokePool;
        owner = msg.sender;
    }

    function setVaultStatus(address vault, bool status) external onlyOwner {
        whitelistedVaults[vault] = status;
        emit VaultWhitelisted(vault, status);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Executor: new owner is the zero address");
        address oldOwner = owner;
        owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }

    function executeIntent(V3SpokePoolInterface.V3RelayData memory relayData) external onlyWhitelistedVault {
        IERC20(relayData.outputToken.toAddress()).approve(address(spokePool), relayData.outputAmount);
        spokePool.fillRelay(relayData, block.chainid, bytes32(uint256(uint160(msg.sender))));
    }
}
