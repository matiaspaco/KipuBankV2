# KipuBankV2

KipuBankV2 - Multi-Token Banking Protocol
📖 Description
KipuBankV2 is an advanced multi-token banking smart contract that allows users to deposit ETH and USDC while implementing secure withdrawal mechanisms, real-time price feeds via Chainlink oracles, and an NFT reward system for loyal users.

Key Features
Multi-Token Support: Deposit and withdraw ETH and USDC

Chainlink Oracle Integration: Real-time ETH/USD price feeds

NFT Reward System: Automatic NFT minting for users exceeding $1000 in deposits

Secure Withdrawals: Pull-pattern withdrawal system with reentrancy protection

Bank Cap Management: Configurable maximum bank capacity in USD

Comprehensive Analytics: Real-time bank statistics and user analytics

🚀 Deployment Instructions
Prerequisites
MetaMask wallet with Sepolia ETH

Remix IDE or Hardhat development environment

Access to Sepolia testnet

Contract Deployment Order
Deploy MockUSDC (for testing) or use real USDC address

javascript
// MockUSDC Constructor: No parameters
Deploy KipuNFT

javascript
// KipuNFT Constructor: No parameters
Deploy KipuBankV2

javascript
// KipuBankV2 Constructor Parameters:
_maxWithdrawalAmount: 1000000000000000000    // 1 ETH in wei
_bankCapUSD: 1000000000000                   // 100,000 USD (8 decimals)
_usdcToken: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238  // Sepolia USDC
_oracle: 0x694AA1769357215DE4FAC081bf1f309aDC325306     // Chainlink ETH/USD
Configure Contracts

javascript
// Call on KipuBankV2:
setKipuNFT(KIPUNFT_CONTRACT_ADDRESS)
Real Addresses for Sepolia
javascript
// Chainlink ETH/USD Price Feed
ORACLE: 0x694AA1769357215DE4FAC081bf1f309aDC325306

// USDC Token (Circle)
USDC: 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238
💻 How to Interact
For Users
Depositing Funds
ETH Deposit:

javascript
// Send ETH directly to contract or call:
depositETH()  // Send ETH with transaction

// Or simply send ETH to contract address (fallback function)
USDC Deposit:

javascript
// First, approve USDC spending
USDC.approve(KIPUBANKV2_ADDRESS, AMOUNT_IN_6_DECIMALS)

// Then deposit
depositUSDC(AMOUNT_IN_6_DECIMALS)
Withdrawing Funds
Request Withdrawal:

javascript
// For ETH
requestWithdrawalETH(AMOUNT_IN_WEI)

// For USDC  
requestWithdrawalUSDC(AMOUNT_IN_6_DECIMALS)
Complete Withdrawal:

javascript
// For ETH
completeWithdrawalETH()

// For USDC
completeWithdrawalUSDC()
For Contract Owner
Update Oracle:

javascript
setOracle(NEW_ORACLE_ADDRESS)
Configure NFT Contract:

javascript
setKipuNFT(NFT_CONTRACT_ADDRESS)
Emergency Withdrawals:

javascript
emergencyWithdrawETH(RECIPIENT, AMOUNT)
emergencyWithdrawUSDC(RECIPIENT, AMOUNT)
View Functions
Check User Balance:

javascript
getBalance(USER_ADDRESS)  // Returns TokenBalance struct
Get Bank Statistics:

javascript
getBankStats()  // Returns BankStats struct
Check ETH Price:

javascript
getETHPrice()  // Returns current ETH/USD price
Get Total Users:

javascript
getTotalUsers()  // Returns number of unique users
🎯 NFT Reward System
Users automatically receive an NFT when their total deposited value exceeds $1000 USD.

Conditions:

Total deposited value ≥ 1000 USD (including both ETH and USDC)

User hasn't received an NFT previously

NFT contract is configured

Automatic Minting: NFTs are minted automatically during deposit transactions that push the user over the threshold.

🔒 Security Features
Reentrancy Protection: All state-changing functions use reentrancy guards

Pull Pattern Withdrawals: Two-step withdrawal process for enhanced security

Input Validation: Zero amount checks and balance verification

Access Control: Owner-only functions for critical operations

Bank Cap Enforcement: Prevents deposits that exceed configured limits

📊 Contract Structure
Key Mappings
balances[user] - User token balances and USD values

depositCount[user] - Number of deposits per user

withdrawalCount[user] - Number of withdrawals per user

hasReceivedNFT[user] - NFT reward tracking

Constants
USD_DECIMALS = 8 - USD value precision

ETH_DECIMALS = 18 - ETH decimal places

USDC_DECIMALS = 6 - USDC decimal places

NFT_THRESHOLD = 1000 * 10^8 - $1000 in 8 decimals

🧪 Testing
Recommended Test Scenarios
ETH Deposits and Withdrawals

USDC Deposits and Withdrawals

Mixed Asset Deposits

NFT Reward Triggering

Bank Cap Limitations

Oracle Price Updates

Test Values
javascript
// Sample test amounts
ETH_DEPOSIT: 100000000000000000  // 0.1 ETH
USDC_DEPOSIT: 500000000          // 500 USDC