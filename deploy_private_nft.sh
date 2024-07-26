#!/bin/bash

# Prompt for user input
read -p "Enter the RPC URL (e.g., https://json-rpc.testnet.swisstronik.com/): " RPC_URL
read -p "Enter your private key: " PRIVATE_KEY
read -p "Enter the recipient address: " RECIPIENT_ADDRESS

# Install dependencies
echo "Installing dependencies..."
npm install @openzeppelin/contracts ethers swisstronik-sdk hardhat

# Initialize Hardhat project
npx hardhat init --yes

# Create the contract directory
mkdir -p contracts

# Create the ERC-721 contract
cat > contracts/PrivateNFT.sol << EOL
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PrivateNFT is ERC721, Ownable {
    mapping(address => bool) private whitelist;

    constructor() ERC721("PrivateNFT", "PNFT") {}

    modifier onlyWhitelisted() {
        require(whitelist[msg.sender], "Not whitelisted");
        _;
    }

    function addToWhitelist(address _address) external onlyOwner {
        whitelist[_address] = true;
    }

    function removeFromWhitelist(address _address) external onlyOwner {
        whitelist[_address] = false;
    }

    function mint(address to, uint256 tokenId) public onlyOwner onlyWhitelisted {
        _mint(to, tokenId);
    }

    function transferFrom(address from, address to, uint256 tokenId) public override onlyWhitelisted {
        super.transferFrom(from, to, tokenId);
    }
}
EOL

echo "Solidity contract created at contracts/PrivateNFT.sol"

# Create the Hardhat config file
cat > hardhat.config.js << EOL
require("@nomiclabs/hardhat-waffle");

module.exports = {
  solidity: "0.8.0",
  networks: {
    testnet: {
      url: "$RPC_URL",
      accounts: ["$PRIVATE_KEY"]
    }
  }
};
EOL

echo "Hardhat config file created at hardhat.config.js"

# Create the deployment script
cat > deploy.js << EOL
const { ethers } = require("hardhat");
const fs = require("fs");

async function main() {
    const [deployer] = await ethers.getSigners();
    console.log("Deploying contracts with the account:", deployer.address);

    // Compile the contract
    await hre.run('compile');

    // Deploy contract
    const PrivateNFT = await ethers.getContractFactory("PrivateNFT");
    const contract = await PrivateNFT.deploy();
    await contract.deployed();
    console.log("Contract deployed at:", contract.address);

    // Whitelist and mint
    const recipientAddress = "$RECIPIENT_ADDRESS";
    let tx = await contract.addToWhitelist(recipientAddress);
    await tx.wait();
    console.log("Address whitelisted:", recipientAddress);

    const tokenId = 1;
    tx = await contract.mint(recipientAddress, tokenId);
    await tx.wait();
    console.log("NFT minted with token ID:", tokenId);
}

main().catch((error) => {
    console.error("Error deploying contract:", error);
    process.exit(1);
});
EOL

echo "Deployment script created at deploy.js"

# Compile the contract using Hardhat
npx hardhat compile

echo "Setup complete. Run 'npx hardhat run deploy.js --network testnet' to deploy your contract."
