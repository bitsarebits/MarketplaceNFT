// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../interfaces/IERC721.sol";
import "../errors/SharedErrors.sol";
import "./SecurityBase.sol";
import "./ReentrancyGuard.sol";

/**
 * @title Core NFT Marketplace
 * @dev Handles the listing, buying, and canceling of ERC-721 token sales.
 */
contract Marketplace is SecurityBase, ReentrancyGuard {
    /// @notice The address that receives marketplace fees (Admin)
    address payable public immutable _feeAccount;

    /// @notice The fee percentage taken by the marketplace on each sale
    uint256 public _feePercent;

    /**
     * @dev Represents a single NFT listed for sale on the marketplace
     * @param seller The address of the user selling the NFT
     * @param price The price in wei at which the NFT is listed
     * @param isActive Boolean indicating if the listing is still open and available
     */
    struct MarketItem {
        address payable seller;
        uint256 price;
        bool isActive;
    }

    /// @notice Maps an NFT collection address and token ID to its respective MarketItem
    mapping(address nftCollection => mapping(uint256 tokenId => MarketItem item))
        public _marketItems;

    /**
     * @notice Emitted when a new NFT is listed on the marketplace
     * @param nftCollection The address of the ERC-721 contract
     * @param tokenId The ID of the listed token
     * @param seller The address of the user who listed the token
     * @param price The listing price in wei
     */
    event ItemListed(
        address indexed nftCollection,
        uint256 indexed tokenId,
        address indexed seller,
        uint256 price
    );

    /**
     * @notice Emitted when an NFT is successfully purchased
     * @param nftCollection The address of the ERC-721 contract
     * @param tokenId The ID of the purchased token
     * @param buyer The address of the user who bought the token
     * @param seller The address of the user who sold the token
     * @param price The final sale price in wei
     */
    event ItemSold(
        address indexed nftCollection,
        uint256 indexed tokenId,
        address indexed buyer,
        address seller,
        uint256 price
    );

    /**
     * @notice Emitted when a listing is canceled by the seller
     * @param nftCollection The address of the ERC-721 contract
     * @param tokenId The ID of the token whose listing was canceled
     * @param seller The address of the user who canceled the listing
     */
    event ItemCanceled(
        address indexed nftCollection,
        uint256 indexed tokenId,
        address indexed seller
    );

    /// @notice Custom error thrown when the listing price is zero
    error PriceMustBeAboveZero();

    /// @notice Custom error thrown when the marketplace lacks approval to transfer the token
    error MarketplaceNotApproved(address collection, uint256 tokenId);

    /// @notice Custom error thrown when trying to buy an unlisted or already sold item
    error ItemNotAvailable(address collection, uint256 tokenId);

    /// @notice Custom error thrown when the msg.value does not exactly match the item price
    error PriceNotMet(
        address collection,
        uint256 tokenId,
        uint256 sent,
        uint256 required
    );

    /// @notice Custom error thrown when an unauthorized user attempts to withdraw fees
    error OnlyFeeAccount();

    /// @notice Custom error thrown when someone other than the seller tries to modify a listing
    error NotSeller();

    /// @notice Custom error thrown when the initial fee percentage exceeds the maximum allowed
    error FeeTooHigh();

    /// @notice Custom error thrown when trying to interact with a listing where the seller no longer owns the NFT
    error SellerNoLongerOwner(address collection, uint256 tokenId);

    /**
     * @notice Initializes the marketplace contract
     * @dev The deployer of the contract becomes the fee recipient
     * @param feePercent The percentage taken by the marketplace on each sale
     */
    constructor(uint256 feePercent) {
        // Fee limit
        if (feePercent > 20) {
            revert FeeTooHigh();
        }

        _feeAccount = payable(msg.sender);
        _feePercent = feePercent;
    }

    /**
     * @notice Lists an NFT for sale on the marketplace
     * @param nftCollection The address of the NFT smart contract
     * @param tokenId The ID of the token to be listed
     * @param price The sale price in wei
     */
    function listToken(
        address nftCollection,
        uint256 tokenId,
        uint256 price
    ) external nonZeroAddress(nftCollection) {
        // Prevent listing for free
        if (!(price > 0)) {
            revert PriceMustBeAboveZero();
        }

        // Ensure the caller actually owns the token they are trying to sell
        if (IERC721(nftCollection).ownerOf(tokenId) != msg.sender) {
            revert NotTokenOwner(msg.sender, nftCollection, tokenId);
        }

        // Ensure the marketplace is approved to move the token (either specifically or globally)
        bool isApproved = IERC721(nftCollection).getApproved(tokenId) ==
            address(this);
        bool isOperator = IERC721(nftCollection).isApprovedForAll(
            msg.sender,
            address(this)
        );

        if (!isApproved && !isOperator) {
            revert MarketplaceNotApproved(nftCollection, tokenId);
        }

        // Create the listing in storage
        _marketItems[nftCollection][tokenId] = MarketItem({
            seller: payable(msg.sender),
            price: price,
            isActive: true
        });

        emit ItemListed(nftCollection, tokenId, msg.sender, price);
    }

    /**
     * @notice Purchases a listed NFT
     * @dev Protected by the nonReentrant modifier and implements the Checks-Effects-Interactions pattern.
     * @param nftCollection The address of the NFT contract
     * @param tokenId The ID of the token to buy
     */
    function buyToken(
        address nftCollection,
        uint256 tokenId
    ) external payable nonReentrant nonZeroAddress(nftCollection) {
        // CHECKS
        MarketItem memory item = _marketItems[nftCollection][tokenId];

        // Ensure the item is actually for sale
        if (!item.isActive) {
            revert ItemNotAvailable(nftCollection, tokenId);
        }

        // Ensure the buyer sent the exact correct amount of wei
        if (msg.value != item.price) {
            revert PriceNotMet(nftCollection, tokenId, msg.value, item.price);
        }

        // Ensure the seller still owns the token
        if (IERC721(nftCollection).ownerOf(tokenId) != item.seller) {
            revert SellerNoLongerOwner(nftCollection, tokenId);
        }

        // EFFECTS
        // Mark the item as sold/inactive first to prevent reentrancy loops
        _marketItems[nftCollection][tokenId].isActive = false;

        // Calculate fee splits
        uint256 feeAmount = (item.price * _feePercent) / 100;
        uint256 sellerAmount = item.price - feeAmount;

        // INTERACTIONS
        /// @dev Using .transfer() to enforce the 2300 gas limit.
        // This strictly prevents both Reentrancy and Out-of-Gas/Griefing Denial of Service attacks.
        item.seller.transfer(sellerAmount);

        // Transfer the NFT from the seller to the buyer
        IERC721(nftCollection).transferFrom(item.seller, msg.sender, tokenId);

        emit ItemSold(
            nftCollection,
            tokenId,
            msg.sender,
            item.seller,
            item.price
        );
    }

    /**
     * @notice Cancels an active listing
     * @param nftCollection The address of the NFT contract
     * @param tokenId The ID of the token listing to cancel
     */
    function cancelListing(
        address nftCollection,
        uint256 tokenId
    ) external nonZeroAddress(nftCollection) {
        // Load the item into memory once to save gas on multiple reads
        MarketItem memory item = _marketItems[nftCollection][tokenId];

        // Ensure the item is currently active on the market
        if (!item.isActive) {
            revert ItemNotAvailable(nftCollection, tokenId);
        }

        // Read the actual owner
        address currentOwner = IERC721(nftCollection).ownerOf(tokenId);

        // Only the seller can cancel the listing.
        // Cancel allowed also if the actual owner is not the seller (Zombie Listings)
        if (msg.sender != item.seller && currentOwner == item.seller) {
            revert NotSeller();
        }

        // Mark the item as inactive.
        _marketItems[nftCollection][tokenId].isActive = false;

        // Emit the cancellation event.
        emit ItemCanceled(nftCollection, tokenId, msg.sender);
    }

    /**
     * @notice Allows the fee account to withdraw accumulated marketplace fees
     * @dev Implements the Pull Pattern for admin revenue
     */
    function withdrawFees() external nonReentrant {
        // Only the designated admin can withdraw fees
        if (msg.sender != _feeAccount) {
            revert OnlyFeeAccount();
        }

        uint256 balance = address(this).balance;

        /// @dev Using .transfer() to prevent gas exhaustion attacks.
        _feeAccount.transfer(balance);
    }
}
