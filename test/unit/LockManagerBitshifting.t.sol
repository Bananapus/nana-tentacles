// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../../src/BPLockManager.sol";

contract LockManagerBitshiftingTest is BPLockManager, Test {
    constructor() BPLockManager(IStakingDelegate(address(0))) {}

    function testToggle(bytes32 _outstandingTentacles, uint8 _id) public pure {
        // Get the state it was in initially
        TENTACLE_STATE _state = _getTentacle(_outstandingTentacles, _id);

        // Toggle the value
        if (_state == TENTACLE_STATE.NONE) {
            _outstandingTentacles = _setTentacle(_outstandingTentacles, _id);
        } else {
            _outstandingTentacles = _unsetTentacle(_outstandingTentacles, _id);
        }

        // Get the new state
        TENTACLE_STATE _newState = _getTentacle(_outstandingTentacles, _id);

        // Make sure that it was toggeled
        assert(_state != _newState);
    }
}
