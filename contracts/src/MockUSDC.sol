// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title MockUSDC - Mock USDC Token for Testing
 * @dev ERC-20 compatible token for testing purposes only
 */
contract MockUSDC {
    string public name = "Mock USDC";
    string public symbol = "USDC";
    uint8 public decimals = 6;
    
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    
    uint256 public totalSupply;
    address public owner;
    
    /**
     * @notice Emitted when tokens are transferred
     * @param from Address sending tokens
     * @param to Address receiving tokens
     * @param value Amount of tokens transferred
     */
    event Transfer(address indexed from, address indexed to, uint256 value);
    
    /**
     * @notice Emitted when allowance is set
     * @param owner Address of token owner
     * @param spender Address of approved spender
     * @param value Allowance amount
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
    
    /**
     * @notice Constructor mints initial supply to deployer
     */
    constructor() {
        owner = msg.sender;
        // Mint 1,000,000 USDC for the deployer
        _mint(msg.sender, 1000000 * 10**6);
    }
    
    /**
     * @notice Internal mint function
     * @param to Address to receive tokens
     * @param value Amount to mint
     */
    function _mint(address to, uint256 value) internal {
        totalSupply += value;
        balanceOf[to] += value;
        emit Transfer(address(0), to, value);
    }
    
    /**
     * @notice Transfer tokens
     * @param to Recipient address
     * @param value Amount to transfer
     * @return Success boolean
     */
    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        emit Transfer(msg.sender, to, value);
        return true;
    }
    
    /**
     * @notice Approve spender
     * @param spender Address to approve
     * @param value Allowance amount
     * @return Success boolean
     */
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
    /**
     * @notice Transfer tokens from approved allowance
     * @param from Address to transfer from
     * @param to Recipient address
     * @param value Amount to transfer
     * @return Success boolean
     */
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        
        balanceOf[from] -= value;
        balanceOf[to] += value;
        allowance[from][msg.sender] -= value;
        
        emit Transfer(from, to, value);
        return true;
    }
    
    /**
     * @notice Mint new tokens (owner only)
     * @param to Address to receive tokens
     * @param amount Amount to mint
     */
    function mint(address to, uint256 amount) external {
        require(msg.sender == owner, "Only owner can mint");
        _mint(to, amount);
    }
    
    /**
     * @notice Burn tokens
     * @param amount Amount to burn
     */
    function burn(uint256 amount) external {
        require(balanceOf[msg.sender] >= amount, "Insufficient balance");
        balanceOf[msg.sender] -= amount;
        totalSupply -= amount;
        emit Transfer(msg.sender, address(0), amount);
    }
}