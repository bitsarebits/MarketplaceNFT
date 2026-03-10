// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @notice Custom error thrown when a caller tries to operate on a token they do not own
error NotTokenOwner(address caller, uint256 tokenId);
