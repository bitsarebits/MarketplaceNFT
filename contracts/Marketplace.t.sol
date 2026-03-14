// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Collection} from "../contracts/Collection.sol";
import {Marketplace} from "../contracts/Marketplace.sol";
import "../errors/SharedErrors.sol";

contract MarketplaceTest is Test {
    Collection public collection;
    Marketplace public marketplace;

    // Fake addresses
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");
    address public admin = makeAddr("admin");

    // Initial constants
    uint256 public constant FEE_PERCENT = 5; // 5% fee
    uint256 public constant LISTING_PRICE = 1 ether;

    // Events copied from Marketplace.sol
    event ItemListed(
        address indexed nftCollection,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );

    event ItemSold(
        address indexed nftCollection,
        uint256 indexed tokenId,
        address indexed buyer,
        address seller,
        uint256 price
    );

    event ItemCanceled(
        address indexed nftCollection,
        uint256 indexed tokenId,
        address indexed seller
    );

    function setUp() public {
        // Deploy the collection
        collection = new Collection();

        // Deploy the marketplace as the admin
        vm.prank(admin);
        marketplace = new Marketplace(FEE_PERCENT);

        // Give some fake ETH to Bob and Charlie for buying NFTs
        vm.deal(bob, 100 ether);
        vm.deal(charlie, 100 ether);
    }

    // ==========================================
    // CONSTRUCTOR TESTS
    // ==========================================
    // test_ConstructorSuccess()
    // test_ConstructorRevert_FeeTooHigh()

    /**
     * @notice Tests the successful initialization of the marketplace.
     */
    function test_ConstructorSuccess() public view {
        assertEq(
            marketplace._feeAccount(),
            admin,
            "Fee account should be the deployer (admin)"
        );
        assertEq(
            marketplace._feePercent(),
            FEE_PERCENT,
            "Fee percent should be set correctly"
        );
    }

    /**
     * @notice Tests that the constructor reverts if the fee is above 20%.
     */
    function test_ConstructorRevert_FeeTooHigh() public {
        vm.prank(admin);
        vm.expectRevert(Marketplace.FeeTooHigh.selector);
        new Marketplace(21); // 21% is above the 20% limit
    }

    // ==========================================
    // LIST_TOKEN TESTS
    // ==========================================
    // test_ListTokenSuccess_SpecificApproval()
    // test_ListTokenSuccess_GlobalOperator()
    // test_ListTokenRevert_PriceZero()
    // test_ListTokenRevert_NotTokenOwner()
    // test_ListTokenRevert_NotApproved()
    // test_ListTokenRevert_ZeroAddressCollection()

    /**
     * @notice Tests successful listing when the marketplace is explicitly approved.
     */
    function test_ListTokenSuccess_SpecificApproval() public {
        string memory uri = "../metadata/token_1.json";

        // Alice mints and approves the marketplace
        vm.startPrank(alice);
        uint256 tokenId = collection.mint(uri);
        collection.approve(address(marketplace), tokenId);

        // Expect the ItemListed event
        vm.expectEmit();
        emit ItemListed(address(collection), tokenId, alice, LISTING_PRICE);

        // Alice lists the token
        marketplace.listToken(address(collection), tokenId, LISTING_PRICE);
        vm.stopPrank();

        // Verify the state of the MarketItem
        (address seller, uint256 price, bool isActive) = marketplace
            ._marketItems(address(collection), tokenId);

        assertEq(seller, alice, "Seller should be Alice");
        assertEq(price, LISTING_PRICE, "Price should match the listing price");
        assertEq(isActive, true, "Listing should be active");
    }

    /**
     * @notice Tests successful listing when the marketplace is an operator (ApprovalForAll).
     */
    function test_ListTokenSuccess_GlobalOperator() public {
        string memory uri = "../metadata/token_1.json";

        // Alice mints and sets marketplace as an operator
        vm.startPrank(alice);
        uint256 tokenId = collection.mint(uri);
        collection.setApprovalForAll(address(marketplace), true);

        // Expect the ItemListed event
        vm.expectEmit();
        emit ItemListed(address(collection), tokenId, alice, LISTING_PRICE);

        // Alice lists the token
        marketplace.listToken(address(collection), tokenId, LISTING_PRICE);
        vm.stopPrank();

        // Verify the state of the MarketItem
        (address seller, uint256 price, bool isActive) = marketplace
            ._marketItems(address(collection), tokenId);

        assertEq(seller, alice, "Seller should be Alice");
        assertEq(price, LISTING_PRICE, "Price should match the listing price");
        assertEq(isActive, true, "Listing should be active");
    }

    /**
     * @notice Tests that listing reverts if the price is 0.
     */
    function test_ListTokenRevert_PriceZero() public {
        string memory uri = "../metadata/token_1.json";

        vm.startPrank(alice);
        uint256 tokenId = collection.mint(uri);
        collection.approve(address(marketplace), tokenId);

        // Expect the custom error PriceMustBeAboveZero
        vm.expectRevert(Marketplace.PriceMustBeAboveZero.selector);
        marketplace.listToken(address(collection), tokenId, 0);
        vm.stopPrank();
    }

    /**
     * @notice Tests that listing reverts if the caller does not own the token.
     */
    function test_ListTokenRevert_NotTokenOwner() public {
        string memory uri = "../metadata/token_1.json";

        vm.prank(alice);
        uint256 tokenId = collection.mint(uri);

        // Bob tries to list Alice's token
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(NotTokenOwner.selector, bob, tokenId)
        );
        marketplace.listToken(address(collection), tokenId, LISTING_PRICE);
    }

    /**
     * @notice Tests that listing reverts if the marketplace lacks transfer approval.
     */
    function test_ListTokenRevert_NotApproved() public {
        string memory uri = "../metadata/token_1.json";

        // Alice mints but forgets to approve the marketplace
        vm.prank(alice);
        uint256 tokenId = collection.mint(uri);

        // Alice tries to list
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.MarketplaceNotApproved.selector,
                tokenId
            )
        );
        marketplace.listToken(address(collection), tokenId, LISTING_PRICE);
    }

    /**
     * @notice Tests that listing reverts if the NFT collection address is zero.
     */
    function test_ListTokenRevert_ZeroAddressCollection() public {
        vm.expectRevert(ZeroAddressNotValid.selector);
        marketplace.listToken(address(0), 1, LISTING_PRICE);
    }

    // ==========================================
    // BUY_TOKEN TESTS
    // ==========================================
    // test_BuyTokenSuccess()
    // test_BuyTokenRevert_ZeroAddressCollection()
    // test_BuyTokenRevert_ItemNotAvailable()
    // test_BuyTokenRevert_PriceNotMet()
    // test_BuyTokenRevert_SellerNoLongerOwner()

    /**
     * @notice Tests the successful purchase of a token, including fee splits and state updates.
     */
    function test_BuyTokenSuccess() public {
        // Alice lists a token
        vm.startPrank(alice);
        uint256 tokenId = collection.mint("../metadata/token_1.json");
        collection.approve(address(marketplace), tokenId);
        marketplace.listToken(address(collection), tokenId, LISTING_PRICE);
        vm.stopPrank();

        uint256 aliceInitialBalance = alice.balance;

        // Expect the ItemSold event from marketplace contract.
        // Ignores the Transfer event from collection contract
        vm.expectEmit(true, true, true, true, address(marketplace));
        emit ItemSold(address(collection), tokenId, bob, alice, LISTING_PRICE);

        // Bob buys the token
        vm.prank(bob);
        marketplace.buyToken{value: LISTING_PRICE}(
            address(collection),
            tokenId
        );

        // Verify Ownership
        assertEq(
            collection.ownerOf(tokenId),
            bob,
            "Bob should now own the token"
        );

        // Verify Balances (Fee split)
        uint256 expectedFee = (LISTING_PRICE * FEE_PERCENT) / 100;
        uint256 expectedSellerAmount = LISTING_PRICE - expectedFee;

        assertEq(
            alice.balance,
            aliceInitialBalance + expectedSellerAmount,
            "Alice should receive the price minus the fee"
        );
        assertEq(
            address(marketplace).balance,
            expectedFee,
            "Marketplace should hold the fee"
        );

        // Verify listing is inactive
        (, , bool isActive) = marketplace._marketItems(
            address(collection),
            tokenId
        );
        assertEq(
            isActive,
            false,
            "Listing should be marked as inactive after sale"
        );
    }

    /**
     * @notice Tests that buying reverts if the NFT collection address is zero.
     */
    function test_BuyTokenRevert_ZeroAddressCollection() public {
        vm.prank(bob);
        vm.expectRevert(ZeroAddressNotValid.selector);
        marketplace.buyToken{value: LISTING_PRICE}(address(0), 1);
    }

    /**
     * @notice Tests that buying reverts if the item is not listed (or already sold).
     */
    function test_BuyTokenRevert_ItemNotAvailable() public {
        uint256 nonExistentTokenId = 99;

        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.ItemNotAvailable.selector,
                nonExistentTokenId
            )
        );
        marketplace.buyToken{value: LISTING_PRICE}(
            address(collection),
            nonExistentTokenId
        );
    }

    /**
     * @notice Tests that buying reverts if the buyer does not send the exact price.
     */
    function test_BuyTokenRevert_PriceNotMet() public {
        // Alice lists the token
        vm.startPrank(alice);
        uint256 tokenId = collection.mint("../metadata/token_1.json");
        collection.approve(address(marketplace), tokenId);
        marketplace.listToken(address(collection), tokenId, LISTING_PRICE);
        vm.stopPrank();

        uint256 wrongPrice = 0.5 ether;

        // Bob tries to pay less
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.PriceNotMet.selector,
                wrongPrice,
                LISTING_PRICE
            )
        );
        marketplace.buyToken{value: wrongPrice}(address(collection), tokenId);
    }

    /**
     * @notice Tests that buying reverts if the seller has transferred the token elsewhere (Zombie Listing).
     */
    function test_BuyTokenRevert_SellerNoLongerOwner() public {
        // Alice lists the token
        vm.startPrank(alice);
        uint256 tokenId = collection.mint("../metadata/token_1.json");
        collection.approve(address(marketplace), tokenId);
        marketplace.listToken(address(collection), tokenId, LISTING_PRICE);

        // Alice transfers the token to Charlie directly, bypassing the marketplace
        collection.transferFrom(alice, charlie, tokenId);
        vm.stopPrank();

        // Bob tries to buy the zombie listing
        vm.prank(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.SellerNoLongerOwner.selector,
                tokenId
            )
        );
        marketplace.buyToken{value: LISTING_PRICE}(
            address(collection),
            tokenId
        );
    }

    // ==========================================
    // CANCEL_LISTING TESTS
    // ==========================================
    // test_CancelListingSuccess_BySeller()
    // test_CancelListingSuccess_ZombieListing()
    // test_CancelListingRevert_ZeroAddressCollection()
    // test_CancelListingRevert_NotAvailable()
    // test_CancelListingRevert_NotSeller()

    /**
     * @notice Tests successful cancellation by the actual seller.
     */
    function test_CancelListingSuccess_BySeller() public {
        // Alice lists the token
        vm.startPrank(alice);
        uint256 tokenId = collection.mint("../metadata/token_1.json");
        collection.approve(address(marketplace), tokenId);
        marketplace.listToken(address(collection), tokenId, LISTING_PRICE);

        // Expect the ItemCanceled event
        vm.expectEmit();
        emit ItemCanceled(address(collection), tokenId, alice);

        // Alice cancels her own listing
        marketplace.cancelListing(address(collection), tokenId);
        vm.stopPrank();

        // Verify it is inactive
        (, , bool isActive) = marketplace._marketItems(
            address(collection),
            tokenId
        );
        assertEq(
            isActive,
            false,
            "Listing should be marked as inactive after cancel"
        );
    }

    /**
     * @notice Tests the Decentralized Garbage Collection feature (anyone can cancel a zombie listing).
     */
    function test_CancelListingSuccess_ZombieListing() public {
        // Alice lists the token
        vm.startPrank(alice);
        uint256 tokenId = collection.mint("../metadata/token_1.json");
        collection.approve(address(marketplace), tokenId);
        marketplace.listToken(address(collection), tokenId, LISTING_PRICE);

        // Alice transfers it to Charlie
        collection.transferFrom(alice, charlie, tokenId);
        vm.stopPrank();

        // Bob (who is not the seller) cleans up the zombie listing
        vm.prank(bob);
        marketplace.cancelListing(address(collection), tokenId);

        // Verify it is inactive
        (, , bool isActive) = marketplace._marketItems(
            address(collection),
            tokenId
        );
        assertEq(
            isActive,
            false,
            "Zombie listing should be successfully canceled"
        );
    }

    /**
     * @notice Tests that cancellation reverts if the NFT collection address is zero.
     */
    function test_CancelListingRevert_ZeroAddressCollection() public {
        vm.prank(alice);
        vm.expectRevert(ZeroAddressNotValid.selector);
        marketplace.cancelListing(address(0), 1);
    }

    /**
     * @notice Tests that cancellation reverts if the listing is not active.
     */
    function test_CancelListingRevert_NotAvailable() public {
        uint256 tokenId = 99; // Non-existent/unlisted

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Marketplace.ItemNotAvailable.selector,
                tokenId
            )
        );
        marketplace.cancelListing(address(collection), tokenId);
    }

    /**
     * @notice Tests that cancellation reverts if a random user tries to cancel an active, valid listing.
     */
    function test_CancelListingRevert_NotSeller() public {
        // Alice lists the token
        vm.startPrank(alice);
        uint256 tokenId = collection.mint("../metadata/token_1.json");
        collection.approve(address(marketplace), tokenId);
        marketplace.listToken(address(collection), tokenId, LISTING_PRICE);
        vm.stopPrank();

        // Bob maliciously tries to cancel Alice's valid listing
        vm.prank(bob);
        vm.expectRevert(Marketplace.NotSeller.selector);
        marketplace.cancelListing(address(collection), tokenId);
    }

    // ==========================================
    // WITHDRAW_FEES TESTS
    // ==========================================
    // test_WithdrawFeesSuccess()
    // test_WithdrawFeesRevert_OnlyFeeAccount()

    /**
     * @notice Tests successful withdrawal of accumulated fees by the admin.
     */
    function test_WithdrawFeesSuccess() public {
        // Generate some fees by completing a sale
        vm.startPrank(alice);
        uint256 tokenId = collection.mint("../metadata/token_1.json");
        collection.approve(address(marketplace), tokenId);
        marketplace.listToken(address(collection), tokenId, LISTING_PRICE);
        vm.stopPrank();

        vm.prank(bob);
        marketplace.buyToken{value: LISTING_PRICE}(
            address(collection),
            tokenId
        );

        uint256 marketplaceBalance = address(marketplace).balance;
        uint256 adminInitialBalance = admin.balance;

        // Ensure there is something to withdraw
        assertTrue(
            marketplaceBalance > 0,
            "Marketplace should have collected fees"
        );

        // Admin withdraws
        vm.prank(admin);
        marketplace.withdrawFees();

        // Assert
        assertEq(
            address(marketplace).balance,
            0,
            "Marketplace balance should be drained"
        );
        assertEq(
            admin.balance,
            adminInitialBalance + marketplaceBalance,
            "Admin should receive the accumulated fees"
        );
    }

    /**
     * @notice Tests that fee withdrawal reverts if called by anyone other than the admin.
     */
    function test_WithdrawFeesRevert_OnlyFeeAccount() public {
        // Alice tries to steal the fees
        vm.prank(alice);
        vm.expectRevert(Marketplace.OnlyFeeAccount.selector);
        marketplace.withdrawFees();
    }
}
