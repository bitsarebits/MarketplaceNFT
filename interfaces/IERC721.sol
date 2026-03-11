// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/**
 * @title Required interface of an ERC721 contract.
 */
interface IERC721 {
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

    /**
     * @dev Emitted when `owner` enables or disables `authorized_operator` to manage all of its assets.
     */
    event ApprovalForAll(
        address indexed owner,
        address indexed authorizedOperator,
        bool authorized
    );

    /**
     * @notice Returns the owner of the `tokenId` token.
     * @param tokenId The ID of the token to query
     * @return owner The address of the token owner
     */
    function ownerOf(uint256 tokenId) external view returns (address owner);

    /**
     * @notice Returns the account approved for `tokenId` token.
     * @param tokenId The ID of the token to query
     * @return operator The address approved to transfer the token
     */
    function getApproved(
        uint256 tokenId
    ) external view returns (address operator);

    /**
     * @notice Gives permission to `to` to transfer `tokenId` token.
     * @dev Approving the zero address clears previous approvals.
     * Only the token owner can call this function.
     * @param to The address to approve (use address(0) to revoke)
     * @param tokenId The token ID to approve
     */
    function approve(address to, uint256 tokenId) external;

    /**
     * @notice Transfers `tokenId` token from `from` to `to`.
     * @param from The current owner of the token
     * @param to The receiving address
     * @param tokenId The ID of the token to transfer
     */
    function transferFrom(address from, address to, uint256 tokenId) external;

    /**
     * @notice Enables or disables approval for a third party (operator) to manage all of the caller's assets
     * @dev The operator can then call transferFrom for any token owned by the caller.
     * @param operator Address to add to the set of authorized operators
     * @param approved True if the operator is approved, false to revoke approval
     */
    function setApprovalForAll(address operator, bool approved) external;

    /**
     * @notice Query if an address is an authorized operator for another address
     * @param owner The address that owns the tokens
     * @param operator The address that acts on behalf of the owner
     * @return True if `operator` is an approved operator for `owner`, false otherwise
     */
    function isApprovedForAll(
        address owner,
        address operator
    ) external view returns (bool);

    /**
     * @notice Count all NFTs assigned to an owner
     * @param owner Address for whom to query the balance
     * @return The number of NFTs owned by `owner`
     */
    function balanceOf(address owner) external view returns (uint256);

    /**
     * @notice Safely transfers `tokenId` token from `from` to `to`
     * @dev Implementation should ideally check if 'to' is a contract and calls onERC721Received
     * @param from The current owner of the token
     * @param to The receiving address
     * @param tokenId The ID of the token to transfer
     */
    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId
    ) external;

    /**
     * @notice Query if a contract implements an interface
     * @param interfaceId The interface identifier, as specified in ERC-165
     * @return `true` if the contract implements `interfaceId`
     */
    function supportsInterface(bytes4 interfaceId) external view returns (bool);
}
