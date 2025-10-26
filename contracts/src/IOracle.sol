// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title IOracle - Chainlink Oracle Interface
 * @dev Interface for Chainlink price feed oracle
 */
interface IOracle {
    /**
     * @notice Get the latest price from the oracle
     * @return Latest price with 8 decimals
     */
    function latestAnswer() external view returns (int256);
}