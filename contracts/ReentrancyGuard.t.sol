// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Test} from "forge-std/Test.sol";
import {ReentrancyGuard} from "../contracts/ReentrancyGuard.sol";
import "../errors/SharedErrors.sol";

interface IAttacker {
    function attackTarget() external;
}

// TARGET CONTRACT
contract MockGuarded is ReentrancyGuard {
    /// @notice A protected function simulating an external interaction
    function protectedCall(address target) external nonReentrant {
        // We use .call("") to provide enough gas for the reentrancy attempt
        IAttacker(target).attackTarget();
    }
}

// ATTACKER CONTRACT
contract Attacker is IAttacker {
    MockGuarded public target;

    constructor(MockGuarded _target) {
        target = _target;
    }

    /// @notice Triggered by the target's external call, attempts to re-enter
    function attackTarget() external override {
        // The attacker tries to re-enter the protected function
        target.protectedCall(address(this));
    }

    /// @notice Initiates the attack
    function attack() external {
        target.protectedCall(address(this));
    }
}

// REENTRANCY GUARD TESTS
contract ReentrancyGuardTest is Test {
    MockGuarded public target;
    Attacker public attacker;

    function setUp() public {
        target = new MockGuarded();
        attacker = new Attacker(target);
    }

    /**
     * @notice Tests that the modifier successfully reverts a reentrant call
     * throwing the specific ReentrancyDetected custom error.
     */
    function test_RevertWhen_ReentrantCall() public {
        // We expect the specific custom error from the modifier
        vm.expectRevert(ReentrancyDetected.selector);

        // Launch the attack
        attacker.attack();
    }
}
