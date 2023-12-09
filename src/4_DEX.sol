// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./4_cZar.sol";
import "./5_lptoken.sol";
import "./CELO.sol";
import "./cEURO.sol";
import "./cREAL.sol";
import "./cUSD.sol";
import "./userRegistry.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol"; // Import SafeERC20

contract DEX is Ownable {
    using SafeERC20 for IERC20; // Use SafeERC20 for IERC20
    cZAR public cZARToken;
    cUSD public cUSDToken;
    cEURO public cEUROToken;
    cREAL public cRealToken;
    cELO public CeloToken;
    LPToken public lpToken;
    uint256 public cZARReserve;
    uint256 public cUSDReserve;
    uint256 public fee = 10; // 0.1% fee but flexible

    address public userRegistryAddress;

    struct Stake {
        uint256 amount;
        uint256 timestamp;
    }

    mapping(address => Stake) public stakes;
    mapping(address => uint256) public customerPurchases;
    mapping(address => uint256) public customerDiscounts;

    struct User {
        string name;
        mapping(address => uint256) balances;
    }

    mapping(address => User) public users;

    error InsufficientLiquidity(uint256 cZARAmount, uint256 cUSDAmount);
    error InsufficientLPToken(uint256 lpAmount);
    error InsufficientFunds(uint256 requested, uint256 available);

    event AddedLiquidity(
        address indexed provider,
        uint256 cZARAmount,
        uint256 cUSDAmount
    );
    event RemovedLiquidity(
        address indexed provider,
        uint256 cZARAmount,
        uint256 cUSDAmount
    );
    event Swapped(
        address indexed trader,
        uint256 cZARAmount,
        uint256 cUSDAmount
    );
    event Staked(address indexed user, uint256 amount, uint256 timestamp);

    event Unstaked(
        address indexed user,
        uint256 amount,
        uint256 reward,
        uint256 timestamp
    );
    event Withdraw(address indexed user, uint256 amount);
    event Payment(
        address indexed sender,
        address indexed recipient,
        uint256 amount,
        address indexed currency
    );

    event PurchaseMade(address customer, uint256 purchaseAmount);

    event TokensMinted(address indexed user, uint256 amount);
    // Event for when a wallet is connected
    event WalletConnected(address indexed walletAddress);

    // Event for when a balance is checked
    event BalanceChecked(
        address indexed walletAddress,
        address indexed tokenAddress,
        uint256 balance
    );

    // Event for when tokens are approved
    event TokensApproved(address indexed walletAddress, uint256 amount);

    // Event for when tokens are transferred
    event TokensTransferred(address indexed walletAddress, uint256 amount);

    constructor(
        address _cZAR,
        address _cUSD,
        address _cEURO,
        address _cReal,
        address _Celo
    ) Ownable(msg.sender) {
        cZARToken = cZAR(_cZAR);
        cUSDToken = cUSD(_cUSD);
        cEUROToken = cEURO(_cEURO);
        cRealToken = cREAL(_cReal);
        CeloToken = cELO(_Celo);
        lpToken = new LPToken(address(this));
    }

    function setcZARAddress(address _cZARAddress) external onlyOwner {
        cZARToken = cZAR(_cZARAddress);
    }

    function setlpTokenAddress(address _lpTokenAddress) external onlyOwner {
        lpToken = LPToken(_lpTokenAddress);
    }

    //register user
    function registerUser(string memory name) external {
        require(bytes(name).length > 0, "Name cannot be empty");
        User storage user = users[msg.sender];
        user.name = name;
    }

    function mintTokensForUsers() external onlyOwner {
        require(
            userRegistryAddress != address(0),
            "User registry address is the zero address"
        );

        UserRegistry userRegistry = UserRegistry(userRegistryAddress);
        for (uint256 i = 0; i < 5; i++) {
            address userAddress = userRegistry.getUserAddressByIndex(i);
            require(
                userAddress != address(0),
                "User address is the zero address"
            );

            User storage user = users[userAddress];
            for (uint256 j = 0; j < 5; j++) {
                // Mint 1000 tokens for each user
                uint256 amount = 1000;
                require(
                    cZARToken.balanceOf(address(this)) >= amount,
                    "Not enough tokens in contract"
                );

                cZARToken.mint(userAddress, amount);
                user.balances[address(cZARToken)] += amount;
                emit TokensMinted(userAddress, amount);
            }
        }
    }

    function makePurchase(
        address customer,
        uint256 /* amount */
    ) external {
        customerPurchases[customer]++;
        uint256 amount = 0; // Dummy variable

        // Emit the purchase made event
        emit PurchaseMade(customer, amount);
    }

    function rewardCustomer(address customer, uint256 amount) external {
        if (customerPurchases[customer] >= 3) {
            uint256 discount = (amount * 10) / 100; // 10% of the purchase amount
            customerDiscounts[customer] += discount;

            // Clear the discount
            customerDiscounts[customer] = 0;
        }
    }

    // This is for staking, keeping your money in the system for rewards
    function stake_cZAR(uint256 amount) external {
        uint256 balance = cZARToken.balanceOf(msg.sender);
        require(balance >= amount, "Insufficient cZAR balance");
        cZARToken.safeTransfer(address(this), amount); // Use safeTransfer
        stakes[msg.sender] = Stake(amount, block.timestamp);
        emit Staked(msg.sender, amount, block.timestamp);
    }

    //You get it out with it's accumulated profit
    function unstake_cZAR() external {
        Stake storage stake = stakes[msg.sender];
        uint256 reward = calculateStakeReward(stake);
        uint256 totalAmount = stake.amount + reward;
        uint256 balance = cZARToken.balanceOf(address(this));
        require(
            balance >= totalAmount,
            "Insufficient cZAR balance in contract"
        );
        cZARToken.transfer(msg.sender, totalAmount);
        emit Unstaked(msg.sender, stake.amount, reward, block.timestamp);
        delete stakes[msg.sender];
    }

    //This is where we calculate how much interest has been accumulated.
    function calculateStakeReward(Stake storage stake)
        internal
        view
        returns (uint256)
    {
        // For simplicity, let's say the reward is 1% per day
        uint256 duration = block.timestamp - stake.timestamp;
        uint256 durationInDays = duration / 1 days;
        return (stake.amount * durationInDays) / 100;
    }

    //For users that want to make some interest by adding their money into the pool.
    function addLiquidity(uint256 cZARAmount, uint256 cUSDAmount) external {
        uint256 cZARBalance = cZARToken.balanceOf(msg.sender);
        uint256 cUSDBalance = cUSDToken.balanceOf(msg.sender); // Use cUSDToken instead of cUSD
        require(cZARBalance >= cZARAmount, "Insufficient cZAR balance");
        require(cUSDBalance >= cUSDAmount, "Insufficient cUSD balance");
        cZARToken.safeTransfer(address(this), cZARAmount);
        cUSDToken.safeTransfer(address(this), cUSDAmount); // Use cUSDToken instead of cUSD
        cZARReserve += cZARAmount;
        cUSDReserve += cUSDAmount;
        lpToken.mint(msg.sender, cZARAmount); // Mint LP Tokens
        emit AddedLiquidity(msg.sender, cZARAmount, cUSDAmount);
    }

    //When they want pull their money out with some profit.
    function removeLiquidity(uint256 lpAmount) external payable {
        uint256 cZARAmount = lpAmount;
        uint256 cUSDAmount = (lpAmount * cUSDReserve) / cZARReserve;

        if (cZARReserve < cZARAmount || cUSDReserve < cUSDAmount) {
            revert InsufficientLiquidity(cZARAmount, cUSDAmount);
        }
        if (lpToken.balanceOf(msg.sender) < lpAmount) {
            revert InsufficientLPToken(lpAmount);
        }
        cZARToken.transfer(msg.sender, cZARAmount);
        cUSDToken.transfer(msg.sender, cUSDAmount); // Use cUSDToken instead of cUSD

        cZARReserve -= cZARAmount;
        cUSDReserve -= cUSDAmount;

        lpToken.burn(msg.sender, lpAmount); // Burn LP tokens

        emit RemovedLiquidity(msg.sender, cZARAmount, cUSDAmount);
    }

    //SWAPS START HERE
    //This is the SWAP where users SWAP one currency for another at a FEE
    // cUSD to cZAR
    function swapUSDForZAR(uint256 cUSDAmount_, uint256 minZARAmount_)
        external
        payable
    {
        uint256 balance = cUSDToken.balanceOf(msg.sender); // Use cUSDToken instead of cUSD
        require(balance >= cUSDAmount_, "Insufficient cUSD balance");
        uint256 cZARAmount = calculateReturn(cUSDAmount_);
        uint256 feeAmount = (cZARAmount * fee) / 10000; // calculate fee

        require(
            cUSDReserve >= cUSDAmount_ && cZARReserve >= cZARAmount + feeAmount,
            "Not enough liquidity"
        );
        require(cZARAmount >= minZARAmount_, "Price impact too high");

        cUSDToken.transferFrom(msg.sender, address(this), cUSDAmount_); // Use cUSDToken instead of cUSD
        cZARToken.transfer(msg.sender, cZARAmount);

        cUSDReserve += cUSDAmount_;
        cZARReserve -= (cZARAmount + feeAmount); // deduct fee from reserves

        emit Swapped(msg.sender, cUSDAmount_, cZARAmount);
    }

    // cZAR to cREAL
    function swapZARForREAL(uint256 cZARAmount, uint256 minREALAmount)
        external
        payable
    {
        uint256 balance = cZARToken.balanceOf(msg.sender);
        require(balance >= cZARAmount, "Insufficient cZAR balance");
        uint256 cREALAmount = calculateReturn(cZARAmount);
        uint256 feeAmount = (cREALAmount * fee) / 10000; // calculate fee

        require(
            cZARReserve >= cZARAmount &&
                cRealToken.balanceOf(address(this)) >= cREALAmount + feeAmount,
            "Not enough liquidity"
        );
        require(cREALAmount >= minREALAmount, "Price impact too high");

        cZARToken.transferFrom(msg.sender, address(this), cZARAmount);
        cRealToken.transfer(msg.sender, cREALAmount);

        cUSDReserve += cZARAmount;
        cZARReserve -= (cREALAmount + feeAmount); // deduct fee from reserves

        emit Swapped(msg.sender, cZARAmount, cREALAmount);
    }

    // cZAR to Celo
    function swapZARForCelo(uint256 cZARAmount, uint256 minCeloAmount)
        external
        payable
    {
        uint256 balance = cZARToken.balanceOf(msg.sender);
        require(balance >= cZARAmount, "Insufficient cZAR balance");
        uint256 celoAmount = calculateReturn(cZARAmount);
        uint256 feeAmount = (celoAmount * fee) / 10000; // calculate fee

        require(
            cZARReserve >= cZARAmount &&
                cEUROToken.balanceOf(address(this)) >= celoAmount + feeAmount,
            "Not enough liquidity"
        );
        require(celoAmount >= minCeloAmount, "Price impact too high");

        cZARToken.transferFrom(msg.sender, address(this), cZARAmount);
        cEUROToken.transfer(msg.sender, celoAmount);

        cZARReserve += cZARAmount;
        cZARReserve -= (celoAmount + feeAmount); // deduct fee from reserves

        emit Swapped(msg.sender, cZARAmount, celoAmount);
    }

    // VICA VERSA
    // cREAL to cZAR
    function swapREALForZAR(uint256 cREALAmount, uint256 minZARAmount)
        external
        payable
    {
        uint256 balance = cRealToken.balanceOf(msg.sender);
        require(balance >= cREALAmount, "Insufficient cREAL balance");
        uint256 cZARAmount = calculateReturn(cREALAmount);
        uint256 feeAmount = (cZARAmount * fee) / 10000; // calculate fee

        require(
            cRealToken.balanceOf(address(this)) >= cREALAmount &&
                cZARReserve >= cZARAmount + feeAmount,
            "Not enough liquidity"
        );
        require(cZARAmount >= minZARAmount, "Price impact too high");

        cRealToken.transferFrom(msg.sender, address(this), cREALAmount);
        cZARToken.transfer(msg.sender, cZARAmount);

        cZARReserve += cREALAmount;
        cZARReserve -= (cZARAmount + feeAmount); // deduct fee from reserves

        emit Swapped(msg.sender, cREALAmount, cZARAmount);
    }

    // Celo to cZAR
    function swapCeloForZAR(uint256 celoAmount, uint256 minZARAmount)
        external
        payable
    {
        uint256 balance = cEUROToken.balanceOf(msg.sender);
        require(balance >= celoAmount, "Insufficient Celo balance");
        uint256 cZARAmount = calculateReturn(celoAmount);
        uint256 feeAmount = (cZARAmount * fee) / 10000; // calculate fee

        require(
            cEUROToken.balanceOf(address(this)) >= celoAmount &&
                cZARReserve >= cZARAmount + feeAmount,
            "Not enough liquidity"
        );
        require(cZARAmount >= minZARAmount, "Price impact too high");

        cEUROToken.transferFrom(msg.sender, address(this), celoAmount);
        cZARToken.transfer(msg.sender, cZARAmount);

        cZARReserve += cZARAmount;
        cZARReserve -= (cZARAmount + feeAmount); // deduct fee from reserves

        emit Swapped(msg.sender, celoAmount, cZARAmount);
    }

    // cUSD to cZAR
    function swapUSDForZARv2(uint256 cUSDAmount, uint256 minZARAmount)
        external
        payable
    {
        uint256 balance = cUSDToken.balanceOf(msg.sender); // Use cUSDToken instead of cUSD
        require(balance >= cUSDAmount, "Insufficient cUSD balance");
        uint256 cZARAmount = calculateReturn(cUSDAmount);
        uint256 feeAmount = (cZARAmount * fee) / 10000; // calculate fee

        require(
            cUSDReserve >= cUSDAmount && cZARReserve >= cZARAmount + feeAmount,
            "Not enough liquidity"
        );
        require(cZARAmount >= minZARAmount, "Price impact too high");

        cUSDToken.transferFrom(msg.sender, address(this), cUSDAmount); // Use cUSDToken instead of cUSD
        cZARToken.transfer(msg.sender, cZARAmount);

        cUSDReserve += cUSDAmount;
        cZARReserve -= (cZARAmount + feeAmount); // deduct fee from reserves

        emit Swapped(msg.sender, cUSDAmount, cZARAmount);
    }

    // cEURO to cZAR
    function swapEUROForZAR(uint256 cEUROAmount, uint256 minZARAmount)
        external
        payable
    {
        uint256 balance = cEUROToken.balanceOf(msg.sender);
        require(balance >= cEUROAmount, "Insufficient cEURO balance");
        uint256 cZARAmount = calculateReturn(cEUROAmount);
        uint256 feeAmount = (cZARAmount * fee) / 10000; // calculate fee

        require(
            cEUROToken.balanceOf(address(this)) >= cEUROAmount &&
                cZARReserve >= cZARAmount + feeAmount,
            "Not enough liquidity"
        );
        require(cZARAmount >= minZARAmount, "Price impact too high");

        cEUROToken.transferFrom(msg.sender, address(this), cEUROAmount);
        cZARToken.transfer(msg.sender, cZARAmount);

        cZARReserve += cZARAmount;
        cZARReserve -= (cZARAmount + feeAmount); // deduct fee from reserves

        emit Swapped(msg.sender, cEUROAmount, cZARAmount);
    }

    //END OF SWAPS

    //This is the function that calculates the rewards for keeping your money in the liquidity pool
    function calculateReturn(uint256 cZARAmount) public view returns (uint256) {
        uint256 cUSDAmount = (cZARAmount * cUSDReserve) / cZARReserve;
        return cUSDAmount;
    }

    //This is whhere we update the fee based on the market conditions
    function updateFee(uint256 newFee) external {
        require(
            msg.sender == owner(),
            "Only the contract owner can update the fee"
        );
        fee = newFee;
    }

    function depositAndMint(address user, uint256 zarAmount)
        external
        onlyOwner
    {
        // Convert ZAR amount to cZAR amount
        // 1 ZAR = 1 cZAR
        uint256 cZARAmount = zarAmount;

        // Mint cZAR tokens
        cZAR(address(cZARToken)).mint(user, cZARAmount);

        // Update reserves
        cZARReserve += cZARAmount;
    }

    //This is the withdrawal function for the user.
    function withdrawAndBurn(uint256 amount) external {
        require(
            cZARToken.balanceOf(msg.sender) >= amount,
            "Insufficient cZAR balance"
        );
        cZARToken.burnFrom(msg.sender, amount); // Burn the cZAR tokens

        // Emit the Withdrawal event
        emit Withdraw(msg.sender, amount);
    }

    function withdraw(uint256 amount) external payable {
        require(
            cZARToken.balanceOf(msg.sender) >= amount,
            "Insufficient cZAR balance"
        );
        cZARToken.burnFrom(msg.sender, amount); // Burn the cZAR tokens

        // Emit the Withdraw event
        emit Withdraw(msg.sender, amount);
    }

    //if the user wants to send tokens to another user or wallet.

    function send(
        address user,
        address recipient,
        uint256 amount,
        address currency
    ) external {
        require(
            IERC20(currency).balanceOf(user) >= amount,
            "Insufficient user balance"
        );
        IERC20(currency).transferFrom(user, recipient, amount);
        emit Payment(user, recipient, amount, currency);
    }

    //EMIT HERE

    //WE DO NOT WANT ETHER
    receive() external payable {
        require(msg.sender != address(cZARToken), "Cannot receive cZAR");
        revert("This contract does not accept Ether");
    }

    fallback() external payable {
        require(msg.sender != address(cZARToken), "Cannot receive cZAR");
        revert("This contract does not accept Ether");
    }

    // Connect to a wallet
    function connectWallet(address walletAddress) external {
        require(walletAddress != address(0), "Invalid wallet address");
        // Add logic to verify that the wallet belongs to the user
        emit WalletConnected(walletAddress);
    }

    // Check the balance of a token in a wallet
    function checkBalance(address walletAddress, address tokenAddress)
        external
        returns (uint256)
    {
        require(walletAddress != address(0), "Invalid wallet address");
        require(tokenAddress != address(0), "Invalid token address");
        uint256 balance = IERC20(tokenAddress).balanceOf(walletAddress);
        emit BalanceChecked(walletAddress, tokenAddress, balance);
        return balance;
    }

    // Approve a wallet to transfer tokens on behalf of the DEX contract
    function approveTokens(address walletAddress, uint256 amount) external {
        require(walletAddress != address(0), "Invalid wallet address");
        require(amount > 0, "Invalid amount");
        // Add logic to approve the tokens
        emit TokensApproved(walletAddress, amount);
    }

    // Transfer tokens to a wallet
    function transferTokens(address walletAddress, uint256 amount) external {
        require(walletAddress != address(0), "Invalid wallet address");
        require(amount > 0, "Invalid amount");
        // Add logic to transfer the tokens
        emit TokensTransferred(walletAddress, amount);
    }
}
