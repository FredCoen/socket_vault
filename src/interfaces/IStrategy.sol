// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

interface IStrategy {
    function processIntent(uint32 chainSlug_, bytes calldata payload_) external;
}
