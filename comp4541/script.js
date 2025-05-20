// Ensure you include this script after the Web3 library in your index.html

const DEX_ADDRESS = '0x2653561f7eF320ae105495Ce829A020a9ddd176E'; // Replace with your deployed contract address
const TokenFactoryABI = [
    // ABI of your TokenFactory contract
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "price",
                "type": "uint256"
            },
            {
                "internalType": "uint256",
                "name": "totalSupply",
                "type": "uint256"
            }
        ],
        "name": "createTokenRequest",
        "outputs": [],
        "stateMutability": "payable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "uint256",
                "name": "requestId",
                "type": "uint256"
            },
            {
                "internalType": "uint256",
                "name": "tokensToPurchase",
                "type": "uint256"
            }
        ],
        "name": "poolEth",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    },
    {
        "inputs": [
            {
                "internalType": "address",
                "name": "tokenIn",
                "type": "address"
            },
            {
                "internalType": "uint256",
                "name": "amountIn",
                "type": "uint256"
            },
            {
                "internalType": "address",
                "name": "tokenOut",
                "type": "address"
            }
        ],
        "name": "swap",
        "outputs": [],
        "stateMutability": "nonpayable",
        "type": "function"
    }
];

async function initApp() {
    const web3 = new Web3(window.ethereum);
    const accounts = await web3.eth.requestAccounts();
    const tokenFactory = new web3.eth.Contract(TokenFactoryABI, DEX_ADDRESS);

    document.getElementById("createTokenButton").onclick = async () => {
        const price = document.getElementById("tokenPrice").value;
        const totalSupply = document.getElementById("totalSupply").value;
        const priceInWei = web3.utils.toWei(price, 'ether');
        
        await tokenFactory.methods.createTokenRequest(priceInWei, totalSupply)
            .send({ from: accounts[0], value: priceInWei * 0.7 });
        
        alert("Token request created!");
    };

    document.getElementById("poolETHButton").onclick = async () => {
        const requestId = document.getElementById("requestId").value;
        const tokensToPurchase = document.getElementById("tokensToPurchase").value;
        const ethToPool = web3.utils.toWei((tokensToPurchase * price).toString(), 'ether');
        
        await tokenFactory.methods.poolEth(requestId, tokensToPurchase)
            .send({ from: accounts[0], value: ethToPool });
        
        alert("Successfully pooled ETH!");
    };

    document.getElementById("swapButton").onclick = async () => {
        const tokenIn = document.getElementById("tokenIn").value;
        const amountIn = document.getElementById("amountIn").value;
        const tokenOut = document.getElementById("tokenOut").value;
        
        await tokenFactory.methods.swap(tokenIn, web3.utils.toWei(amountIn, 'ether'), tokenOut)
            .send({ from: accounts[0] });
        
        alert("Tokens swapped!");
    };
}

// Initialize the app when the page loads
window.onload = initApp;
