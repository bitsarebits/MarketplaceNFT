// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import "../errors/SharedErrors.sol";

/**
 * @title Security Base Contract
 * @dev Abstract contract that provides common security modifiers and state variables
 */
abstract contract SecurityBase {
    /**
     * @dev Modifier to check if an address is the zero address.
     * Reverts with ZeroAddressNotValid if the address is address(0).
     * @param addr The address to validate
     */
    modifier nonZeroAddress(address addr) {
        if (addr == address(0)) {
            revert ZeroAddressNotValid();
        }
        _;
    }
}
