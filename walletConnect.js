
//connect metamask
async function connectMetamask() {
    // Check if MetaMask is installed
    if (typeof window.ethereum !== 'undefined') {
        try {
            // Request permission to access the user's wallet
            await window.ethereum.request({ method: 'eth_requestAccounts' });

            // Get the user's current account address
            const accounts = await web3.eth.getAccounts();
            const userAddress = accounts[0];

            // Create a new instance of the StakePro contract
            const stakeProContract = new web3.eth.Contract(StakePro.abi, StakePro.address);

            // Return the user's address and the contract instance
            return { userAddress, stakeProContract };
        } catch (error) {
            console.error(error);
        }
    } else {
        // Display an error message if MetaMask is not installed
        alert('Please install MetaMask to use this feature');
    }
}

// connect trustwallet
async function connectTrustWallet() {
    if (window.ethereum) {
        try {
            // Request account access if needed
            await window.ethereum.request({ method: 'eth_requestAccounts' });

            // Set the provider to Trust Wallet
            web3 = new Web3(window.ethereum);

            // Get the user's address
            const accounts = await web3.eth.getAccounts();
            const userAddress = accounts[0];

            // Display a success message
            alert(`Connected to Trust Wallet! Your address is ${userAddress}`);
        } catch (error) {
            console.error(error);
            alert('Error connecting to Trust Wallet');
        }
    } else {
        alert('Please install Trust Wallet to use this feature.');
    }
}
