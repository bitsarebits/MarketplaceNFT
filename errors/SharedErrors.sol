// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

/// @notice Custom error thrown when a caller tries to operate on a token they do not own
error NotTokenOwner(address caller, uint256 tokenId);

/// @notice Custom error thrown when providing an invalid zero address
error ZeroAddressNotValid();

/// @notice Custom error thrown when a reentrant call is detected by the mutex
error ReentrancyDetected();
