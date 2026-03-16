import { describe, it } from "node:test";
import { network } from "hardhat";
import { getAddress, parseEther, zeroAddress } from "viem";

const { viem, networkHelpers } = await network.connect();

const URI1 = "../metadata/token_1.json";
const URI2 = "../metadata/token_2.json";

describe("MarketplaceFlows", function () {
    // Fixture setup
    async function deployMarketplaceFlowsFixture() {
        // Get the public client to read blockchain data
        const publicClient = await viem.getPublicClient();

        // Get the wallet clients
        const [admin, alice, bob, charlie] = await viem.getWalletClients();

        // Define the fee percentage as a BigInt
        const FEE_PERCENT = 5n;

        // Deploy the contracts
        const marketplace = await viem.deployContract(
            "Marketplace",
            [FEE_PERCENT],
            { client: { wallet: admin } },
        );
        const collection = await viem.deployContract("Collection");

        return {
            collection,
            marketplace,
            publicClient,
            admin,
            alice,
            bob,
            charlie,
            FEE_PERCENT,
        };
    }

    // Fixture for setup with some NFT listed
    async function deployAndListFixture() {
        const {
            collection,
            marketplace,
            publicClient,
            admin,
            alice,
            bob,
            charlie,
            FEE_PERCENT,
        } = await networkHelpers.loadFixture(deployMarketplaceFlowsFixture);

        const tokenId = 1n;
        const price = parseEther("1");

        await collection.write.mint(["../metadata/token_1.json"], {
            account: alice.account,
        });

        await collection.write.approve([marketplace.address, tokenId], {
            account: alice.account,
        });

        await marketplace.write.listToken(
            [collection.address, tokenId, price],
            {
                account: alice.account,
            },
        );

        return {
            collection,
            marketplace,
            publicClient,
            admin,
            alice,
            bob,
            charlie,
            FEE_PERCENT,
            tokenId,
            price,
        };
    }

    async function deployAndSellFixture() {
        const {
            collection,
            marketplace,
            publicClient,
            admin,
            alice,
            bob,
            charlie,
            FEE_PERCENT,
            tokenId,
            price,
        } = await networkHelpers.loadFixture(deployAndListFixture);

        await marketplace.write.buyToken([collection.address, tokenId], {
            account: bob.account,
            value: price,
        });

        const feeAmount = (price * FEE_PERCENT) / 100n;
        const sellerRevenue = price - feeAmount;

        return {
            collection,
            marketplace,
            publicClient,
            admin,
            alice,
            bob,
            charlie,
            FEE_PERCENT,
            tokenId,
            price,
            feeAmount,
            sellerRevenue,
        };
    }

    it("Should allow Alice to mint an NFT, approve the marketplace, and list it", async function () {
        const { collection, marketplace, alice } =
            await networkHelpers.loadFixture(deployMarketplaceFlowsFixture);

        // First token of the collection minted (ID: 1)
        const tokenId = 1n;

        // Mint a token and expect Transfer event
        await viem.assertions.emitWithArgs(
            collection.write.mint([URI1], {
                account: alice.account,
            }),
            collection,
            "Transfer",
            [zeroAddress, getAddress(alice.account.address), tokenId],
        );

        // Approve the marketplace and expect Approval event
        await viem.assertions.emitWithArgs(
            collection.write.approve([marketplace.address, tokenId], {
                account: alice.account,
            }),
            collection,
            "Approval",
            [
                getAddress(alice.account.address),
                getAddress(marketplace.address),
                tokenId,
            ],
        );

        const price = parseEther("1");

        // List the Token expecting the ItemListed event
        await viem.assertions.emitWithArgs(
            marketplace.write.listToken([collection.address, tokenId, price], {
                account: alice.account,
            }),
            marketplace,
            "ItemListed",
            [
                getAddress(collection.address),
                tokenId,
                getAddress(alice.account.address),
                price,
            ],
        );
    });

    it("Should allow Bob to buy a listed NFT", async function () {
        const {
            marketplace,
            collection,
            bob,
            alice,
            tokenId,
            price,
            FEE_PERCENT,
        } = await networkHelpers.loadFixture(deployAndListFixture);

        const buyTokenPromise = marketplace.write.buyToken(
            [collection.address, tokenId],
            {
                account: bob.account,
                value: price,
            },
        );

        await viem.assertions.emitWithArgs(
            buyTokenPromise,
            collection,
            "Transfer",
            [
                getAddress(alice.account.address),
                getAddress(bob.account.address),
                tokenId,
            ],
        );

        await viem.assertions.emitWithArgs(
            buyTokenPromise,
            marketplace,
            "ItemSold",
            [
                getAddress(collection.address),
                tokenId,
                getAddress(bob.account.address),
                getAddress(alice.account.address),
                price,
            ],
        );

        const feeAmount = (price * FEE_PERCENT) / 100n;
        const sellerRevenue = price - feeAmount;

        await viem.assertions.balancesHaveChanged(buyTokenPromise, [
            { address: bob.account.address, amount: -price },
            { address: alice.account.address, amount: sellerRevenue },
            { address: marketplace.address, amount: feeAmount },
        ]);
    });

    it("Should allow Alice to cancel the listing", async function () {
        const { marketplace, collection, alice, tokenId } =
            await networkHelpers.loadFixture(deployAndListFixture);

        await viem.assertions.emitWithArgs(
            marketplace.write.cancelListing([collection.address, tokenId], {
                account: alice.account,
            }),
            marketplace,
            "ItemCanceled",
            [
                getAddress(collection.address),
                tokenId,
                getAddress(alice.account.address),
            ],
        );
    });

    it("Should allow Alice to create multiple NFTs, approve the Marketplace for all her tokens and list them", async function () {
        const { marketplace, collection, alice } =
            await networkHelpers.loadFixture(deployMarketplaceFlowsFixture);

        const firstTokenId = 1n;
        const secondTokenId = 2n;
        const firstPrice = parseEther("1");
        const secondPrice = parseEther("4");

        await viem.assertions.emitWithArgs(
            collection.write.mint([URI1], {
                account: alice.account,
            }),
            collection,
            "Transfer",
            [zeroAddress, getAddress(alice.account.address), firstTokenId],
        );

        await viem.assertions.emitWithArgs(
            collection.write.setApprovalForAll([marketplace.address, true], {
                account: alice.account,
            }),
            collection,
            "ApprovalForAll",
            [
                getAddress(alice.account.address),
                getAddress(marketplace.address),
                true,
            ],
        );

        await viem.assertions.emitWithArgs(
            collection.write.mint([URI2], {
                account: alice.account,
            }),
            collection,
            "Transfer",
            [zeroAddress, getAddress(alice.account.address), secondTokenId],
        );

        await viem.assertions.emitWithArgs(
            marketplace.write.listToken(
                [collection.address, firstTokenId, firstPrice],
                {
                    account: alice.account,
                },
            ),
            marketplace,
            "ItemListed",
            [
                getAddress(collection.address),
                firstTokenId,
                getAddress(alice.account.address),
                firstPrice,
            ],
        );

        await viem.assertions.emitWithArgs(
            marketplace.write.listToken(
                [collection.address, secondTokenId, secondPrice],
                {
                    account: alice.account,
                },
            ),
            marketplace,
            "ItemListed",
            [
                getAddress(collection.address),
                secondTokenId,
                getAddress(alice.account.address),
                secondPrice,
            ],
        );
    });

    it("Should allow any user to cancel a zombie listing after a private transfer", async function () {
        const { marketplace, collection, alice, bob, charlie, tokenId } =
            await networkHelpers.loadFixture(deployAndListFixture);

        await viem.assertions.emitWithArgs(
            collection.write.transferFrom(
                [alice.account.address, charlie.account.address, tokenId],
                { account: alice.account },
            ),
            collection,
            "Transfer",
            [
                getAddress(alice.account.address),
                getAddress(charlie.account.address),
                tokenId,
            ],
        );

        await viem.assertions.emitWithArgs(
            marketplace.write.cancelListing([collection.address, tokenId], {
                account: bob.account,
            }),
            marketplace,
            "ItemCanceled",
            [
                getAddress(collection.address),
                tokenId,
                getAddress(bob.account.address),
            ],
        );
    });

    it("Should allow the admin to withdraw accumulated fees", async function () {
        const { marketplace, admin, feeAmount } =
            await networkHelpers.loadFixture(deployAndSellFixture);

        await viem.assertions.balancesHaveChanged(
            marketplace.write.withdrawFees({ account: admin.account }),
            [
                { address: marketplace.address, amount: -feeAmount },
                { address: admin.account.address, amount: feeAmount },
            ],
        );
    });
});
