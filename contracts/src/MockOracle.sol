// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title MockOracle - Simulates Chainlink Oracle for Local Testing
 * @dev Provides ETH/USD prices for local development
 */
contract MockOracle {
    int256 public price;
    address public owner;
    
    event PriceUpdated(int256 newPrice);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }
    
    constructor(int256 _initialPrice) {
        price = _initialPrice;
        owner = msg.sender;
    }
    
    function latestAnswer() external view returns (int256) {
        return price;
    }
    
    function setPrice(int256 newPrice) external onlyOwner {
        price = newPrice;
        emit PriceUpdated(newPrice);
    }
    
    // Chainlink compatibility
    function latestRoundData() external view returns (
        uint80 roundId,
        int256 answer,
        uint256 startedAt,
        uint256 updatedAt,
        uint80 answeredInRound
    ) {
        return (0, price, block.timestamp, block.timestamp, 0);
    }
}