// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../interfaces/IERC721.sol";
import "../errors/SharedErrors.sol";

/**
 * @title Core ERC-721 NFT Collection
 * @dev This contract handles the minting and ownership tracking of NFTs
 */
contract Collection is IERC721 {
    // Counter to keep track of the most recently minted token ID
    uint256 private _nextTokenId;

    // Mapping from token ID to the owner's address
    mapping(uint256 tokenId => address owner) private _owners;

    // Mapping from token ID to its specific metadata URI (link to a JSON file)
    mapping(uint256 tokenId => string tokenURI) private _tokenURIs;

    // Mapping from token ID to the approved address (only one for ERC-721).
    mapping(uint256 tokenId => address approved) private _tokenApprovals;

    /// @notice Custom error thrown when querying a non-existent token
    error InvalidTokenId(uint256 tokenId);

    /**
     * @dev Modifier to check if a token ID exists.
     * Reverts with InvalidTokenId if the token is 0 or exceeds the minted supply.
     */
    modifier validTokenId(uint256 tokenId) {
        if (tokenId == 0 || tokenId > _nextTokenId) {
            revert InvalidTokenId(tokenId);
        }
        _;
    }

    /// @inheritdoc IERC721
    function ownerOf(
        uint256 tokenId
    ) external view validTokenId(tokenId) returns (address) {
        return _owners[tokenId];
    }

    /// @inheritdoc IERC721
    function getApproved(
        uint256 tokenId
    ) external view validTokenId(tokenId) returns (address) {
        return _tokenApprovals[tokenId];
    }

    /**
     * @notice Mints a new NFT and assigns it to the caller (msg.sender)
     * @dev Uses pre-increment to start token IDs from 1. Uses calldata for gas optimization.
     * @param uri The Uniform Resource Identifier pointing to the token's metadata JSON
     * @return The newly minted token ID
     */
    function mint(string calldata uri) external returns (uint256) {
        // Read and increment the counter
        uint256 id = ++_nextTokenId;

        // Assign ownership to the address calling the function
        _owners[id] = msg.sender;

        // Store the metadata URI for this specific token
        _tokenURIs[id] = uri;

        // Emit the Transfer event (from address(0) indicates a mint)
        emit Transfer(address(0), msg.sender, id);

        return id;
    }

    /**
     * @notice Returns the metadata URI for a given token
     * @param tokenId The ID of the token to query
     * @return The string URI pointing to the token's JSON metadata
     */
    function tokenURI(
        uint256 tokenId
    ) external view validTokenId(tokenId) returns (string memory) {
        return _tokenURIs[tokenId];
    }

    /// @inheritdoc IERC721
    function approve(
        address to,
        uint256 tokenId
    ) external validTokenId(tokenId) {
        // Cache the owner address in memory to save gas reading from storage twice
        address owner = _owners[tokenId];

        // Check if the caller is the actual owner
        if (owner != msg.sender) {
            revert NotTokenOwner(msg.sender, tokenId);
        }

        // Assign the new approved address
        _tokenApprovals[tokenId] = to;

        // Emit the standard event
        emit Approval(owner, to, tokenId);
    }

    /// @inheritdoc IERC721
    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external validTokenId(tokenId) {
        address owner = _owners[tokenId];

        // Verify that the 'from' address is the actual current owner
        if (owner != from) {
            revert NotTokenOwner(from, tokenId);
        }

        // Verify that the caller is either the owner or the approved marketplace
        address approved = _tokenApprovals[tokenId];
        if (msg.sender != owner && msg.sender != approved) {
            revert NotTokenOwner(msg.sender, tokenId); // Usiamo lo stesso errore per semplicità
        }

        // Clear previous approvals to prevent unauthorized transfers after the sale
        _tokenApprovals[tokenId] = address(0);

        // Reassign ownership to the buyer
        _owners[tokenId] = to;

        // Emit the standard ERC-721 Transfer event
        emit Transfer(from, to, tokenId);
    }
}
