// SPDX-License-Identifier: MIT
pragma solidity ^0.8.29;

import {V3SpokePoolInterface} from "./across/V3SpokePoolInterface.sol";

/**
 * @title IVault
 * @notice Interface for the custom methods of the Vault contract that are not part of the ERC4626 interface
 */
interface IVault {
    /**
     * @notice Sets the address of the SpokePool contract
     * @param _spokePool Address of the SpokePool contract
     */
    function setSpokePool(address _spokePool) external;
    
    /**
     * @notice Returns the address of the SpokePool contract
     * @return The SpokePool interface
     */
    function spokePool() external view returns (V3SpokePoolInterface);
    
    /**
     * @notice Returns the timestamp after which deposits, withdrawals, and other actions are allowed
     * @return The timelock timestamp
     */
    function timelock() external view returns (uint256);
    
    /**
     * @notice Executes an intent by filling a relay through the SpokePool
     * @param relayData The relay data for the transaction
     */
    function executeIntent(V3SpokePoolInterface.V3RelayData memory relayData) external;
} 