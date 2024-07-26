#!/bin/sh

# Function to handle errors
handle_error() {
    echo "Error occurred in script execution. Exiting."
    exit 1
}

# Trap any error
trap 'handle_error' ERR

# Update and upgrade the system
echo "Updating and upgrading the system..."
sudo apt-get update && sudo apt-get upgrade -y
clear

# Install necessary packages and dependencies
echo "Installing necessary packages and dependencies..."
npm install --save-dev hardhat
npm install dotenv
npm install @swisstronik/utils
npm install @openzeppelin/contracts
npm install @openzeppelin/contracts-upgradeable
npm install --save-dev @openzeppelin/hardhat-upgrades
npm install @nomicfoundation/hardhat-toolbox
npm install @swisstronik/sdk
npm install typescript ts-node @types/node
echo "Installation of dependencies completed."

# Create a new Hardhat project
echo "Creating a new Hardhat project..."
npx hardhat init

# Remove the default Lock.sol contract
echo "Removing default Lock.sol contract..."
rm -f contracts/Lock.sol

# Create .env file
echo "Creating .env file..."
read -p "Enter your private key: " PRIVATE_KEY
echo "PRIVATE_KEY=$PRIVATE_KEY" > .env
echo ".env file created."

# Configure Hardhat
echo "Configuring Hardhat..."
cat << 'EOL' > hardhat.config.ts
import { HardhatUserConfig } from 'hardhat/config';
import '@nomicfoundation/hardhat-toolbox';
import dotenv from 'dotenv';
import '@openzeppelin/hardhat-upgrades';

dotenv.config();

const config: HardhatUserConfig = {
  defaultNetwork: 'swisstronik',
  solidity: '0.8.20',
  networks: {
    swisstronik: {
      url: 'https://json-rpc.testnet.swisstronik.com/',
      accounts: [`0x${process.env.PRIVATE_KEY}`],
    },
  },
};

export default config;
EOL
echo "Hardhat configuration completed."

# Collect NFT details
read -p "Enter the NFT name: " NFT_NAME
read -p "Enter the NFT symbol: " NFT_SYMBOL

# Create the private ERC-721 contract
echo "Creating PrivateNFT.sol contract..."
mkdir -p contracts
cat << EOL > contracts/PrivateNFT.sol
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PrivateNFT is ERC721, Ownable {
    uint256 private _nextTokenId;
    
    constructor() ERC721("$NFT_NAME", "$NFT_SYMBOL") {
        _nextTokenId = 1;
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return "https://api.yourproject.com/metadata/";
    }

    function mint(address to) public onlyOwner {
        uint256 currentTokenId = _nextTokenId;
        _safeMint(to, currentTokenId);
        _nextTokenId++;
    }
}
EOL
echo "PrivateNFT.sol contract created."

# Compile the contract
echo "Compiling the contract..."
npx hardhat compile
echo "Contract compiled."

# Create deploy.ts script
echo "Creating deploy.ts script..."
mkdir -p scripts utils
cat << 'EOL' > scripts/deploy.ts
import { ethers } from 'hardhat'
import fs from 'fs'
import path from 'path'

async function main() {
  const Contract = await ethers.getContractFactory('PrivateNFT')

  console.log('Deploying PrivateNFT token...')
  const contract = await Contract.deploy()

  await contract.waitForDeployment()
  const contractAddress = await contract.getAddress()
  console.log('PrivateNFT token deployed to:', contractAddress)

  const deployedAddressPath = path.join(__dirname, '..', 'utils', 'deployed-address.ts')

  const fileContent = `const deployedAddress = '${contractAddress}'\n\nexport default deployedAddress\n`

  fs.writeFileSync(deployedAddressPath, fileContent, { encoding: 'utf8' })
  console.log('Address written to deployed-address.ts')
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
})
EOL
echo "deploy.ts script created."

# Create mint.ts script using SwisstronikSDK
echo "Creating mint.ts script..."
cat << 'EOL' > scripts/mint.ts
import { ethers, network } from 'hardhat'
import { SwisstronikSDK } from '@swisstronik/sdk'
import deployedAddress from '../utils/deployed-address'

async function main() {
  const contractAddress = deployedAddress

  const [signer] = await ethers.getSigners()

  const sdk = new SwisstronikSDK({
    privateKey: process.env.PRIVATE_KEY!,
    rpcUrl: network.config.url!,
  })

  const contract = new sdk.Contract(contractAddress, [
    'function mint(address to) public',
  ])

  const recipient = signer.address
  const tx = await contract.methods.mint(recipient).send({ from: signer.address })
  await tx.wait()

  console.log('Minted PrivateNFT to:', recipient)
}

main().catch((error) => {
  console.error(error)
  process.exitCode = 1
})
EOL
echo "mint.ts script created."

# Run the deploy script
echo "Running the deploy script..."
npx hardhat run scripts/deploy.ts --network swisstronik

echo "Script execution completed."
