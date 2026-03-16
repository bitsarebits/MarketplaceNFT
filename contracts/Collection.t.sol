// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {Collection} from "../contracts/Collection.sol";
import "../errors/SharedErrors.sol";
import "../interfaces/IERC721.sol";

contract CollectionTest is Test {
    Collection public collection;

    // Fake addresses
    address public alice = makeAddr("alice");
    address public bob = makeAddr("bob");
    address public charlie = makeAddr("charlie");

    // IERC721 event copy
    event Transfer(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId
    );

    event Approval(
        address indexed owner,
        address indexed approved,
        uint256 indexed tokenId
    );

    event ApprovalForAll(
        address indexed owner,
        address indexed authorizedOperator,
        bool authorized
    );

    function setUp() public {
        collection = new Collection();
    }

    // ==========================================
    // OWNER_OF TESTS
    // ==========================================
    // test_OwnerOfSuccess()
    // test_OwnerOfRevert_InvalidTokenId()

    /**
     * @notice Tests OwnerOf function.
     */
    function test_OwnerOfSuccess() public {
        // Setup the initial data
        string memory uri = "../metadata/token_1.json";

        // Mint a token as Alice
        vm.prank(alice);
        uint256 tokenId = collection.mint(uri);

        assertEq(
            collection.ownerOf(tokenId),
            alice,
            "The owner should be Alice"
        );
    }

    /**
     * @notice Tests that OwnerOf reverts if the token ID does not exist.
     */
    function test_OwnerOfRevert_InvalidTokenId() public {
        uint256 nonExistentTokenId = 5;

        // Expect the custom error InvalidTokenId (from validTokenId modifier)
        vm.expectRevert(
            abi.encodeWithSelector(
                Collection.InvalidTokenId.selector,
                nonExistentTokenId
            )
        );
        collection.ownerOf(nonExistentTokenId);
    }

    // ==========================================
    // GET_APPROVED TESTS
    // ==========================================
    // test_GetApprovedSuccess()
    // test_GetApprovedSuccess_NoApproval()
    // test_GetApprovedRevert_InvalidTokenId()

    /**
     * @notice Tests GetApproved function.
     */
    function test_GetApprovedSuccess() public {
        // Setup the initial data
        string memory uri = "../metadata/token_1.json";

        // Mint a token as Alice and approve Bob
        vm.startPrank(alice);
        uint256 tokenId = collection.mint(uri);
        collection.approve(bob, tokenId);
        vm.stopPrank();

        assertEq(
            collection.getApproved(tokenId),
            bob,
            "The Authorized address should be Bob"
        );
    }

    /**
     * @notice Tests the GetApproved when approve function is not called,
     * so no address (except the owner) is authorized.
     */
    function test_GetApprovedSuccess_NoApproval() public {
        string memory uri = "../metadata/token_1.json";

        vm.prank(alice);
        uint256 tokenId = collection.mint(uri);

        // Verify the state updates
        assertEq(
            collection.getApproved(tokenId),
            address(0),
            "Freshly minted token should have no approved address"
        );
    }

    /**
     * @notice Tests that GetApproved reverts if the token ID does not exist.
     */
    function test_GetApprovedRevert_InvalidTokenId() public {
        uint256 nonExistentTokenId = 5;

        // Expect the custom error InvalidTokenId (from validTokenId modifier)
        vm.expectRevert(
            abi.encodeWithSelector(
                Collection.InvalidTokenId.selector,
                nonExistentTokenId
            )
        );
        collection.getApproved(nonExistentTokenId);
    }

    // ==========================================
    // TOKEN_URI TESTS
    // ==========================================
    // test_tokenURISuccess()
    // test_tokenURIRevert_InvalidToken()

    /**
     * @notice Tests the tokenURI function.
     */
    function test_tokenURISuccess() public {
        // Setup the token's initial data
        string memory uri = "../metadata/token_1.json";

        // Mint a token as Alice
        vm.prank(alice);
        uint256 tokenId = collection.mint(uri);

        assertEq(
            collection.tokenURI(tokenId),
            uri,
            "The stored token URI should match the provided URI"
        );
    }

    /**
     * @notice Tests that tokenURI() reverts if the token ID does not exist.
     */
    function test_TokenURIRevert_InvalidTokenId() public {
        uint256 nonExistentTokenId = 5;

        // Expect the custom error InvalidTokenId (from validTokenId modifier)
        vm.expectRevert(
            abi.encodeWithSelector(
                Collection.InvalidTokenId.selector,
                nonExistentTokenId
            )
        );
        collection.tokenURI(nonExistentTokenId);
    }

    // ==========================================
    // BALANCE_OF TESTS
    // ==========================================
    // test_BalanceOfSuccess()
    // test_BalanceOfRevert_ZeroAddress()

    /**
     * @notice Tests the balanceOf function to ensure it correctly reports token counts.
     */
    function test_BalanceOfSuccess() public {
        // Initial balance should be 0
        assertEq(
            collection.balanceOf(alice),
            0,
            "Alice's initial balance should be 0"
        );

        // Mint a token as Alice
        string memory uri = "../metadata/token_1.json";
        vm.prank(alice);
        collection.mint(uri);

        // Balance should increase to 1
        assertEq(
            collection.balanceOf(alice),
            1,
            "Alice's balance should be 1 after one mint"
        );

        // Mint another token as Alice
        vm.prank(alice);
        collection.mint(uri);

        // Balance should increase to 2
        assertEq(
            collection.balanceOf(alice),
            2,
            "Alice's balance should be 2 after two mints"
        );

        // Bob's balance should remain 0
        assertEq(collection.balanceOf(bob), 0, "Bob's balance should be 0");
    }

    /**
     * @notice Tests that balanceOf reverts when querying the zero address.
     */
    function test_BalanceOfRevert_ZeroAddress() public {
        // Expect custom error ZeroAddressNotValid (from nonZeroAddress modifier)
        vm.expectRevert(ZeroAddressNotValid.selector);

        // Query balance of address(0)
        collection.balanceOf(address(0));
    }

    // ==========================================
    // SUPPORTS_INTERFACE TESTS
    // ==========================================
    // test_SupportsInterfaceSuccess()

    /**
     * @notice Tests the supportsInterface function against standard ERC165 and ERC721 interface IDs.
     */
    function test_SupportsInterfaceSuccess() public view {
        // Check ERC721 interface ID (0x80ac58cd)
        assertEq(
            collection.supportsInterface(0x80ac58cd),
            true,
            "The contract should support the ERC721 interface"
        );

        // Check ERC165 interface ID (0x01ffc9a7)
        assertEq(
            collection.supportsInterface(0x01ffc9a7),
            true,
            "The contract should support the ERC165 interface"
        );

        // Check a random unsupported interface ID
        assertEq(
            collection.supportsInterface(0xffffafff),
            false,
            "The contract should not support a random interface ID (0xffffafff)"
        );
    }

    // ==========================================
    // MINTING TESTS
    // ==========================================
    // test_MintSuccess_Single()
    // test_MintSuccess_Multiple()

    /**
     * @notice Tests the successful minting of a single NFT
     */
    function test_MintSuccess_Single() public {
        // Setup the initial data
        string memory uri = "../metadata/token_1.json";

        // Expect the Transfer event
        vm.expectEmit();
        // We expect a Transfer from address(0) to Alice for token ID 1
        emit Transfer(address(0), alice, 1);

        // Perform the action as Alice
        vm.startPrank(alice);
        uint256 tokenId = collection.mint(uri);
        vm.stopPrank();

        // Verify the state updates
        assertEq(tokenId, 1, "The first minted token ID should be exactly 1");

        assertEq(
            collection.ownerOf(tokenId),
            alice,
            "Alice should be the recorded owner of the token"
        );

        assertEq(
            collection.balanceOf(alice),
            1,
            "Alice's token balance should increase to 1"
        );

        assertEq(
            collection.tokenURI(tokenId),
            uri,
            "The stored token URI should match the provided local path"
        );
    }

    /**
     * @notice Tests the state progression when minting multiple NFTs
     */
    function test_MintSuccess_Multiple() public {
        // First mint
        string memory uri1 = "../metadata/token_1.json";

        vm.expectEmit();
        emit Transfer(address(0), alice, 1);

        vm.startPrank(alice);
        collection.mint(uri1);
        vm.stopPrank();

        // Second mint
        // Arrange data for the second token
        string memory uri2 = "../metadata/token_2.json";

        // Expect the Transfer event for token ID 2
        vm.expectEmit();
        emit Transfer(address(0), alice, 2);

        // Alice mints a second token
        vm.startPrank(alice);
        uint256 secondTokenId = collection.mint(uri2);
        vm.stopPrank();

        // Verify the counter incremented correctly and state is updated
        assertEq(
            secondTokenId,
            2,
            "The second minted token ID should be exactly 2"
        );

        assertEq(
            collection.ownerOf(secondTokenId),
            alice,
            "Alice should be the recorded owner of the second token"
        );

        assertEq(
            collection.balanceOf(alice),
            2,
            "Alice's overall token balance should increase to 2"
        );

        assertEq(
            collection.tokenURI(secondTokenId),
            uri2,
            "The stored token URI should match the second local path"
        );
    }

    // ==========================================
    // APPROVE TESTS
    // ==========================================
    // test_ApproveSuccess()
    // test_ApproveSuccess_ByOperator()
    // test_ApproveRevert_InvalidTokenId()
    // test_ApproveRevert_NotTokenOwner()
    // test_ApproveRevert_ApprovalToCurrentOwner()

    /**
     * @notice Tests the successful approval of an operator for a specific token,
     * verifying the state update and the emitted event.
     */
    function test_ApproveSuccess() public {
        // Setup the token's initial data
        string memory uri = "../metadata/token_1.json";

        // Mint a token as Alice and approve Bob
        vm.startPrank(alice);
        uint256 tokenId = collection.mint(uri);

        // Expect the Approval event
        vm.expectEmit();
        // We expect a Approval from Alice to Bob for token ID 1
        emit Approval(alice, bob, tokenId);

        collection.approve(bob, tokenId);
        vm.stopPrank();

        assertEq(
            collection.getApproved(tokenId),
            bob,
            "The approved address for the token should be Bob"
        );

        assertEq(
            collection.ownerOf(tokenId),
            alice,
            "Alice should still be the owner"
        );
    }

    /**
     * @notice Tests that approve() reverts if the token ID does not exist.
     */
    function test_ApproveRevert_InvalidTokenId() public {
        uint256 nonExistentTokenId = 5;

        // Expect the custom error InvalidTokenId (from validTokenId modifier)
        vm.expectRevert(
            abi.encodeWithSelector(
                Collection.InvalidTokenId.selector,
                nonExistentTokenId
            )
        );
        collection.approve(alice, nonExistentTokenId);
    }

    /**
     * @notice Tests approve when called by an approved operator (ApprovalForAll).
     */
    function test_ApproveSuccess_ByOperator() public {
        string memory uri = "../metadata/token_1.json";

        // Alice mints a token and sets Bob as a global operator
        vm.startPrank(alice);
        uint256 tokenId = collection.mint(uri);
        collection.setApprovalForAll(bob, true);
        vm.stopPrank();

        // Expect the Approval event (Owner is Alice, Approved is Charlie)
        vm.expectEmit();
        emit Approval(alice, charlie, tokenId);

        // Bob (the operator) approves Charlie for Alice's token
        vm.prank(bob);
        collection.approve(charlie, tokenId);

        // Verify the state updates
        assertEq(
            collection.getApproved(tokenId),
            charlie,
            "The approved address should be Charlie"
        );
        assertEq(
            collection.ownerOf(tokenId),
            alice,
            "Alice should still be the owner"
        );
    }

    /**
     * @notice Tests that Approve() reverts if the caller is not the owner
     * nor an approved operator.
     */
    function test_ApproveRevert_NotTokenOwner() public {
        // Setup the token's initial data
        string memory uri = "../metadata/token_1.json";

        // Mint a token as Alice
        vm.prank(alice);
        uint256 tokenId = collection.mint(uri);

        // Expect the revert with custom error NotTokenOwner
        vm.expectRevert(
            abi.encodeWithSelector(
                NotTokenOwner.selector,
                bob,
                address(collection),
                tokenId
            )
        );

        // Try to approve Charlie for Alice's token as Bob
        vm.prank(bob);
        collection.approve(charlie, tokenId);
    }

    /**
     * @notice Tests that approve reverts if the owner tries to approve themselves.
     */
    function test_ApproveRevert_ApprovalToCurrentOwner() public {
        string memory uri = "../metadata/token_1.json";

        // Mint a token as Alice
        vm.prank(alice);
        uint256 tokenId = collection.mint(uri);

        // Expect custom error ApprovalToCurrentOwner
        vm.expectRevert(Collection.ApprovalToCurrentOwner.selector);

        // Alice tries to approve herself
        vm.prank(alice);
        collection.approve(alice, tokenId);
    }

    // ==========================================
    // TRANSFER_FROM TESTS
    // ==========================================
    // test_TransferFromSuccess_ByOwner()
    // test_TransferFromSuccess_ByApproved()
    // test_TransferFromSuccess_ByOperator()
    // test_TransferFromRevert_NotTokenOwner()
    // test_TransferFromRevert_WrongFromAddress()
    // test_TransferFromRevert_ToZeroAddress()
    // test_TransferFromRevert_InvalidTokenId()

    /**
     * @notice Tests the successful transfer of a token from one user to another,
     * verifying balance updates and the clearing of previous approvals.
     */
    function test_TransferFromSuccess_ByOwner() public {
        // Setup the token's initial data
        string memory uri = "../metadata/token_1.json";

        // Mint a token as Alice and approve a fake operator (0x99)
        vm.startPrank(alice);
        uint256 tokenId = collection.mint(uri);
        collection.approve(address(99), tokenId);
        vm.stopPrank();

        // Expect the Transfer event
        vm.expectEmit();
        // We expect a Transfer from Alice to Bob for token ID 1
        emit Transfer(alice, bob, tokenId);

        // Transfer the token to Bob as Alice
        vm.prank(alice);
        collection.transferFrom(alice, bob, tokenId);

        // Verify the state updates
        assertEq(
            collection.ownerOf(tokenId),
            bob,
            "Bob should be the new owner of the token"
        );
        assertEq(
            collection.balanceOf(alice),
            0,
            "Alice's token balance should decrease to 0"
        );
        assertEq(
            collection.balanceOf(bob),
            1,
            "Bob's token balance should increase to 1"
        );

        assertEq(
            collection.tokenURI(tokenId),
            uri,
            "Token URI should not change"
        );

        // Check that the approved operator get initialized again to address(0)
        assertEq(
            collection.getApproved(tokenId),
            address(0),
            "Previous approvals must be cleared after transfer"
        );
    }

    /**
     * @notice Tests transferFrom when called by an explicitly approved address.
     */
    function test_TransferFromSuccess_ByApproved() public {
        string memory uri = "../metadata/token_1.json";

        // Mint a token as Alice and approve Bob
        vm.startPrank(alice);
        uint256 tokenId = collection.mint(uri);
        collection.approve(bob, tokenId);
        vm.stopPrank();

        // Bob (approved) transfer the token
        vm.prank(bob);
        collection.transferFrom(alice, charlie, tokenId);

        // Verify the state updates
        assertEq(
            collection.ownerOf(tokenId),
            charlie,
            "Charlie should be the new owner of the token"
        );
        assertEq(
            collection.balanceOf(alice),
            0,
            "Alice's token balance should decrease to 0"
        );
        assertEq(
            collection.balanceOf(bob),
            0,
            "Bob's token balance should be 0"
        );

        assertEq(
            collection.balanceOf(charlie),
            1,
            "Charlie's token balance should increase to 1"
        );
        assertEq(
            collection.getApproved(tokenId),
            address(0),
            "Previous approvals must be cleared after transfer"
        );
    }

    /**
     * @notice Tests transferFrom when called by an approved operator (ApprovalForAll).
     */
    function test_TransferFromSuccess_ByOperator() public {
        string memory uri = "../metadata/token_1.json";

        // Mint ta token as Alice and approve Bob as operator for all Alice's tokens
        vm.startPrank(alice);
        uint256 tokenId = collection.mint(uri);
        collection.setApprovalForAll(bob, true);
        vm.stopPrank();

        // Bob (approved) transfers Alice's token to Charlie
        vm.prank(bob);
        collection.transferFrom(alice, charlie, tokenId);

        // Verify the state updates
        assertEq(
            collection.ownerOf(tokenId),
            charlie,
            "Charlie should be the new owner of the token"
        );
        assertEq(
            collection.balanceOf(alice),
            0,
            "Alice's token balance should decrease to 0"
        );
        assertEq(
            collection.balanceOf(bob),
            0,
            "Bob's token balance should be 0"
        );

        assertEq(
            collection.balanceOf(charlie),
            1,
            "Charlie's token balance should increase to 1"
        );
        assertEq(
            collection.getApproved(tokenId),
            address(0),
            "Previous approvals must be cleared after transfer"
        );
    }

    /**
     * @notice Tests that transferFrom reverts if the caller is not the owner
     * nor an approved operator.
     */
    function test_TransferFromRevert_NotTokenOwner() public {
        // Setup the token's initial data
        string memory uri = "../metadata/token_1.json";

        // Mint a token as Alice
        vm.prank(alice);
        uint256 tokenId = collection.mint(uri);

        // Expect the revert with custom error NotTokenOwner
        vm.expectRevert(
            abi.encodeWithSelector(
                NotTokenOwner.selector,
                bob,
                address(collection),
                tokenId
            )
        );

        // Try to transfer Alice's token as Bob
        vm.prank(bob);
        collection.transferFrom(alice, bob, tokenId);
    }

    /**
     * @notice Tests that transferFrom reverts if the 'from' parameter
     * is not the actual owner of the token.
     */
    function test_TransferFromRevert_WrongFromAddress() public {
        string memory uri = "../metadata/token_1.json";

        // Mint a token as Alice
        vm.prank(alice);
        uint256 tokenId = collection.mint(uri);

        // Expect the revert with the custom error NotTokenOwner
        vm.expectRevert(
            abi.encodeWithSelector(
                NotTokenOwner.selector,
                bob,
                address(collection),
                tokenId
            )
        );

        // Alice transfers her token but declaring it's Bob's token
        vm.prank(alice);
        collection.transferFrom(bob, charlie, tokenId);
    }

    /**
     * @notice Tests that transferFrom reverts if transferring to the zero address.
     */
    function test_TransferFromRevert_ToZeroAddress() public {
        string memory uri = "../metadata/token_1.json";

        // Mint a token as Alice
        vm.prank(alice);
        uint256 tokenId = collection.mint(uri);

        // Expect revert with custom error ZeroAdressNotValid (from non ZeroAdress modifier)
        vm.expectRevert(ZeroAddressNotValid.selector);

        // Alice transfers her token to the address 0
        vm.prank(alice);
        collection.transferFrom(alice, address(0), tokenId);
    }

    /**
     * @notice Tests that transferFrom reverts if the token ID does not exist.
     */
    function test_TransferFromRevert_InvalidTokenId() public {
        uint256 nonExistentTokenId = 5;

        // Expect the custom error InvalidTokenId (from validTokenId modifier)
        vm.expectRevert(
            abi.encodeWithSelector(
                Collection.InvalidTokenId.selector,
                nonExistentTokenId
            )
        );

        // Alice transfers an invalid token
        vm.prank(alice);
        collection.transferFrom(alice, bob, nonExistentTokenId);
    }

    // ==========================================
    // SET_APPROVAL_FOR_ALL & IS_APPROVED_FOR_ALL TESTS
    // ==========================================
    // test_SetApprovalForAllSuccess()
    // test_SetApprovalForAllRevert_CannotApproveSelf()
    // test_SetApprovalForAllRevert_ZeroAddress()

    /**
     * @notice Tests the successful setting and revoking of an operator,
     * verifying the state updates and the emitted events.
     */
    function test_SetApprovalForAllSuccess() public {
        // Initially, Bob should not be an operator for Alice
        assertEq(
            collection.isApprovedForAll(alice, bob),
            false,
            "Bob should not be an operator initially"
        );

        // Expect the ApprovalForAll event (Alice approves Bob)
        vm.expectEmit();
        emit ApprovalForAll(alice, bob, true);

        // Alice sets Bob as an operator
        vm.prank(alice);
        collection.setApprovalForAll(bob, true);

        // Verify the state updated
        assertEq(
            collection.isApprovedForAll(alice, bob),
            true,
            "Bob should be an operator for Alice"
        );

        // Expect the ApprovalForAll event (Alice revokes Bob)
        vm.expectEmit();
        emit ApprovalForAll(alice, bob, false);

        // Alice revokes Bob's operator status
        vm.prank(alice);
        collection.setApprovalForAll(bob, false);

        // Verify the state updated
        assertEq(
            collection.isApprovedForAll(alice, bob),
            false,
            "Bob should no longer be an operator for Alice"
        );
    }

    /**
     * @notice Tests that setApprovalForAll reverts if the owner tries to approve themselves.
     */
    function test_SetApprovalForAllRevert_CannotApproveSelf() public {
        // Expect custom error CannotApproveSelf
        vm.expectRevert(Collection.CannotApproveSelf.selector);

        // Alice tries to set herself as an operator
        vm.prank(alice);
        collection.setApprovalForAll(alice, true);
    }

    /**
     * @notice Tests that setApprovalForAll reverts if the operator is the zero address.
     */
    function test_SetApprovalForAllRevert_ZeroAddress() public {
        // Expect custom error ZeroAddressNotValid (from nonZeroAddress modifier)
        vm.expectRevert(ZeroAddressNotValid.selector);

        // Alice tries to set the zero address as an operator
        vm.prank(alice);
        collection.setApprovalForAll(address(0), true);
    }

    // ==========================================
    // SAFE_TRANSFER_FROM TESTS
    // ==========================================
    // test_SafeTransferFromSuccess()

    /**
     * @notice Tests the safeTransferFrom function (which wraps transferFrom).
     */
    function test_SafeTransferFromSuccess() public {
        // Setup initial data
        string memory uri = "../metadata/token_1.json";

        // Alice mints a token and approves Charlie (to check if approval clears)
        vm.startPrank(alice);
        uint256 tokenId = collection.mint(uri);
        collection.approve(charlie, tokenId);
        vm.stopPrank();

        // Expect the Transfer event
        vm.expectEmit();
        emit Transfer(alice, bob, tokenId);

        // Alice transfers to Bob using safeTransferFrom
        vm.prank(alice);
        collection.safeTransferFrom(alice, bob, tokenId);

        // Verify state updates
        assertEq(
            collection.ownerOf(tokenId),
            bob,
            "Bob should be the new owner"
        );
        assertEq(collection.balanceOf(alice), 0, "Alice's balance should be 0");
        assertEq(collection.balanceOf(bob), 1, "Bob's balance should be 1");
        assertEq(
            collection.getApproved(tokenId),
            address(0),
            "Previous approvals must be cleared"
        );
    }
}
