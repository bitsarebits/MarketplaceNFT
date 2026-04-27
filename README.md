# Web3 NFT Ecosystem & Interactive CLI

A locally deployable Web3 ecosystem built to demonstrate secure smart contract architecture, gas optimization, and event-driven off-chain indexing.

This project provides a complete environment to simulate a decentralized non-fungible token (NFT) marketplace. Instead of a traditional React frontend, interaction is driven by a custom Command Line Interface (CLI) built with TypeScript and `viem`, allowing developers to test complex trading flows, permissions, and edge cases in a permissionless environment.

## Architecture & Security Features

The core logic is divided into two main smart contracts, built with a strict focus on security vulnerabilities (e.g., Reentrancy, Denial of Service) and EVM memory management.

### 1. ERC-721 Collection (`Collection.sol`)

A modular implementation of the ERC-721 standard.

- **Gas-Optimized Storage:** Token properties (ownership, metadata URIs, approvals) are strictly separated into parallel mappings to minimize costly `SLOAD` operations.
- **Event-Driven Feedback:** Leverages standard ERC-721 events (`Transfer`, `Approval`, `ApprovalForAll`) to communicate state changes to the client without requiring additional read calls.
- **Off-Chain IPFS Simulation:** Metadata generation is handled locally by the CLI to simulate distributed file systems without relying on external providers.

### 2. The Marketplace (`Marketplace.sol`)

A permissionless trading engine capable of handling any standard ERC-721 token.

- **Reentrancy Protection:** Secures state-changing functions using the Checks-Effects-Interactions (CEI) pattern and a custom Mutex lock (`nonReentrant` modifier).
- **Pull over Push (Fees):** Protocol fees are safely isolated using the Withdrawal pattern (`withdrawFees`), preventing DoS attacks related to external calls.
- **Strict Gas Limits:** Payments to sellers are routed using the `.transfer()` method, strictly limiting forwarded gas to 2300 units to mitigate Griefing and Out-of-Gas attacks.
- **Decentralized Garbage Collection:** Mitigates "Zombie Listings" (active listings of tokens that were transferred privately). The `cancelListing` function allows _anyone_ to invalidate an order if the seller is no longer the actual owner.

---

## Getting Started

### Prerequisites

- **Node.js**: Version 18.x or higher.
- **npm**: Node package manager.

_Note: Hardhat and Viem are handled locally via project dependencies. No global installations are required._

### Installation

Clone the repository and install the dependencies:

```bash
npm install
```

## Running the Simulation

To fully experience the multi-actor environment, you will need to open **two or more terminal windows**.

### 1. Start the Local Blockchain (Terminal 1)

Boot up the local Hardhat node:

```bash
npm run chain
```

This initializes a local EVM network with 20 pre-funded test accounts. Leave this process running.

_Graceful Shutdown: Pressing `Ctrl+C` will automatically trigger a cleanup script, deleting all temporary mock IPFS metadata generated during the session._

### 2. Launch the CLI Client (Terminal 2+)

Open a new terminal window and start the interactive interface:

```bash
npm run cli
```

You can open multiple terminal windows running the CLI to simulate different actors (Admin, Minter, Seller, Buyer) interacting simultaneously.

## CLI Testing Guide

Upon launching the CLI, select a user account (0-19). Follow this recommended flow to explore the ecosystem:

1. **Deploy Contracts (Admin):** Select option `2` to deploy a Collection, then option `3` to deploy the Marketplace. You will set the protocol fee percentage (max 20%).

2. **Minting (Minter):** Use option `4` to create a new NFT. The CLI will generate mock metadata and store it locally.

3. **Smart Approval & Listing (Seller):** Use option `9` to list your NFT. The CLI performs a "smart approval" check: it reads the chain state and only sends an `approve` transaction if the marketplace lacks permissions, saving Gas.

4. **Off-Chain Indexing (Any User):** Select option `11` to view the Marketplace Catalog. The CLI dynamically reconstructs the active market state by parsing historical `ItemListed` events and filtering for active status, bypassing EVM array limitations.

5. **Purchasing (Buyer):** Switch to a different terminal/user, connect to the active contracts (option `1`), and use option `10` to execute an atomic swap (NFT for ETH).

6. **Edge Cases & Zombie Listings:** Mint a new token, list it, and use option `7` (Raw Gift) to bypass the marketplace and transfer it directly. Check the catalog (option `11`) to observe the Zombie Listing, then safely remove it using option `12`.

7. **Admin Withdrawal:** Return to the Admin terminal and use option `13` to pull the accumulated protocol fees. You can monitor all account balances via option `14`.
