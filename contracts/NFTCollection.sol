// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/**
 * @title Core ERC-721 NFT Collection
 * @dev This contract handles the minting and ownership tracking of NFTs
 */
contract NFTCollection {
    // Counter to keep track of the most recently minted token ID
    uint256 private _nextTokenId;

    // Mapping from token ID to the owner's address
    mapping(uint256 _id => address _owner) private _owners;

    // Mapping from token ID to its specific metadata URI (link to a JSON file)
    mapping(uint256 _id => string _tokenURI) private _tokenURIs;

    // Mapping from token ID to the approved address (only one for ERC-721).
    mapping(uint256 _id => address _approved) private _tokenApprovals;

    /**
     * @dev Emitted when `tokenId` token is transferred from `from` address to `to` address.
     * In the case of minting, `from` is the zero address.
     */
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    /**
     * @dev Emitted when `owner` enables `approved` to manage the `tokenId` token.
     */
    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    /// @notice Custom error thrown when querying a non-existent token
    error InvalidTokenId(uint256 tokenId);

    /// @notice Custom error thrown when a caller tries to approve a token they do not own
    error NotTokenOwner(address caller, uint256 tokenId);

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

    /**
     * @notice Returns the owner of the `tokenId` token.
     * @param tokenId The ID of the token to query
     * @return The address of the token owner
     */
    function ownerOf(
        uint256 tokenId
    ) external view validTokenId(tokenId) returns (address) {
        return _owners[tokenId];
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

    /**
     * @notice Gives permission to `to` to transfer `tokenId` token.
     * @dev Approving the zero address clears previous approvals.
     * Only the token owner can call this function.
     * @param to The address to approve (use address(0) to revoke)
     * @param tokenId The token ID to approve
     */
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
}
