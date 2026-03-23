# Local NFT Marketplace & Interactive CLI

This repository contains a locally deployable Web3 ecosystem. It is designed to demonstrate how NFTs and blockchain marketplaces function behind the scenes, providing a safe environment for testing and interaction without the need for real funds or prior blockchain experience.

## Project Overview

The project consists of two main parts:

1. **Smart Contracts**: The core logic deployed on the blockchain.
2. **Interactive CLI**: A command-line interface that allows you to interact with the contracts easily.

### The Smart Contracts

- **Collection (`Collection.sol`)**: This contract follows the ERC-721 standard for NFTs. It allows users to mint (create) new digital items and transfer them. Metadata (like the name and description of the NFT) is simulated locally.
- **Marketplace (`Marketplace.sol`)**: This is the trading engine. It allows users to list their NFTs for sale, buy NFTs using digital currency (ETH), and cancel active listings. It includes safety mechanisms to handle edge cases, such as "Zombie Listings" (when a token is actively listed but transferred away privately).

### The Command Line Interface (CLI)

Instead of a web frontend, this project uses a text-based menu in your terminal. It acts as a control panel, allowing you to log in as different users, deploy the contracts, and execute trades step-by-step.

## Prerequisites

To run this project, you only need:

- **Node.js**: JavaScript runtime (version 18 or higher is recommended).
- **npm**: The Node package manager (this comes automatically with Node.js).

The project works across Linux, macOS, and Windows. You do not need to install Hardhat globally; the project handles all necessary tools locally.

## Installation

Install the required dependencies while in the project root folder:

```bash
npm install
```

This command downloads all the necessary background tools, including Hardhat (to run the local blockchain) and Viem (to interact with it).

## How to Run the Simulation

To interact with the ecosystem, you need to open **two separate terminal windows** at the same time.

### Step 1: Start the Local Blockchain

In your first terminal (ensure you are inside the project folder), start the local Hardhat network:

```bash
npm run chain
```

This command starts a private, temporary blockchain on your computer. It provides several test accounts loaded with fake ETH. Leave this terminal open and running in the background.

_Note: When you stop this node (by pressing Ctrl+C), the script will automatically clean up any temporary metadata files generated during your session._

### Step 2: Start the CLI Client

Open a second terminal window, navigate to the project folder, and launch the interactive menu:

```bash
npm run cli
```

## Using the CLI

Once the CLI starts, you will be prompted to select an account (by typing a number from 0 to 19). You can open additional terminal windows to log in as different users and simulate multi-user interactions.

**Recommended Testing Flow:**

1. **Deploy Contracts**: Select option `2` to deploy the Collection, then option `3` to deploy the Marketplace. You will be asked to set a custom fee percentage for the marketplace.
2. **Mint an NFT**: Select option `4` to create a new digital item. You can do this multiple times to build up your inventory.
3. **Approve the Marketplace (Optional)**: Select option `6` to grant the marketplace global permission to handle all your current and future tokens. This step is entirely optional but recommended because it saves gas in the long run. If you choose to skip it, the marketplace will automatically ask for individual token approval during the listing process.
4. **List for Sale**: Select option `9` to put your newly minted NFT up for sale. If you skipped step 3, the script will automatically process the required approval before listing the item.
5. **View the Catalog**: Use option `11` to view all active items currently listed on the marketplace, along with the marketplace's owner address and accumulated fee balance.
6. **Switch Users & Buy**: Open a new terminal window, log in as a different user, and select option `1` to connect to the existing contract addresses. Then, use option `10` to purchase an NFT from the catalog.
7. **Test Edge Cases (Zombie Listings)**: As a seller, mint a token, list it for sale, and then use option `7` (Raw Gift) to transfer it directly to another user. Check the catalog to see how the system registers the resulting "Zombie Listing". Try option `8` (Safe Gift) to see the secure alternative. Zombie listings can be deleted by any user, not only the owner of the token for a decentralized cleanup.
8. **Withdraw Fees**: Log back in as the original marketplace deployer (admin) and use option `13` to securely withdraw the accumulated trading fees to your personal wallet.

---

_Disclaimer: Portions of this README documentation and code comments were generated and refined with the assistance of an AI chatbot._
