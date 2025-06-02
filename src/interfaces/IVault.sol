// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {V3SpokePoolInterface} from "./across/V3SpokePoolInterface.sol";

interface IVault {
    function spokePool() external view returns (V3SpokePoolInterface);
    function executeIntent(V3SpokePoolInterface.V3RelayData memory relayData) external;
}
