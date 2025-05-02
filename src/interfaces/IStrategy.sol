// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IStrategy {
    function receiveIntent(uint32 chainSlug_, bytes calldata payload_) external;
}
