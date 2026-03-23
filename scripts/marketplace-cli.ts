import {
    createWalletClient,
    createPublicClient,
    http,
    parseEther,
    parseEventLogs,
    formatEther,
    BaseError,
} from "viem";
import { hardhat } from "viem/chains";
import { privateKeyToAccount } from "viem/accounts";
import * as readline from "readline/promises";
import { stdin, stdout } from "process";
import { HARDHAT_PRIVATE_KEYS } from "./accounts.js";
import * as fs from "fs/promises";
import * as path from "path";
import { randomBytes } from "crypto";

// Static imports for ABI and Bytecode
import CollectionArtifact from "../artifacts/contracts/Collection.sol/Collection.json";
import MarketplaceArtifact from "../artifacts/contracts/Marketplace.sol/Marketplace.json";

// input/output interface
const rl = readline.createInterface({ input: stdin, output: stdout });

// Setup Public Client
const publicClient = createPublicClient({
    chain: hardhat,
    transport: http(),
});

// Session state (connected Collection and Marketplace)
let activeCollection: `0x${string}` | null = null;
let activeMarketplace: `0x${string}` | null = null;

// CLI entry point
async function main() {
    console.log("\n\t------ LOCAL WEB3 ENVIRONMENT CLI -----\n\n ");

    // Login
    let accountIndex = -1;
    while (accountIndex < 0 || accountIndex >= HARDHAT_PRIVATE_KEYS.length) {
        const inputStr = await rl.question(
            `> Select account (0-${HARDHAT_PRIVATE_KEYS.length - 1}): `,
        );
        accountIndex = parseInt(inputStr.trim());
    }

    let sessionName = await rl.question("> Enter name (optional): ");
    if (!sessionName.trim()) {
        sessionName = `User_${accountIndex}`;
    }

    // Setup Client Wallet
    const privateKey = HARDHAT_PRIVATE_KEYS[accountIndex] as `0x${string}`;
    const account = privateKeyToAccount(privateKey);
    const walletClient = createWalletClient({
        account,
        chain: hardhat,
        transport: http(),
    });

    console.log(`\nLogged in as: ${sessionName} (${account.address})`);

    // Main loop
    let isRunning = true;
    while (isRunning) {
        console.log("\n=========================================");
        console.log(`[USER]  ${sessionName} (${account.address})`);
        console.log("=========================================");
        console.log("-----------------------------------------");
        console.log(`Active Collection: ${activeCollection || "None"}`);
        console.log(`Active Marketplace: ${activeMarketplace || "None"}`);
        console.log("-----------------------------------------");
        console.log("--- SETUP ---");
        console.log("1. Connect to existing contracts");
        console.log("2. Deploy NEW Collection");
        console.log("3. Deploy NEW Marketplace");
        console.log("\n--- COLLECTION ACTIONS ---");
        console.log("4. Mint NFT");
        console.log("5. View My NFTs (Inventory)");
        console.log(
            "6. Approve Marketplace for ALL tokens (setApprovalForAll)",
        );
        console.log("7. Gift Token [RAW] (Leaves Zombie Listing)");
        console.log("8. Gift Token [SAFE] (Cancels listing before transfer)");
        console.log("\n--- MARKETPLACE ACTIONS ---");
        console.log("9. List NFT");
        console.log("10. Buy NFT");
        console.log("11. View Market Listings");
        console.log("12. Cancel Listing");
        console.log("\n--- ADMIN ---");
        console.log("13. Withdraw Fees");
        console.log("\n--- UTILS ---");
        console.log("14. View Account Balances");
        console.log("0. Exit");

        const choice = await rl.question("\n> Choose an action: ");

        switch (choice.trim()) {
            case "1":
                const colInput = await rl.question(
                    "> Enter Collection Address (or press enter to skip): ",
                );
                if (colInput.trim() !== "") {
                    activeCollection = colInput.trim() as `0x${string}`;
                }

                const mktInput = await rl.question(
                    "> Enter Marketplace Address (or press enter to skip): ",
                );
                if (mktInput.trim() !== "") {
                    activeMarketplace = mktInput.trim() as `0x${string}`;
                }

                console.log("Addresses updated!");
                break;
            case "2":
                console.log("Deploying Collection contract...");

                // Deploy the contract
                const collectionHash = await walletClient.deployContract({
                    abi: CollectionArtifact.abi,
                    bytecode: CollectionArtifact.bytecode as `0x${string}`,
                });

                // Wait for the block to be mined
                const collectionReceipt =
                    await publicClient.waitForTransactionReceipt({
                        hash: collectionHash,
                    });

                // Check
                if (!collectionReceipt.contractAddress) {
                    console.error(
                        "Deployment failed: No contract address returned.",
                    );
                    break;
                }

                activeCollection = collectionReceipt.contractAddress;
                console.log(`Collection deployed at: ${activeCollection}`);
                break;
            case "3":
                // Read feePercent as user input
                const feeInput = await rl.question(
                    "\n> Enter the fee percentage for the Marketplace (0-20): ",
                );

                // Check if input contains only digits
                if (!/^\d+$/.test(feeInput.trim())) {
                    console.error(
                        "Invalid input. Please enter a valid number.",
                    );
                    break;
                }

                const feePercent = BigInt(feeInput.trim());

                if (feePercent > 20n) {
                    console.error(
                        `Fee too high (${feePercent}%). Maximum allowed is 20%.`,
                    );
                    break;
                }

                console.log(
                    `\nDeploying Marketplace contract (Fee: ${feePercent}%)...`,
                );
                // Deploy the Marketplace contract
                const marketplaceHash = await walletClient.deployContract({
                    abi: MarketplaceArtifact.abi,
                    bytecode: MarketplaceArtifact.bytecode as `0x${string}`,
                    args: [feePercent], // Constructor argument
                });

                const marketplaceReceipt =
                    await publicClient.waitForTransactionReceipt({
                        hash: marketplaceHash,
                    });

                if (!marketplaceReceipt.contractAddress) {
                    console.error(
                        "Deployment failed: No contract address returned.",
                    );
                    break;
                }

                activeMarketplace = marketplaceReceipt.contractAddress;
                console.log(`Marketplace deployed at: ${activeMarketplace}`);
                break;
            case "4":
                // Ensure a collection is active before minting
                if (!activeCollection) {
                    console.error(
                        "Error: Connect or deploy a Collection first!",
                    );
                    break;
                }

                console.log("\n--- MINT NEW NFT ---");
                const nftName = await rl.question("> Enter NFT Name: ");

                if (!nftName.trim()) {
                    console.error("Error: NFT Name cannot be empty.");
                    break;
                }

                const nftDesc = await rl.question(
                    "> Enter NFT Description (optional): ",
                );

                // Save JSON locally
                const tokenURI = await saveMetadata(
                    nftName,
                    nftDesc,
                    sessionName,
                );

                // Execute Smart Contract Minting
                console.log(
                    `\nMinting NFT on Collection (${activeCollection})...`,
                );

                try {
                    const mintHash = await walletClient.writeContract({
                        address: activeCollection,
                        abi: CollectionArtifact.abi,
                        functionName: "mint",
                        args: [tokenURI], // Passing the fake URI
                    });

                    // Wait for the block confirmation
                    const mintReceipt =
                        await publicClient.waitForTransactionReceipt({
                            hash: mintHash,
                        });

                    // Read the Transfer event to get the tokenId
                    const logs = parseEventLogs({
                        abi: CollectionArtifact.abi,
                        eventName: "Transfer",
                        logs: mintReceipt.logs,
                    });

                    let mintedTokenId = "Unknown";
                    // If we found the Transfer event, extract the tokenId
                    if (logs.length > 0) {
                        const event = logs[0] as any;

                        if (event.args && event.args.tokenId !== undefined) {
                            mintedTokenId = event.args.tokenId.toString();
                        }
                    }

                    console.log(`NFT Minted successfully!`);
                    console.log(`Token ID: ${mintedTokenId}`);
                    console.log(
                        `Transaction Hash: ${mintReceipt.transactionHash}`,
                    );
                } catch (error) {
                    console.error("Minting failed:");
                    printCleanError(error);
                }
                break;
            case "5":
                console.log("\n--- MY NFT INVENTORY ---");
                const invColInput = await rl.question(
                    `> Enter Collection Address (Press Enter to use active: ${activeCollection || "None"}): `,
                );

                const inventoryCollection =
                    invColInput.trim() !== ""
                        ? (invColInput.trim() as `0x${string}`)
                        : activeCollection;

                if (!inventoryCollection) {
                    console.error("Error: Collection address is required.");
                    break;
                }

                console.log(
                    `Scanning blockchain for your tokens in Collection ${inventoryCollection}...`,
                );

                try {
                    // Fetch all Transfer events for this collection
                    const transferLogs = await publicClient.getLogs({
                        address: inventoryCollection,
                        events: CollectionArtifact.abi.filter(
                            (item: any) =>
                                item.type === "event" &&
                                item.name === "Transfer",
                        ),
                        fromBlock: "earliest", // From the first block, works for hardhat but not on real chains
                    });

                    // Find unique Token IDs that our account has ever interacted with
                    const candidateTokens = new Set<bigint>();
                    const myAddress = account.address.toLowerCase();

                    for (const log of transferLogs) {
                        const event = log as any;
                        if (event.args && event.args.tokenId !== undefined) {
                            const fromAddress = event.args.from?.toLowerCase();
                            const toAddress = event.args.to?.toLowerCase();

                            // If we received it or sent it, add to candidates
                            if (
                                fromAddress === myAddress ||
                                toAddress === myAddress
                            ) {
                                candidateTokens.add(BigInt(event.args.tokenId));
                            }
                        }
                    }

                    let ownedCount = 0;

                    // Verify current ownership directly on-chain
                    for (const tokenId of candidateTokens) {
                        try {
                            const currentOwner =
                                (await publicClient.readContract({
                                    address: inventoryCollection,
                                    abi: CollectionArtifact.abi,
                                    functionName: "ownerOf",
                                    args: [tokenId],
                                })) as string;

                            // If we are still the owner, fetch metadata and print!
                            if (currentOwner.toLowerCase() === myAddress) {
                                ownedCount++;

                                let nftName = "Unknown";
                                let description = "No description available";

                                try {
                                    // Fetch Metadata URI
                                    const tokenURI =
                                        (await publicClient.readContract({
                                            address: inventoryCollection,
                                            abi: CollectionArtifact.abi,
                                            functionName: "tokenURI",
                                            args: [tokenId],
                                        })) as string;

                                    // Parse local JSON mock IPFS
                                    const cid = tokenURI.replace("ipfs://", "");
                                    const filePath = path.join(
                                        process.cwd(),
                                        "metadata",
                                        `${cid}.json`,
                                    );
                                    const fileContent = await fs.readFile(
                                        filePath,
                                        "utf-8",
                                    );
                                    const metadata = JSON.parse(fileContent);

                                    nftName = metadata.name || "Unknown";
                                    description =
                                        metadata.description ||
                                        "No description available";
                                } catch (e) {
                                    nftName =
                                        "[Metadata unreadable or missing off-chain]";
                                }

                                console.log(
                                    "\n-----------------------------------------",
                                );
                                console.log(`Token ID:   ${tokenId}`);
                                console.log(`Title:      ${nftName}`);
                                console.log(
                                    `Description:       ${description}`,
                                );
                            }
                        } catch (e) {
                            // Ingore if ownerOf reverts
                        }
                    }

                    if (ownedCount === 0) {
                        console.log(
                            "\nYou don't own any tokens in this collection right now.",
                        );
                    } else {
                        console.log(
                            "-----------------------------------------",
                        );
                        console.log(`Total Owned: ${ownedCount} NFTs`);
                    }
                } catch (error) {
                    console.error("Error: Failed to fetch inventory:");
                    printCleanError(error);
                }
                break;
            case "6":
                if (!activeCollection || !activeMarketplace) {
                    console.error(
                        "Error: Connect both Collection and Marketplace first.",
                    );
                    break;
                }

                console.log("\n--- APPROVE ALL TOKENS ---");
                console.log(
                    `Approving Marketplace (${activeMarketplace}) to handle all your tokens on Collection (${activeCollection})...`,
                );

                try {
                    const approveAllHash = await walletClient.writeContract({
                        address: activeCollection,
                        abi: CollectionArtifact.abi,
                        functionName: "setApprovalForAll",
                        args: [activeMarketplace, true],
                    });

                    await publicClient.waitForTransactionReceipt({
                        hash: approveAllHash,
                    });
                    console.log("Global approval granted.");
                } catch (error) {
                    console.error("Error: Approval failed:");
                    printCleanError(error);
                }
                break;
            case "7":
                if (!activeCollection) {
                    console.error("Error: Connect to a Collection first.");
                    break;
                }

                console.log("\n--- RAW GIFT TOKEN (Creates Zombie) ---");
                const giftToInput = await rl.question(
                    "> Enter recipient address: ",
                );
                const giftTokenIdInput = await rl.question(
                    "> Enter Token ID to gift: ",
                );

                try {
                    console.log(
                        "Transferring token directly via Collection contract...",
                    );
                    const giftHash = await walletClient.writeContract({
                        address: activeCollection,
                        abi: CollectionArtifact.abi,
                        functionName: "transferFrom",
                        args: [
                            account.address,
                            giftToInput.trim(),
                            BigInt(giftTokenIdInput.trim()),
                        ],
                    });

                    await publicClient.waitForTransactionReceipt({
                        hash: giftHash,
                    });
                    console.log(
                        "Token transferred. If it was listed, it is now a Zombie Listing.",
                    );
                } catch (error) {
                    console.error("Error: Raw transfer failed:");
                    printCleanError(error);
                }
                break;
            case "8":
                if (!activeCollection || !activeMarketplace) {
                    console.error(
                        "Error: Connect both Collection and Marketplace first.",
                    );
                    break;
                }

                console.log("\n--- SAFE GIFT TOKEN (Auto-Cancel) ---");
                const safeGiftToInput = await rl.question(
                    "> Transfer to (address): ",
                );
                const safeGiftTokenIdInput = await rl.question(
                    "> Enter Token ID to gift: ",
                );
                const safeTokenId = BigInt(safeGiftTokenIdInput.trim());

                try {
                    console.log(
                        "Step 1/2: Attempting to cancel marketplace listing...",
                    );

                    try {
                        const autoCancelHash = await walletClient.writeContract(
                            {
                                address: activeMarketplace,
                                abi: MarketplaceArtifact.abi,
                                functionName: "cancelListing",
                                args: [activeCollection, safeTokenId],
                            },
                        );
                        await publicClient.waitForTransactionReceipt({
                            hash: autoCancelHash,
                        });
                        console.log("Listing canceled successfully.");
                    } catch (e) {
                        console.warn(
                            "No active listing found to cancel, proceeding with transfer.",
                        );
                    }

                    console.log("Step 2/2: Transferring token...");
                    const safeGiftHash = await walletClient.writeContract({
                        address: activeCollection,
                        abi: CollectionArtifact.abi,
                        functionName: "transferFrom",
                        args: [
                            account.address,
                            safeGiftToInput.trim(),
                            safeTokenId,
                        ],
                    });

                    await publicClient.waitForTransactionReceipt({
                        hash: safeGiftHash,
                    });
                    console.log("Token transferred safely.");
                } catch (error) {
                    console.error("Error: Safe transfer failed:");
                    printCleanError(error);
                }
                break;
            case "9":
                // Ensure both contracts are active
                if (!activeCollection || !activeMarketplace) {
                    console.error(
                        "Error: Connect both Collection and Marketplace first!",
                    );
                    break;
                }

                console.log("\n--- LIST NFT FOR SALE ---");
                const tokenIdInput = await rl.question(
                    "> Enter Token ID to list: ",
                );
                const tokenId = BigInt(tokenIdInput.trim());

                const priceInput = await rl.question(
                    "> Enter Price (in ETH, e.g., 0.5): ",
                );

                // Convert readable ETH string to Wei (BigInt)
                const priceInWei = parseEther(priceInput.trim());

                if (priceInWei <= 0n) {
                    console.error("Error: Price must be greater than 0.");
                    break;
                }

                try {
                    // Approve the Marketplace to move the NFT
                    console.log(
                        `\nStep 1/2: Approving Marketplace to handle Token ID ${tokenId}...`,
                    );

                    // Check if the marketplace is already approved
                    const getApprovedAddress = (await publicClient.readContract(
                        {
                            address: activeCollection,
                            abi: CollectionArtifact.abi,
                            functionName: "getApproved",
                            args: [tokenId],
                        },
                    )) as string;

                    // Check if the marketplace is approved for all tokens
                    const isOperator = (await publicClient.readContract({
                        address: activeCollection,
                        abi: CollectionArtifact.abi,
                        functionName: "isApprovedForAll",
                        args: [account.address, activeMarketplace],
                    })) as boolean;

                    if (isOperator) {
                        console.log(
                            "This marketplace was already approve for all the collection's Tokens",
                        );
                    } else if (
                        getApprovedAddress.toLowerCase() ===
                        activeMarketplace.toLowerCase()
                    ) {
                        console.log(
                            "The marketplace was already approved for this token",
                        );
                    } else {
                        const approveHash = await walletClient.writeContract({
                            address: activeCollection,
                            abi: CollectionArtifact.abi,
                            functionName: "approve",
                            args: [activeMarketplace, tokenId],
                        });

                        await publicClient.waitForTransactionReceipt({
                            hash: approveHash,
                        });

                        console.log("Approval successful!");
                    }

                    // List the token on the Marketplace
                    console.log(
                        `\nStep 2/2: Listing Token ID ${tokenId} for ${priceInput} ETH...`,
                    );

                    const listHash = await walletClient.writeContract({
                        address: activeMarketplace,
                        abi: MarketplaceArtifact.abi,
                        functionName: "listToken",
                        args: [activeCollection, tokenId, priceInWei],
                    });

                    await publicClient.waitForTransactionReceipt({
                        hash: listHash,
                    });

                    console.log(
                        "Token successfully listed on the Marketplace!",
                    );
                } catch (error) {
                    console.error("Listing failed:");
                    printCleanError(error);
                }
                break;
            case "10":
                if (!activeMarketplace) {
                    console.error("Error: Connect to a Marketplace first!");
                    break;
                }

                console.log("\n--- BUY NFT ---");
                const buyColInput = await rl.question(
                    `> Enter Collection Address (Press Enter to use active: ${activeCollection || "None"}): `,
                );

                // Use input if provided, otherwise fallback to activeCollection
                const buyCollectionAddress =
                    buyColInput.trim() !== ""
                        ? (buyColInput.trim() as `0x${string}`)
                        : activeCollection;

                if (!buyCollectionAddress) {
                    console.error("Error: Collection address is required.");
                    break;
                }

                const buyTokenIdInput = await rl.question(
                    "> Enter Token ID to buy: ",
                );
                const buyTokenId = BigInt(buyTokenIdInput.trim());

                console.log(`\nChecking availability and price on-chain...`);

                try {
                    // Read the market item to get the exact required price
                    const itemData = (await publicClient.readContract({
                        address: activeMarketplace,
                        abi: MarketplaceArtifact.abi,
                        functionName: "_marketItems",
                        args: [buyCollectionAddress, buyTokenId],
                    })) as [string, bigint, boolean];

                    const isItemActive = itemData[2];
                    const itemPriceInWei = itemData[1];

                    if (!isItemActive) {
                        console.error(
                            "Error: This item is not currently active on the market.",
                        );
                        break;
                    }

                    console.log(
                        `Exact price found: ${formatEther(itemPriceInWei)} ETH. Proceeding with purchase...`,
                    );

                    // Execute the purchase
                    const buyHash = await walletClient.writeContract({
                        address: activeMarketplace,
                        abi: MarketplaceArtifact.abi,
                        functionName: "buyToken",
                        args: [buyCollectionAddress, buyTokenId],
                        value: itemPriceInWei,
                    });

                    // Wait for the block confirmation
                    const buyReceipt =
                        await publicClient.waitForTransactionReceipt({
                            hash: buyHash,
                        });

                    console.log(
                        "\nPurchase successful! You are the new owner of the NFT.",
                    );
                    console.log(
                        `Transaction Hash: ${buyReceipt.transactionHash}`,
                    );
                } catch (error) {
                    console.error("Purchase failed:");
                    printCleanError(error);
                }
                break;
            case "11":
                if (!activeMarketplace) {
                    console.error("Error: Connect to a Marketplace first!");
                    break;
                }

                console.log("\n---  MARKETPLACE CATALOG ---\n");

                // Read Marketplace stats
                const ownerAddress = (await publicClient.readContract({
                    address: activeMarketplace,
                    abi: MarketplaceArtifact.abi,
                    functionName: "_feeAccount",
                })) as string;

                const marketplaceFeePercent = (await publicClient.readContract({
                    address: activeMarketplace,
                    abi: MarketplaceArtifact.abi,
                    functionName: "_feePercent",
                })) as bigint;

                const balanceInWei = await publicClient.getBalance({
                    address: activeMarketplace,
                });

                const balanceInEth = formatEther(balanceInWei);

                console.log("\n=========================================");
                console.log(`[OWNER]  ${ownerAddress}`);
                console.log(`[BALANCE]  ${balanceInEth}`);
                console.log(`[FEE] ${marketplaceFeePercent}%`);
                console.log("=========================================");

                console.log("Scanning blockchain for active listings...");
                try {
                    // Fetch all 'ItemListed' events to find which tokens were ever listed.
                    const logs = await publicClient.getLogs({
                        address: activeMarketplace,
                        events: MarketplaceArtifact.abi.filter(
                            (item: any) =>
                                item.type === "event" &&
                                item.name === "ItemListed",
                        ),
                        fromBlock: "earliest", // From the first block, works for hardhat but not on real chains
                    });

                    // Use a Set to store unique collection-id identifier
                    const uniqueListings = new Set<string>();
                    for (const log of logs) {
                        const event = log as any;
                        if (
                            event.args &&
                            event.args.nftCollection &&
                            event.args.tokenId !== undefined
                        ) {
                            uniqueListings.add(
                                `${event.args.nftCollection}-${event.args.tokenId}`,
                            );
                        }
                    }

                    let activeCount = 0;

                    // Iterate through unique pairs and check their current status directly in the contract mapping
                    for (const listingKey of uniqueListings) {
                        // Split the composite key back into address and ID
                        const [collectionAddress, tokenIdStr] =
                            listingKey.split("-");
                        const tokenId = BigInt(tokenIdStr);

                        // The mapping _marketItems returns an array/tuple: [seller, price, isActive]
                        const itemData = (await publicClient.readContract({
                            address: activeMarketplace,
                            abi: MarketplaceArtifact.abi,
                            functionName: "_marketItems",
                            args: [collectionAddress as `0x${string}`, tokenId],
                        })) as [string, bigint, boolean];

                        const isActive = itemData[2];

                        if (isActive) {
                            activeCount++;
                            const seller = itemData[0];
                            const priceInWei = itemData[1];
                            const priceInEth = formatEther(priceInWei);

                            let nftName = "Unknown";
                            let artistName = "Unknown";
                            let description = "No description available";

                            try {
                                //Fetch Metadata URI from the Collection contract
                                const tokenURI =
                                    (await publicClient.readContract({
                                        address:
                                            collectionAddress as `0x${string}`,
                                        abi: CollectionArtifact.abi,
                                        functionName: "tokenURI",
                                        args: [tokenId],
                                    })) as string;

                                // Read local JSON
                                const cid = tokenURI.replace("ipfs://", "");
                                const filePath = path.join(
                                    process.cwd(),
                                    "metadata",
                                    `${cid}.json`,
                                );

                                const fileContent = await fs.readFile(
                                    filePath,
                                    "utf-8",
                                );
                                const metadata = JSON.parse(fileContent);

                                nftName = metadata.name || "Unknown";
                                description =
                                    metadata.description ||
                                    "No description available";

                                // Find the Artist
                                const artistAttr = metadata.attributes?.find(
                                    (a: any) => a.trait_type === "Artist",
                                );
                                artistName = artistAttr
                                    ? artistAttr.value
                                    : "Unknown";
                            } catch (e) {
                                nftName =
                                    "[Metadata unreadable or missing off-chain]";
                            }

                            // Print the formatted Item Card
                            console.log(
                                "\n-----------------------------------------",
                            );
                            console.log(`Token ID:   ${tokenId}`);
                            console.log(`Collection: ${collectionAddress}`);
                            console.log(`Title:      ${nftName}`);
                            console.log(`Artist:     ${artistName}`);
                            console.log(`Desc:       ${description}`);
                            console.log(`Price:      ${priceInEth} ETH`);
                            console.log(`Seller:     ${seller}`);
                        }
                    }

                    if (activeCount === 0) {
                        console.log("\nThe marketplace is currently empty.");
                    } else {
                        console.log(
                            "-----------------------------------------",
                        );
                    }
                } catch (error) {
                    console.error("Failed to fetch marketplace listings:");
                    printCleanError(error);
                }
                break;
            case "12":
                if (!activeMarketplace) {
                    console.error("Error: Connect to a Marketplace first.");
                    break;
                }

                console.log("\n--- CANCEL LISTING ---");
                const cancelColInput = await rl.question(
                    `> Enter Collection Address (Press Enter to use active: ${activeCollection || "None"}): `,
                );
                const cancelCollectionAddress =
                    cancelColInput.trim() !== ""
                        ? (cancelColInput.trim() as `0x${string}`)
                        : activeCollection;

                if (!cancelCollectionAddress) {
                    console.error("Error: Collection address is required.");
                    break;
                }

                const cancelTokenIdInput = await rl.question(
                    "> Enter Token ID to cancel: ",
                );
                const cancelTokenId = BigInt(cancelTokenIdInput.trim());

                try {
                    console.log("Canceling listing...");
                    const cancelHash = await walletClient.writeContract({
                        address: activeMarketplace,
                        abi: MarketplaceArtifact.abi,
                        functionName: "cancelListing",
                        args: [cancelCollectionAddress, cancelTokenId],
                    });

                    await publicClient.waitForTransactionReceipt({
                        hash: cancelHash,
                    });
                    console.log("Listing canceled successfully.");
                } catch (error) {
                    console.error("Error: Cancellation failed:");
                    printCleanError(error);
                }
                break;
            case "13":
                if (!activeMarketplace) {
                    console.error("Error: Connect to a Marketplace first.");
                    break;
                }

                console.log("\n--- WITHDRAW FEES (Admin Only) ---");
                try {
                    console.log("Attempting to withdraw accumulated fees...");
                    const withdrawHash = await walletClient.writeContract({
                        address: activeMarketplace,
                        abi: MarketplaceArtifact.abi,
                        functionName: "withdrawFees",
                    });

                    const withdrawReceipt =
                        await publicClient.waitForTransactionReceipt({
                            hash: withdrawHash,
                        });
                    console.log("Fees withdrawn to admin account.");
                    console.log(
                        `Transaction Hash: ${withdrawReceipt.transactionHash}`,
                    );
                } catch (error) {
                    console.error("Error: Withdraw failed:");
                    printCleanError(error);
                }
                break;
            case "14":
                console.log("\n--- VIEW ACCOUNT BALANCES ---");
                try {
                    console.log("Fetching balances from local blockchain...\n");

                    for (let i = 0; i < 20; i++) {
                        const privateKey = HARDHAT_PRIVATE_KEYS[
                            i
                        ] as `0x${string}`;
                        const tempAccount = privateKeyToAccount(privateKey);

                        // Fetch the balance in Wei directly from the Hardhat node
                        const balanceInWei = await publicClient.getBalance({
                            address: tempAccount.address,
                        });

                        // Convert to ETH
                        const balanceInEth = formatEther(balanceInWei);

                        // Highlight the currently active session account
                        const isActive =
                            tempAccount.address === account.address;
                        const prefix = isActive ? "-->" : "   ";
                        const label = isActive ? "(YOU)  " : `(Account ${i})`;

                        console.log(
                            `${prefix} ${label} ${tempAccount.address}: ${balanceInEth} ETH`,
                        );
                    }
                    console.log("\nBalances updated successfully.");
                } catch (error) {
                    console.error("Error: Failed to fetch balances:");
                    printCleanError(error);
                }
                break;

            case "0":
                console.log(`\nBye ${sessionName}!`);
                isRunning = false;
                break;
            default:
                console.log("\nInvalid option.");
        }

        if (isRunning) {
            await rl.question("\n[Press Enter to continues...]");
        }
    }

    rl.close();
}

// Start the script
main().catch((error) => {
    // Intercept the Ctrl+C abort error from readline
    if (error.code === "ABORT_ERR") {
        console.log("\nExiting CLI...");
        process.exit(0);
    } else {
        // Print actual unexpected errors
        console.error(error);
    }
});

// Utils

/**
 * Parses and prints clean, readable errors from viem/contracts
 * instead of dumping the massive unreadable object trace.
 */
function printCleanError(error: unknown) {
    if (error instanceof BaseError) {
        // Viem errors
        console.error(`Error details: ${error.shortMessage}`);
    } else if (error instanceof Error) {
        // JavaScript errors
        console.error(`Error details: ${error.message}`);
    } else {
        console.error("Error details: An unknown error occurred.");
    }
}

// Helpers

/**
 * Simulates uploading NFT metadata to IPFS by saving a JSON file locally.
 * Formatted according to the ERC-721 standard.
 * * @param name The name of the NFT
 * @param description The description of the NFT
 * @returns The simulated IPFS URI (e.g., ipfs://<fake-hash>)
 */
async function saveMetadata(
    name: string,
    description: string,
    artistName: string,
): Promise<string> {
    // Define the local directory path
    const metadataDir = path.join(process.cwd(), "metadata");

    // Ensure the directory exists (creates it if it doesn't)
    await fs.mkdir(metadataDir, { recursive: true });

    // Generate a fake IPFS Content Identifier (CID) using crypto for realism
    const fakeCid = randomBytes(16).toString("hex");
    const fileName = `${fakeCid}.json`;
    const filePath = path.join(metadataDir, fileName);

    // Create the JSON payload following standard NFT metadata structures
    const metadata = {
        name: name,
        description: description,
        image: `ipfs://${fakeCid}-image.png`, // Mock image link
        attributes: [
            {
                trait_type: "Artist",
                value: artistName,
            },
            {
                trait_type: "Environment",
                value: "Local Hardhat Testing",
            },
            {
                display_type: "date",
                trait_type: "Created At",
                value: Date.now(),
            },
        ],
    };

    // Write the formatted JSON to the file system
    await fs.writeFile(filePath, JSON.stringify(metadata, null, 2));

    console.log(
        `\n[Mock IPFS] Metadata successfully saved to: metadata/${fileName}`,
    );

    // Return the standard IPFS URI format expected by the Smart Contract
    return `ipfs://${fakeCid}`;
}
