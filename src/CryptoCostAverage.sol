// SPDX-License-Identifier: MIT

pragma solidity ^0.8.26;

import {AutomationCompatibleInterface} from
    "../lib/chainlink-brownie-contracts/contracts/src/v0.8/automation/interfaces/AutomationCompatibleInterface.sol";
import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ISwapRouter} from "../lib/v3-periphery/contracts/interfaces/ISwapRouter.sol";
import {ReentrancyGuard} from "../lib/openzeppelin-contracts/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// THIS CONTRACT HAS NOT BEEN AUDITED BY PROFESSIONALS
// USE AT YOUR OWN RISK

/**
 * @title Investment contract for ERC20 tokens
 * @author Fin Nöthen
 * @notice This contract automatically swaps ETH for ERC20 tokens in 30 day intervals
 * @notice The concept is based on the dollar cost averaging strategy
 * @dev This implements the Chainlink Automation checkUpkeep and performUpkeep
 *  for calling the swap mechanism (Uniswap V3's SwapRouter)
 */
contract CryptoCostAverage is AutomationCompatibleInterface, Ownable, ReentrancyGuard {
    ////////////////////
    // State Variables//
    ////////////////////

    address[] public s_users;
    address[] public s_activeUsers;
    address[] public s_supportedTokens;
    mapping(address => uint256) public s_userBalances;
    mapping(address => uint256) public s_userFundsLockedInSwaps;
    mapping(address => mapping(address => uint256)) public s_userSwapAmountsForTokens;
    mapping(address => address[]) public s_userTokens;
    mapping(address => bool) public s_isUser;
    mapping(address => bool) private s_isActiveUser;
    uint256 public s_lastTimeStamp;
    uint256 public s_totalSwaps;
    uint256 public s_deadline;
    uint256 public constant INTERVAL = 30 days;

    //////////////////////
    // Uniswap Variables//
    //////////////////////

    ISwapRouter public immutable i_swapRouter;
    address public immutable i_weth;
    uint24 public s_poolFee = 3000; // 0.3% Uniswap pool fee

    ///////////
    // Events//
    ///////////

    event UserAdded(address indexed user);
    event UserRemoved(address indexed user);
    event TokenAdded(address indexed token);
    event EthDeposited(address indexed user, uint256 indexed amount);
    event UpkeepPerformed(uint256 activeUsersCount, uint256 timestamp);
    event UserTokenToAmountSet(address indexed user, address indexed token, uint256 indexed amount);
    event UserTokenToAmountRemoved(address indexed user, address indexed token);
    event SwapPerformed(address indexed user, address indexed token, uint256 indexed totalSwaps);
    event SwapFailed(address indexed user, address indexed token, uint256 indexed amount);
    event SwapsSkippedDueToNoSwapsSet(address indexed user);
    event TokenSwapSkippedDueToInsufficientFunds(address indexed user, address indexed token);

    //////////////
    // Functions//
    //////////////
    constructor(address swapRouterAddress, address wethAddress, address[] memory supportedTokens, address owner)
        Ownable(owner)
    {
        // Check if given addresses are valid
        require(swapRouterAddress != address(0), "Invalid swap router address");
        require(wethAddress != address(0), "Invalid WETH address");

        // Set variables
        i_swapRouter = ISwapRouter(swapRouterAddress);
        i_weth = wethAddress;
        s_supportedTokens = supportedTokens;
        s_lastTimeStamp = block.timestamp;
        s_deadline = 300; // 5 minutes
        s_totalSwaps = 0;
    }

    ///////////////////////////////////
    // Receive and Fallback Functions//
    ///////////////////////////////////

    receive() external payable {}

    fallback() external payable {
        revert("Function not found");
    }

    /////////////////////
    // Public Functions//
    /////////////////////

    /*
    * Deposit ether
    */
    function depositEther() public payable {
        if (!s_isUser[msg.sender]) {
            s_users.push(msg.sender);
            s_isUser[msg.sender] = true;
            emit UserAdded(msg.sender);
        }
        s_userBalances[msg.sender] += msg.value;
        emit EthDeposited(msg.sender, msg.value);
    }

    /*
    * Withdraw ether
    * @param _amount, The amount of eth to be withdrawn
    */
    function withdrawEther(uint256 _amount) public nonReentrant {
        require(s_userBalances[msg.sender] >= _amount, "Not enough balance");
        s_userBalances[msg.sender] -= _amount;
        (bool success,) = payable(msg.sender).call{value: _amount}("");
        require(success, "Withdraw failed");
    }

    /*
    * Set a supported ERC20 token with the desired amount to swap in the 30 day interval
    * @param _token, The ERC20 token to swap
    * @param _amount, The swap amount in eth for that token
    */
    function setTokenForSwap(address _token, uint256 _amount) public {
        require(_amount > 0, "The swap amount must be greater than 0");
        require(isTokenSupported(_token), "Token not supported");

        // Check if the user has already set the swap amount for the token
        if (s_userSwapAmountsForTokens[msg.sender][_token] > 0) {
            revert("Swap amount already set for token");
        }
        // Check if the user has enough ETH to set the swap amount
        uint256 availbleFunds = s_userBalances[msg.sender] - s_userFundsLockedInSwaps[msg.sender];
        if (availbleFunds < _amount) {
            revert("Not enough ETH to set swap amount");
        }

        // Add user to active user array if not already added
        if (!s_isActiveUser[msg.sender]) {
            s_activeUsers.push(msg.sender);
            s_isActiveUser[msg.sender] = true;
        }

        // Update Variables
        s_userTokens[msg.sender].push(_token);
        s_userSwapAmountsForTokens[msg.sender][_token] = _amount;
        s_userFundsLockedInSwaps[msg.sender] += _amount;
        emit UserTokenToAmountSet(msg.sender, _token, _amount);
    }

    /*
    * Remove a ERC20 token for swap 
    * @param _token, The token to remove
    */
    function removeTokenForUserSwap(address _token) public {
        require(s_userSwapAmountsForTokens[msg.sender][_token] > 0, "No swap amount set for token");
        removeUserToken(msg.sender, _token);

        s_userFundsLockedInSwaps[msg.sender] -= s_userSwapAmountsForTokens[msg.sender][_token];
        s_userSwapAmountsForTokens[msg.sender][_token] = 0;

        // Call removeActiveUser function if user has no funds locked in swaps left
        if (s_userFundsLockedInSwaps[msg.sender] == 0) {
            removeActiveUser(msg.sender);
        }
        emit UserTokenToAmountRemoved(msg.sender, _token);
    }

    ///////////////////////////////
    // Public OnlyOwner Functions//
    ///////////////////////////////

    /*
    * The owner of the contract can add new ERC20 tokens to supported tokens array
    * @param _token, The token to add to supported Tokens
    */
    function addToken(address _token) public onlyOwner {
        // Add token to supported tokens array
        require(_token != address(0), "0 address not allowed");
        require(IERC20(_token).totalSupply() > 0, "Not a valid ERC20 Token"); // Check if token is a valid ERC20 token
        s_supportedTokens.push(_token);
        emit TokenAdded(_token);
    }

    /*
    * The owner of the contract can remove ERC20 tokens from supported tokens array
    * @param _token, The token to remove from supported Tokens
    */
    function removeToken(address _token) public onlyOwner {
        for (uint256 i = 0; i < s_supportedTokens.length; i++) {
            if (s_supportedTokens[i] == _token) {
                s_supportedTokens[i] = s_supportedTokens[s_supportedTokens.length - 1];
                s_supportedTokens.pop();
                break;
            }
        }
    }

    /*
    * The owner of contract can change the Uniswap pool fee
    */
    function changePoolFee(uint24 _poolFee) public onlyOwner {
        s_poolFee = _poolFee;
    }

    /*
    * The owner of the contract can change the deadline for the Uniswap call
    */
    function changeDeadline(uint256 _deadline) public onlyOwner {
        s_deadline = _deadline;
    }

    ///////////////////////////////////
    // Chainlink Automation Functions//
    ///////////////////////////////////

    /*
    * This function returns true if timePassed and hasActiveUsers are true
    * @param checkData, not needed
    * @dev This is a Chainlink Automation function
    */
    function checkUpkeep(bytes memory /*checkData*/ )
        public
        view
        override
        returns (bool upkeepNeeded, bytes memory /*performData*/ )
    {
        bool timePassed = ((block.timestamp - s_lastTimeStamp) > INTERVAL);
        bool hasActiveUsers = s_activeUsers.length > 0;
        upkeepNeeded = timePassed && hasActiveUsers;
        return (upkeepNeeded, "");
    }

    /*
    * This function calls the swap function for all active users and their tokens
    * @param performData, not needed
    * @dev This function is a Chainlink Automation function which can only be called if
    * checkUpkeep returns true
    */
    function performUpkeep(bytes calldata /*performData*/ ) external override nonReentrant {
        // Perform the swap for each user
        // -> Only executable if checkUpkeep returns true (every 30 days)
        (bool upkeepNeeded,) = checkUpkeep("");
        if (!upkeepNeeded) {
            revert("No upkeep needed");
        }

        s_lastTimeStamp = block.timestamp; // Reset the 30 day interval

        uint256 activeUsersLength = s_activeUsers.length;
        for (uint256 i = 0; i < activeUsersLength; i++) {
            // Loop through all active users
            address user = s_activeUsers[i];
            // Remove user from active users if swap funds exceed balance
            if (s_userBalances[user] < s_userFundsLockedInSwaps[user]) {
                removeActiveUser(user);
                continue;
            }
            if (s_userFundsLockedInSwaps[user] == 0) {
                emit SwapsSkippedDueToNoSwapsSet(user);
                continue;
            }
            address[] memory tokens = s_userTokens[user];
            // Loop through all tokens for the user
            for (uint256 j = 0; j < tokens.length; j++) {
                address token = tokens[j];
                uint256 userSwapAmount = s_userSwapAmountsForTokens[user][token];
                // Check if the user has enough ETH left to swap
                if (s_userBalances[user] < userSwapAmount) {
                    emit TokenSwapSkippedDueToInsufficientFunds(user, token);
                    continue;
                }
                s_userBalances[user] -= userSwapAmount;
                swapToken(user, tokens[j]); // Call the swap function
            }
        }
        emit UpkeepPerformed(s_activeUsers.length, block.timestamp);
    }

    ///////////////////////
    // Internal Functions//
    ///////////////////////

    /*
    * This function swaps eth for a ERC20 and sends them to the users wallet
    * @param _user, The user for whom the swap is expected
    * @param _token, The token to swap 
    * @dev The function uses Uniswaps V3 SwapRouter for the swap
    */
    function swapToken(address _user, address _token) internal returns (bool) {
        // Swap ETH for token using Uniswap V3 SwapRouter
        uint256 userSwapAmount = s_userSwapAmountsForTokens[_user][_token];
        uint256 deadlineTimeStamp = block.timestamp + s_deadline;

        // Set parameters for the swap
        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter.ExactInputSingleParams({
            tokenIn: i_weth, // wETH as the token to swap from
            tokenOut: _token, // Passed token to swap to
            fee: s_poolFee, // Uniswap pool fee
            recipient: _user, // The user as the reception address
            deadline: deadlineTimeStamp, // The deadline before the call reverts if it did not pass
            amountIn: userSwapAmount, // The amount of eth that should be swapped
            amountOutMinimum: 1, // At least 1 LINK has to be received to ensure the swap is successful
            sqrtPriceLimitX96: 0 // No price limit
        });

        // Try to make the swap call to Uniswap
        try i_swapRouter.exactInputSingle{value: userSwapAmount}(params) {
            emit SwapPerformed(_user, _token, s_totalSwaps++);
            // Remove user from active user array if he has no swaps left
            if (s_userBalances[_user] < s_userFundsLockedInSwaps[_user]) {
                removeActiveUser(_user);
            }
            return true;
        } catch {
            emit SwapFailed(_user, _token, userSwapAmount);
            return false;
        }
    }

    /*
    * This function checks if a token is in the supported tokens array
    * @param _token, The token to check
    */
    function isTokenSupported(address _token) internal view returns (bool) {
        for (uint256 i = 0; i < s_supportedTokens.length; i++) {
            if (s_supportedTokens[i] == _token) {
                return true;
            }
        }
        return false;
    }

    /*
    * This function removes a user from active users array
    * @param _user, The user to remove
    */
    function removeActiveUser(address _user) internal {
        // Remove user from active user array
        for (uint256 i = 0; i < s_activeUsers.length; i++) {
            if (s_activeUsers[i] == _user) {
                s_activeUsers[i] = s_activeUsers[s_activeUsers.length - 1];
                s_activeUsers.pop();
                break;
            }
        }
        s_isActiveUser[_user] = false;
        emit UserRemoved(_user);
    }

    /*
    * This function removes a token from the user tokens array for a user
    * @param _user, The user for whom the function was called
    * @param _token, The token to remove for the user
    */
    function removeUserToken(address _user, address _token) internal {
        for (uint256 i = 0; i < s_userTokens[_user].length; i++) {
            if (s_userTokens[_user][i] == _token) {
                s_userTokens[_user][i] = s_userTokens[_user][s_userTokens[_user].length - 1];
                s_userTokens[_user].pop();
                break;
            }
        }
    }

    /////////////////////
    // Getter Functions//
    /////////////////////

    function getUsers() public view returns (address[] memory) {
        return s_users;
    }

    function getUserBalance(address _user) public view returns (uint256) {
        return s_userBalances[_user];
    }

    function getActiveSwaps(address _user) public view returns (address[] memory) {
        return s_userTokens[_user];
    }

    function getActiveUsers() public view returns (address[] memory) {
        return s_activeUsers;
    }

    function getSupportedTokens() public view returns (address[] memory) {
        return s_supportedTokens;
    }

    function getUserTokensToSwapAmount(address _user, address _token) public view returns (uint256) {
        return s_userSwapAmountsForTokens[_user][_token];
    }

    function getISwapRouter() public view returns (address) {
        return address(i_swapRouter);
    }

    function getWeth() public view returns (address) {
        return i_weth;
    }

    function getInterval() public pure returns (uint256) {
        return INTERVAL;
    }

    function getUserFundsInSwaps(address _user) public view returns (uint256) {
        return s_userFundsLockedInSwaps[_user];
    }

    function getUserTokens(address _user) public view returns (address[] memory) {
        return s_userTokens[_user];
    }

    function getPoolFee() public view returns (uint24) {
        return s_poolFee;
    }

    function getLastTimestamp() public view returns (uint256) {
        return s_lastTimeStamp;
    }

    function getUserByIndex(uint256 _index) public view returns (address) {
        return s_users[_index];
    }
}
