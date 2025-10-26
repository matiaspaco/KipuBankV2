// SPDX-License-Identifier: MIT
pragma solidity 0.8.26;

/**
 * @title KipuBankV2 - Multi-Token Bank with Chainlink Oracle
 * @dev Enhanced version with ETH/USDC support, oracles and NFT reward system
 */
contract KipuBankV2 {
    // ============ TYPES ============
    /**
     * @notice Structure to store user token balances
     * @param nativeBalance ETH balance of the user
     * @param usdcBalance USDC token balance of the user
     * @param totalUSDValue Total balance value in USD (8 decimals)
     * @param pendingWithdrawalETH Pending ETH withdrawal amount
     * @param pendingWithdrawalUSDC Pending USDC withdrawal amount
     */
    struct TokenBalance {
        uint256 nativeBalance;
        uint256 usdcBalance;
        uint256 totalUSDValue;
        uint256 pendingWithdrawalETH;
        uint256 pendingWithdrawalUSDC;
    }
    
    /**
     * @notice Structure to store bank statistics
     * @param depositsOps Total number of deposit operations
     * @param withdrawalOps Total number of withdrawal operations
     * @param totalBalance Total ETH balance of the contract
     * @param users Total number of unique users
     */
    struct BankStats {
        uint256 depositsOps;
        uint256 withdrawalOps;
        uint256 totalBalance;
        uint256 users;
    }

    // ============ CONSTANTS ============
    uint256 public constant USD_DECIMALS = 8;
    uint256 public constant ETH_DECIMALS = 18;
    uint256 public constant USDC_DECIMALS = 6;
    uint256 public constant NFT_THRESHOLD = 1000 * 10**USD_DECIMALS; // 1000 USD threshold for NFT reward

    // ============ IMMUTABLES ============
    uint256 public immutable maxWithdrawalAmount;
    uint256 public immutable bankCapUSD;
    address public immutable owner;

    // ============ STORAGE ============
    address public oracle;
    address public usdcToken;
    address public kipuNFT;
    
    mapping(address => TokenBalance) public balances;
    mapping(address => uint256) public depositCount;
    mapping(address => uint256) public withdrawalCount;
    mapping(address => bool) public hasReceivedNFT;
    
    address[] private userAddresses;
    
    uint256 public totalDepositOps;
    uint256 public totalWithdrawalOps;
    
    bool private reentrancyLock;

    // ============ EVENTS ============
    /**
     * @notice Emitted when a deposit is made
     * @param user Address of the user who deposited
     * @param token Address of the token deposited (address(0) for ETH)
     * @param amount Amount deposited
     * @param usdValue USD value of the deposit
     */
    event Deposit(address indexed user, address indexed token, uint256 amount, uint256 usdValue);
    
    /**
     * @notice Emitted when a withdrawal is requested
     * @param user Address of the user requesting withdrawal
     * @param token Address of the token to withdraw
     * @param amount Amount requested for withdrawal
     */
    event WithdrawalRequested(address indexed user, address indexed token, uint256 amount);
    
    /**
     * @notice Emitted when a withdrawal is completed
     * @param user Address of the user who completed withdrawal
     * @param token Address of the token withdrawn
     * @param amount Amount withdrawn
     */
    event WithdrawalCompleted(address indexed user, address indexed token, uint256 amount);
    
    /**
     * @notice Emitted when bank cap is reached
     * @param currentBalanceUSD Current total balance in USD
     * @param capUSD Bank cap in USD
     */
    event BankCapReached(uint256 currentBalanceUSD, uint256 capUSD);
    
    /**
     * @notice Emitted when oracle is updated
     * @param newOracle Address of the new oracle
     */
    event OracleUpdated(address indexed newOracle);
    
    /**
     * @notice Emitted when user earns NFT
     * @param user Address of the user who earned NFT
     */
    event NFTEarned(address indexed user);

    // ============ ERRORS ============
    error ZeroAmount();
    error ExceedsBankCap(uint256 attempted, uint256 cap);
    error ExceedsMaxWithdrawal(uint256 requested, uint256 maxAllowed);
    error InsufficientBalance(uint256 requested, uint256 available);
    error OnlyOwner(address caller);
    error Reentrancy();
    error TransferFailed();

    // ============ MODIFIERS ============
    /**
     * @notice Modifier to restrict access to owner only
     */
    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner(msg.sender);
        _;
    }

    /**
     * @notice Modifier to prevent reentrancy attacks
     */
    modifier nonReentrant() {
        if (reentrancyLock) revert Reentrancy();
        reentrancyLock = true;
        _;
        reentrancyLock = false;
    }

    /**
     * @notice Modifier to ensure amount is not zero
     * @param amount Amount to check
     */
    modifier nonZeroAmount(uint256 amount) {
        if (amount == 0) revert ZeroAmount();
        _;
    }

    // ============ CONSTRUCTOR ============
    /**
     * @notice Deploys the KipuBankV2 contract
     * @param _maxWithdrawalAmount Maximum allowed withdrawal per request in wei
     * @param _bankCapUSD Maximum total USD balance allowed in the bank (8 decimals)
     * @param _usdcToken Address of the USDC token contract
     * @param _oracle Address of the Chainlink oracle contract
     */
    constructor(
        uint256 _maxWithdrawalAmount,
        uint256 _bankCapUSD,
        address _usdcToken,
        address _oracle
    ) {
        if (_maxWithdrawalAmount == 0) revert ZeroAmount();
        if (_bankCapUSD == 0) revert ZeroAmount();

        maxWithdrawalAmount = _maxWithdrawalAmount;
        bankCapUSD = _bankCapUSD;
        usdcToken = _usdcToken;
        oracle = _oracle;
        owner = msg.sender;
    }

    // ============ DEPOSIT FUNCTIONS ============
    /**
     * @notice Deposit ETH into the bank
     * @dev Uses reentrancy guard and non-zero amount modifier
     */
    function depositETH() external payable nonReentrant nonZeroAmount(msg.value) {
        _handleDepositETH(msg.sender, msg.value);
    }

    /**
     * @notice Deposit USDC tokens into the bank
     * @param amount Amount of USDC to deposit (6 decimals)
     * @dev Requires prior approval of USDC tokens to this contract
     */
    function depositUSDC(uint256 amount) external nonReentrant nonZeroAmount(amount) {
        // Transfer USDC from the user
        (bool success, ) = usdcToken.call(
            abi.encodeWithSignature("transferFrom(address,address,uint256)", msg.sender, address(this), amount)
        );
        require(success, "USDC transfer failed");
        
        _handleDepositUSDC(msg.sender, amount);
    }

    /**
     * @notice Internal function to handle ETH deposits
     * @param from Address of the depositor
     * @param amount Amount of ETH deposited
     */
    function _handleDepositETH(address from, uint256 amount) private {
        uint256 usdValue = _calculateETHValue(amount);
        _updateBalancesAfterDeposit(from, address(0), amount, usdValue);
    }

    /**
     * @notice Internal function to handle USDC deposits
     * @param from Address of the depositor
     * @param amount Amount of USDC deposited
     */
    function _handleDepositUSDC(address from, uint256 amount) private {
        uint256 usdValue = _calculateUSDCValue(amount);
        _updateBalancesAfterDeposit(from, usdcToken, amount, usdValue);
    }

    /**
     * @notice Internal function to update balances after deposit
     * @param from Address of the depositor
     * @param token Address of the token deposited
     * @param amount Amount deposited
     * @param usdValue USD value of the deposit
     */
    function _updateBalancesAfterDeposit(address from, address token, uint256 amount, uint256 usdValue) private {
        // Check bank cap
        uint256 currentTotalUSD = _getTotalBalanceUSD();
        if (currentTotalUSD + usdValue > bankCapUSD) {
            emit BankCapReached(currentTotalUSD + usdValue, bankCapUSD);
            revert ExceedsBankCap(currentTotalUSD + usdValue, bankCapUSD);
        }

        TokenBalance storage balance = balances[from];
        
        // Update token-specific balances
        if (token == address(0)) {
            balance.nativeBalance += amount;
        } else {
            balance.usdcBalance += amount;
        }
        
        balance.totalUSDValue += usdValue;

        // Register user if new
        if (balance.totalUSDValue == usdValue) { // First deposit for this user
            userAddresses.push(from);
        }

        // Update counters
        depositCount[from]++;
        totalDepositOps++;

        emit Deposit(from, token, amount, usdValue);

        // Check and mint NFT if eligible
        _checkAndMintNFT(from);
    }

    // ============ WITHDRAWAL FUNCTIONS ============
    /**
     * @notice Request withdrawal of ETH
     * @param amount Amount of ETH to withdraw (in wei)
     */
    function requestWithdrawalETH(uint256 amount) external nonReentrant nonZeroAmount(amount) {
        TokenBalance storage balance = balances[msg.sender];
        if (amount > balance.nativeBalance) revert InsufficientBalance(amount, balance.nativeBalance);
        if (amount > maxWithdrawalAmount) revert ExceedsMaxWithdrawal(amount, maxWithdrawalAmount);

        balance.nativeBalance -= amount;
        balance.pendingWithdrawalETH += amount;

        withdrawalCount[msg.sender]++;
        totalWithdrawalOps++;

        emit WithdrawalRequested(msg.sender, address(0), amount);
    }

    /**
     * @notice Request withdrawal of USDC
     * @param amount Amount of USDC to withdraw (6 decimals)
     */
    function requestWithdrawalUSDC(uint256 amount) external nonReentrant nonZeroAmount(amount) {
        TokenBalance storage balance = balances[msg.sender];
        if (amount > balance.usdcBalance) revert InsufficientBalance(amount, balance.usdcBalance);
        if (amount > maxWithdrawalAmount) revert ExceedsMaxWithdrawal(amount, maxWithdrawalAmount);

        balance.usdcBalance -= amount;
        balance.pendingWithdrawalUSDC += amount;

        withdrawalCount[msg.sender]++;
        totalWithdrawalOps++;

        emit WithdrawalRequested(msg.sender, usdcToken, amount);
    }

    /**
     * @notice Complete pending ETH withdrawal
     */
    function completeWithdrawalETH() external nonReentrant {
        TokenBalance storage balance = balances[msg.sender];
        uint256 amount = balance.pendingWithdrawalETH;
        if (amount == 0) revert ZeroAmount();

        balance.pendingWithdrawalETH = 0;

        (bool success, ) = msg.sender.call{value: amount}("");
        if (!success) revert TransferFailed();

        emit WithdrawalCompleted(msg.sender, address(0), amount);
    }

    /**
     * @notice Complete pending USDC withdrawal
     */
    function completeWithdrawalUSDC() external nonReentrant {
        TokenBalance storage balance = balances[msg.sender];
        uint256 amount = balance.pendingWithdrawalUSDC;
        if (amount == 0) revert ZeroAmount();

        balance.pendingWithdrawalUSDC = 0;

        (bool success, ) = usdcToken.call(
            abi.encodeWithSignature("transfer(address,uint256)", msg.sender, amount)
        );
        require(success, "USDC transfer failed");

        emit WithdrawalCompleted(msg.sender, usdcToken, amount);
    }

    // ============ ORACLE & PRICE FUNCTIONS ============
    /**
     * @notice Calculate USD value of ETH amount
     * @param amount Amount of ETH in wei
     * @return USD value with 8 decimals
     */
    function _calculateETHValue(uint256 amount) private view returns (uint256) {
        (, bytes memory data) = oracle.staticcall(abi.encodeWithSignature("latestAnswer()"));
        int256 ethPrice = abi.decode(data, (int256));
        
        require(ethPrice > 0, "Invalid price from oracle");
        
        return (amount * uint256(ethPrice)) / 10**ETH_DECIMALS;
    }

    /**
     * @notice Calculate USD value of USDC amount
     * @param amount Amount of USDC (6 decimals)
     * @return USD value with 8 decimals
     */
    function _calculateUSDCValue(uint256 amount) private pure returns (uint256) {
        return amount * 10**(USD_DECIMALS - USDC_DECIMALS);
    }

    /**
     * @notice Get current ETH price from oracle
     * @return Current ETH price in USD with 8 decimals
     */
    function getETHPrice() external view returns (int256) {
        (, bytes memory data) = oracle.staticcall(abi.encodeWithSignature("latestAnswer()"));
        return abi.decode(data, (int256));
    }

    // ============ NFT REWARDS LOGIC ============
    /**
     * @notice Check if user is eligible for NFT and mint it
     * @param user Address of the user to check
     */
    function _checkAndMintNFT(address user) private {
        if (kipuNFT == address(0)) return; // NFT not configured
        
        TokenBalance storage balance = balances[user];
        
        if (balance.totalUSDValue >= NFT_THRESHOLD && !hasReceivedNFT[user]) {
            hasReceivedNFT[user] = true;
            
            // Mint NFT
            (bool success, ) = kipuNFT.call(
                abi.encodeWithSignature("safeMint(address,string)", user, "https://kipubank.com/nft.json")
            );
            
            if (success) {
                emit NFTEarned(user);
            }
        }
    }

    // ============ VIEW FUNCTIONS ============
    /**
     * @notice Get user's token balances
     * @param user Address of the user
     * @return TokenBalance structure with user's balances
     */
    function getBalance(address user) external view returns (TokenBalance memory) {
        return balances[user];
    }

    /**
     * @notice Get user's total balance in USD
     * @param user Address of the user
     * @return Total balance in USD (8 decimals)
     */
    function getUserTotalBalanceUSD(address user) external view returns (uint256) {
        return balances[user].totalUSDValue;
    }

    /**
     * @notice Get bank statistics
     * @return BankStats structure with bank statistics
     */
    function getBankStats() external view returns (BankStats memory) {
        return BankStats({
            depositsOps: totalDepositOps,
            withdrawalOps: totalWithdrawalOps,
            totalBalance: address(this).balance,
            users: userAddresses.length
        });
    }

    /**
     * @notice Get total number of users
     * @return Number of unique users
     */
    function getTotalUsers() external view returns (uint256) {
        return userAddresses.length;
    }

    /**
     * @notice Calculate total balance of the bank in USD
     * @return Total balance in USD (8 decimals)
     */
    function _getTotalBalanceUSD() private view returns (uint256) {
        uint256 total;
        for (uint i = 0; i < userAddresses.length; i++) {
            total += balances[userAddresses[i]].totalUSDValue;
        }
        return total;
    }

    // ============ OWNER FUNCTIONS ============
    /**
     * @notice Update oracle address
     * @param newOracle Address of the new oracle contract
     */
    function setOracle(address newOracle) external onlyOwner {
        oracle = newOracle;
        emit OracleUpdated(newOracle);
    }

    /**
     * @notice Set KipuNFT contract address
     * @param nftAddress Address of the KipuNFT contract
     */
    function setKipuNFT(address nftAddress) external onlyOwner {
        kipuNFT = nftAddress;
    }

    /**
     * @notice Emergency withdraw ETH (owner only)
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function emergencyWithdrawETH(address to, uint256 amount) external onlyOwner nonReentrant {
        (bool success, ) = to.call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /**
     * @notice Emergency withdraw USDC (owner only)
     * @param to Recipient address
     * @param amount Amount to withdraw
     */
    function emergencyWithdrawUSDC(address to, uint256 amount) external onlyOwner nonReentrant {
        (bool success, ) = usdcToken.call(
            abi.encodeWithSignature("transfer(address,uint256)", to, amount)
        );
        require(success, "USDC transfer failed");
    }

    // ============ FALLBACK ============
    /**
     * @notice Receive function to accept ETH deposits
     */
    receive() external payable {
        _handleDepositETH(msg.sender, msg.value);
    }
}