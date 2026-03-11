// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../errors/SharedErrors.sol";

/**
 * @title Reentrancy Guard
 * @dev Abstract contract that provides a mutex for reentrancy attack
 */
abstract contract ReentrancyGuard {
    /// @dev Mutex lock to prevent reentrancy attacks.
    bool private _locked;

    /**
     * @dev Modifier to prevent reentrancy attacks.
     * Acts as a mutex lock during external calls.
     */
    modifier nonReentrant() {
        if (_locked) {
            revert ReentrancyDetected();
        }
        _locked = true;
        _;
        _locked = false;
    }
}
