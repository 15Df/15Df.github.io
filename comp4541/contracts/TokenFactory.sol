pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract TokenFactory is Ownable {
    enum State { Pending, Active, Completed }

    struct TokenRequest {
        address issuer;       // Address of the user that requests the token
        uint256 ethRequired;  // Total ETH required to create the token
        uint256 price;        // Price per token in Wei
        uint256 totalSupply;  // Total supply of tokens requested
        State state;          // Current state of the request
        uint256 ethPooled;    // Total ETH pooled so far
        CustomToken token;    // Reference to the created token
    }

    mapping(uint256 => TokenRequest) public tokenRequests;
    mapping(uint256 => mapping(address => uint256)) public contributions; // Track user contributions
    mapping(uint256 => mapping(address => uint256)) public userTokenRequests; // Track users' token requests
    mapping(uint256 => address[]) public contributors; // Track contributors' addresses
    uint256 public requestCounter;

    // DEX functionality
    mapping(address => mapping(address => uint256)) public liquidity; // store liquidity: token => token => liquidityAmount
    mapping(address => uint256) public tokenPrices; // store token prices: token => priceInWei

    event TokenCreated(address indexed tokenAddress, address indexed issuer, uint256 totalSupply, uint256 price);
    event EthPooled(uint256 indexed requestId, address indexed user, uint256 amount);
    event Swapped(address indexed user, address tokenIn, uint256 amountIn, address tokenOut, uint256 amountOut);
    event LiquidityAdded(address indexed provider, address tokenA, uint256 amountA, address tokenB, uint256 amountB);
    event LiquidityRemoved(address indexed provider, address tokenA, uint256 amountA, address tokenB, uint256 amountB);

    constructor() Ownable(msg.sender) {}

    // Users first create a token request specifying price and total supply
    function createTokenRequest(uint256 price, uint256 totalSupply) external payable {
        require(msg.value > 0, "Must send ETH to create a token request");
        require(totalSupply > 0, "Token total supply must be greater than 0");
        require(price > 0, "Token price must be greater than 0");

        requestCounter++;
        uint256 ethRequired = price * totalSupply;

        // Require the issuer to pool at least 80% of the required ETH
        uint256 requiredEthToPool = (ethRequired * 70) / 100;
        require(msg.value >= requiredEthToPool, "Must send at least 70% of the required ETH");

        tokenRequests[requestCounter] = TokenRequest({
            issuer: msg.sender,
            ethRequired: ethRequired,
            price: price,
            totalSupply: totalSupply,
            state: State.Pending,
            ethPooled: msg.value, // Initial contribution
            token: CustomToken(address(0)) // Initialize with address(0)
        });

        // Track contributions
        contributions[requestCounter][msg.sender] = msg.value;
        contributors[requestCounter].push(msg.sender);
    }

    // Users express interest in purchasing tokens
    function poolEth(uint256 requestId, uint256 tokensToPurchase) external payable {
        TokenRequest storage req = tokenRequests[requestId];
        require(req.state == State.Pending, "Token request not active");
        require(tokensToPurchase > 0, "Must specify at least one token to purchase");

        // Calculate required ETH for tokens
        uint256 requiredEth = req.price * tokensToPurchase;

        // Pool the required Ether and refund excess
        req.ethPooled += requiredEth;
        contributions[requestId][msg.sender] += requiredEth;

        uint256 excessEth = msg.value - requiredEth;
        if (excessEth > 0) {
            payable(msg.sender).transfer(excessEth);
        }

        userTokenRequests[requestId][msg.sender] += tokensToPurchase;

        emit EthPooled(requestId, msg.sender, requiredEth);

        // Finalize token creation if enough ETH pooled
        if (req.ethPooled >= req.ethRequired) {
            finalizeTokenCreation(requestId);
        }
    }

    // Finalize the token creation and distribute the tokens according to the new distribution rules
    function finalizeTokenCreation(uint256 requestId) internal {
        TokenRequest storage req = tokenRequests[requestId];
        require(req.state == State.Pending, "Token request already completed");

        uint256 totalTokens = req.totalSupply;
        uint256 totalContributions = req.ethPooled;

        // Create the new token
        req.token = new CustomToken("NewToken", "NTK", totalTokens, req.issuer, requestId);
        req.state = State.Completed; // Mark request as completed

        // Mint tokens based on the new distribution
        uint256 issuerShare = (totalTokens * 70) / 100; // 70% to issuer
        uint256 contributorShare = (totalTokens * 20) / 100; // 20% to contributors
        uint256 poolShare = (totalTokens * 10) / 100; // 10% to pool

        // Allocate 70% to the issuer
        req.token.mint(req.issuer, issuerShare);

        // Allocate 20% to contributors based on their contributions
        for (uint256 i = 0; i < contributors[requestId].length; i++) {
            address contributor = contributors[requestId][i];
            uint256 userContribution = contributions[requestId][contributor];
            uint256 tokensToAllocate = (userContribution * contributorShare) / totalContributions;

            if (tokensToAllocate > 0) {
                req.token.mint(contributor, tokensToAllocate); // Transfer allocated tokens to the contributor
            }
        }

        // Allocate 10% to the contract for liquidity or pool
        req.token.mint(address(this), poolShare);

        // Set token price for DEX
        tokenPrices[address(req.token)] = req.price;

        emit TokenCreated(address(req.token), req.issuer, totalTokens, req.price);
    }

    // DEX functions
function swap(address tokenIn, uint256 amountIn, address tokenOut) external {
    require(amountIn > 0, "Must send an amount greater than 0");
    require(liquidity[tokenIn][tokenOut] > 0, "Liquidity not available for this swap");

    // Get current reserves for both tokens
    uint256 reserveIn = liquidity[tokenIn][tokenOut];
    uint256 reserveOut = liquidity[tokenOut][tokenIn];

    // Calculate amount out for the token being swapped
    uint256 amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
    require(amountOut > 0, "Insufficient output amount");

    // Update the reserves before transferring tokens
    liquidity[tokenIn][tokenOut] += amountIn;
    liquidity[tokenOut][tokenIn] -= amountOut;

    // Transfer tokens in and out
    ERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn);
    ERC20(tokenOut).transfer(msg.sender, amountOut);

    emit Swapped(msg.sender, tokenIn, amountIn, tokenOut, amountOut);
}

function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) internal pure returns (uint256) {
    require(reserveIn > 0 && reserveOut > 0, "Invalid reserves");
    uint256 amountInWithFee = amountIn * 997; // 0.3% fee
    uint256 numerator = amountInWithFee * reserveOut;
    uint256 denominator = (reserveIn * 1000) + amountInWithFee;
    return numerator / denominator;
}
}
