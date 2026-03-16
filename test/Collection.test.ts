import { describe, it } from "node:test";
import { strict as assert } from "node:assert";
import { network } from "hardhat";
import { getAddress, zeroAddress } from "viem";

const { viem, networkHelpers } = await network.connect();

const URI1 = "ipfs://metadata_1.json";

describe("Collection", function () {
    async function deployCollectionSetupFixture() {
        const publicClient = await viem.getPublicClient();
        const [admin, alice, bob, charlie] = await viem.getWalletClients();

        const collection = await viem.deployContract("Collection", [], {
            client: { wallet: admin },
        });

        return {
            collection,
            publicClient,
            admin,
            alice,
            bob,
            charlie,
        };
    }

    // Fixture to setup a minted token
    async function deployAndMintFixture() {
        const setup = await networkHelpers.loadFixture(
            deployCollectionSetupFixture,
        );
        const { collection, alice } = setup;

        const tokenId = 1n;

        await collection.write.mint([URI1], {
            account: alice.account,
        });

        return { ...setup, tokenId };
    }

    it("Should mint a new NFT, assign ownership, and update balances", async function () {
        const { collection, alice } = await networkHelpers.loadFixture(
            deployCollectionSetupFixture,
        );

        const expectedTokenId = 1n;

        // Mint and check Transfer event
        await viem.assertions.emitWithArgs(
            collection.write.mint([URI1], {
                account: alice.account,
            }),
            collection,
            "Transfer",
            [zeroAddress, getAddress(alice.account.address), expectedTokenId],
        );

        // Check ownership and balances
        const owner = await collection.read.ownerOf([expectedTokenId]);
        const balance = await collection.read.balanceOf([
            alice.account.address,
        ]);
        const tokenURI = await collection.read.tokenURI([expectedTokenId]);

        assert.equal(getAddress(owner), getAddress(alice.account.address));
        assert.equal(balance, 1n);
        assert.equal(tokenURI, URI1);
    });

    it("Should support ERC721 and ERC165 interfaces", async function () {
        const { collection } = await networkHelpers.loadFixture(
            deployCollectionSetupFixture,
        );

        const supportsERC721 = await collection.read.supportsInterface([
            "0x80ac58cd",
        ]);
        const supportsERC165 = await collection.read.supportsInterface([
            "0x01ffc9a7",
        ]);

        const supportsRandom = await collection.read.supportsInterface([
            "0xffafff7f",
        ]);

        assert.equal(supportsERC721, true);
        assert.equal(supportsERC165, true);
        assert.equal(supportsRandom, false);
    });

    it("Should allow the owner to approve another address", async function () {
        const { collection, alice, bob, tokenId } =
            await networkHelpers.loadFixture(deployAndMintFixture);

        await viem.assertions.emitWithArgs(
            collection.write.approve([bob.account.address, tokenId], {
                account: alice.account,
            }),
            collection,
            "Approval",
            [
                getAddress(alice.account.address),
                getAddress(bob.account.address),
                tokenId,
            ],
        );

        const approvedAddress = await collection.read.getApproved([tokenId]);
        assert.equal(
            getAddress(approvedAddress),
            getAddress(bob.account.address),
        );
    });

    it("Should allow the owner to set an operator for all tokens", async function () {
        const { collection, alice, bob } = await networkHelpers.loadFixture(
            deployCollectionSetupFixture,
        );

        await viem.assertions.emitWithArgs(
            collection.write.setApprovalForAll([bob.account.address, true], {
                account: alice.account,
            }),
            collection,
            "ApprovalForAll",
            [
                getAddress(alice.account.address),
                getAddress(bob.account.address),
                true,
            ],
        );

        const isApproved = await collection.read.isApprovedForAll([
            alice.account.address,
            bob.account.address,
        ]);
        assert.equal(isApproved, true);
    });

    it("Should allow an approved address to transfer the token via transferFrom", async function () {
        const { collection, alice, bob, charlie, tokenId } =
            await networkHelpers.loadFixture(deployAndMintFixture);

        // Alice approva Bob
        await collection.write.approve([bob.account.address, tokenId], {
            account: alice.account,
        });

        // Bob trasferisce il token a Charlie
        await viem.assertions.emitWithArgs(
            collection.write.transferFrom(
                [alice.account.address, charlie.account.address, tokenId],
                { account: bob.account },
            ),
            collection,
            "Transfer",
            [
                getAddress(alice.account.address),
                getAddress(charlie.account.address),
                tokenId,
            ],
        );

        const newOwner = await collection.read.ownerOf([tokenId]);
        assert.equal(getAddress(newOwner), getAddress(charlie.account.address));

        const approvedAddress = await collection.read.getApproved([tokenId]);
        assert.equal(getAddress(approvedAddress), zeroAddress);
    });

    it("Should allow the owner to safeTransferFrom the token", async function () {
        const { collection, alice, bob, tokenId } =
            await networkHelpers.loadFixture(deployAndMintFixture);

        await viem.assertions.emitWithArgs(
            collection.write.safeTransferFrom(
                [alice.account.address, bob.account.address, tokenId],
                { account: alice.account },
            ),
            collection,
            "Transfer",
            [
                getAddress(alice.account.address),
                getAddress(bob.account.address),
                tokenId,
            ],
        );

        const newOwner = await collection.read.ownerOf([tokenId]);
        assert.equal(getAddress(newOwner), getAddress(bob.account.address));
    });

    it("Should revert with InvalidTokenId when querying a non-existent token", async function () {
        const { collection } = await networkHelpers.loadFixture(
            deployCollectionSetupFixture,
        );

        const invalidId = 99n;

        await viem.assertions.revertWithCustomErrorWithArgs(
            collection.read.ownerOf([invalidId]),
            collection,
            "InvalidTokenId",
            [invalidId],
        );
    });

    it("Should revert with ApprovalToCurrentOwner when the owner approves themselves", async function () {
        const { collection, alice, tokenId } =
            await networkHelpers.loadFixture(deployAndMintFixture);

        await viem.assertions.revertWithCustomError(
            collection.write.approve([alice.account.address, tokenId], {
                account: alice.account,
            }),
            collection,
            "ApprovalToCurrentOwner",
        );
    });

    it("Should revert with CannotApproveSelf when setting self as operator", async function () {
        const { collection, alice } = await networkHelpers.loadFixture(
            deployCollectionSetupFixture,
        );

        await viem.assertions.revertWithCustomError(
            collection.write.setApprovalForAll([alice.account.address, true], {
                account: alice.account,
            }),
            collection,
            "CannotApproveSelf",
        );
    });

    it("Should revert with NotTokenOwner when an unauthorized user tries to approve a token", async function () {
        const { collection, bob, charlie, tokenId } =
            await networkHelpers.loadFixture(deployAndMintFixture);

        // Bob (non proprietario) prova ad approvare Charlie
        await viem.assertions.revertWithCustomErrorWithArgs(
            collection.write.approve([charlie.account.address, tokenId], {
                account: bob.account,
            }),
            collection,
            "NotTokenOwner",
            [
                getAddress(bob.account.address),
                getAddress(collection.address),
                tokenId,
            ],
        );
    });

    it("Should revert with NotTokenOwner when transferFrom has an incorrect 'from' address", async function () {
        const { collection, alice, bob, charlie, tokenId } =
            await networkHelpers.loadFixture(deployAndMintFixture);

        await viem.assertions.revertWithCustomErrorWithArgs(
            collection.write.transferFrom(
                [charlie.account.address, bob.account.address, tokenId],
                { account: alice.account },
            ),
            collection,
            "NotTokenOwner",
            [
                getAddress(charlie.account.address),
                getAddress(collection.address),
                tokenId,
            ],
        );
    });

    it("Should revert with NotTokenOwner when an unauthorized user tries to transfer a token", async function () {
        const { collection, alice, bob, tokenId } =
            await networkHelpers.loadFixture(deployAndMintFixture);

        await viem.assertions.revertWithCustomErrorWithArgs(
            collection.write.transferFrom(
                [alice.account.address, bob.account.address, tokenId],
                { account: bob.account },
            ),
            collection,
            "NotTokenOwner",
            [
                getAddress(bob.account.address),
                getAddress(collection.address),
                tokenId,
            ],
        );
    });

    it("Should revert when trying to transfer to the zero address", async function () {
        const { collection, alice, tokenId } =
            await networkHelpers.loadFixture(deployAndMintFixture);

        await viem.assertions.revertWithCustomError(
            collection.write.transferFrom(
                [alice.account.address, zeroAddress, tokenId],
                { account: alice.account },
            ),
            collection,
            "ZeroAddressNotValid",
        );
    });
});
