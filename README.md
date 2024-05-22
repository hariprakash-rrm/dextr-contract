# CS - Staking

This project is a staking smart contract. Below are the requirements and steps to set up, deploy, and verify the contract using Truffle and the Truffle Verify Plugin.

## Requirements

- Truffle
- Truffle Verify Plugin

## Installation

Ensure you have all necessary dependencies installed using npm.

## Deployment

### Step 1: Install Truffle and Truffle Verify Plugin

Make sure Truffle and the Truffle Verify Plugin are installed globally.

### Step 2: Configure Truffle

Update your `truffle-config.js` to include the necessary configurations for the network you are using (e.g., Ethereum, Binance Smart Chain). Below is an example configuration for using the Truffle Dashboard:

```javascript
module.exports = {
  networks: {
    dashboard: {
      network_id: "*", // Match any network id
    },
  },
  plugins: [
    'truffle-plugin-verify'
  ],
  api_keys: {
    etherscan: 'YOUR_ETHERSCAN_API_KEY' // Add your Etherscan API key here
  },
  compilers: {
    solc: {
      version: "0.8.0",    // Fetch exact version from solc-bin (default: truffle's version)
    }
  }
};

### Step 3: deployment

truffle migrate --network dashboard
truffle run verify <contractName> --network dashboard


