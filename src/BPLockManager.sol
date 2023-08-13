// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {IBPTentacle} from "./interfaces/IBPTentacle.sol";
import {IBPLockManager} from "./interfaces/IBPLockManager.sol";
import {IStakingDelegate} from "./interfaces/IStakingDelegate.sol";

enum TENTACLE_STATE {
    NONE,
    CREATED
}

contract BPLockManager is IBPLockManager {
    error ONLY_DELEGATE();
    error INVALID_DELEGATE();
    error NOT_SET_AS_LOCKMANAGER(uint256 _tokenId);
    error NOT_ALLOWED(uint256 _tokenId);
    error ALREADY_CREATED(uint8 _tentacleID, uint256 _tokenId);
    error TENTACLE_NOT_SET(uint8 _tentacleID);

    /**
     * @dev
     * The delegate that this lockManager is for.
     */
    IStakingDelegate immutable stakingDelegate;

    /**
     * @dev 
     * The outstanding tentacles for each token.
     */
    mapping(uint256 _tokenID => bytes32) outstandingTentacles;

    /**
     * @dev 
     * Limited to be a `uint8` since this is the limit of the `outstandingTentacles` bitmap.
     */
    mapping(uint8 => IBPTentacle) tentacles;

    constructor(IStakingDelegate _stakingDelegate) {
        stakingDelegate = _stakingDelegate;
    }

    function onRegistration(
        uint256 _id,
        bytes[] calldata _data
    ) external override {
        // Make sure only the delegate can call this
        if(msg.sender != address(stakingDelegate)) revert ONLY_DELEGATE();

        // TODO: implement
    }

    function onRedeem(uint256 _id) external override {
        // Make sure only the delegate can call this
        if(msg.sender != address(stakingDelegate)) revert ONLY_DELEGATE();

        // TODO: get the outstandingTentacles and attempt to destroy all of the outstanding tentacles
    }

    function create(uint8 _tentacleID, uint256 _tokenID, address _beneficiary) external {
        // Make sure that this lockManager is in control of locking the token
        if(stakingDelegate.lockManager(_tokenID) != address(this)) revert NOT_SET_AS_LOCKMANAGER(_tokenID);
        // Check that the sender has permission to create tentacles for the token
        if(!stakingDelegate.isApprovedOrOwner(msg.sender, _tokenID)) revert NOT_ALLOWED(_tokenID);

        _create(_tentacleID, _tokenID, _beneficiary);
        
        // TODO: emit event?
    }

    function destroy(uint8 _tentacleID, uint256 _tokenID) public {
        // Check that the sender has permission to destroy tentacles for the token
        if(!stakingDelegate.isApprovedOrOwner(msg.sender, _tokenID)) revert NOT_ALLOWED(_tokenID);

        _destroy(_tentacleID, _tokenID, msg.sender, msg.sender);

        // TODO: emit event?
    }

    function setTentacle(uint8 _tentacleID, IBPTentacle _tentacle) external {
        // NOTICE
        // TODO: Add owner check!

        // Should we allow an tentacle to be replaced? 
        tentacles[_tentacleID] = _tentacle;

        // TODO: emit event
    }

    function isUnlocked(
        address _token,
        uint256 _id
    ) external view override returns (bool) {
        // Safety precaution to make sure if another delegate accidentally has this as its lockManager it will not lock any tokens indefinetly
        if(_token != address(stakingDelegate)) return true;
        // Check if no bits are set, if none are then this token is unlocked
        return uint256(outstandingTentacles[_id]) == 0;
    }

    function _create(uint8 _tentacleID, uint256 _tokenID, address _beneficiary) internal {
        // NOTICE: this does not perform access control checks!

        // Get the value of the token
        uint256 _amount = stakingDelegate.stakingTokenBalance(_tokenID);

        // Check that the tentacle hasn't been created yet for this token
        bytes32 _outstandingTentacles = outstandingTentacles[_tokenID];
        if(_getTentacle(_outstandingTentacles, _tentacleID) == TENTACLE_STATE.CREATED)
            revert ALREADY_CREATED(_tentacleID, _tokenID);

        // Update to reflect that the tentacle has been created
        outstandingTentacles[_tokenID] = _setTentacle(_outstandingTentacles, _tentacleID);

        // Get the tentacle that we are minting
        IBPTentacle _tentacle = tentacles[_tentacleID];
        if(address(_tentacle) == address(0)) revert TENTACLE_NOT_SET(_tentacleID);

        // Call tentacle to mint tokens
        _tentacle.mint(_beneficiary, _amount);
    }

    function _destroy(uint8 _tentacleID, uint256 _tokenID, address _caller, address _from) internal {
        // NOTICE: this does not perform access control checks!

        // Get the value of the token
        uint256 _amount = stakingDelegate.stakingTokenBalance(_tokenID);

        bytes32 _outstandingTentacles = outstandingTentacles[_tokenID];
        if(_getTentacle(_outstandingTentacles, _tentacleID) == TENTACLE_STATE.CREATED)
            revert ALREADY_CREATED(_tentacleID, _tokenID);

        // Get the tentacle that we are burning for
        IBPTentacle _tentacle = tentacles[_tentacleID];
        if(address(_tentacle) == address(0)) revert TENTACLE_NOT_SET(_tentacleID);

        // Call tentacle to burn tokens
        _tentacle.burn(msg.sender, msg.sender, _amount);

        // Update to reflect that the tentacle has been destroyed
        outstandingTentacles[_tokenID] = _unsetTentacle(_outstandingTentacles, _tentacleID);
    }


    function _setTentacle(bytes32 _outstandingTentacles, uint8 _id) internal pure returns (bytes32 _updatedTentacles) {
        assembly {
            _updatedTentacles := or(shl(_id, 1), _outstandingTentacles)
        }
    }

    function _unsetTentacle(bytes32 _outstandingTentacles, uint8 _id) internal pure returns (bytes32 _updatedTentacles) {
        assembly {
            _updatedTentacles := and(shl(_id, 0), _outstandingTentacles)
        }
    }

    function _getTentacle(bytes32 _outstandingTentacles, uint8 _id) internal pure returns (TENTACLE_STATE _state) {
        assembly {
            _state := iszero(iszero(and(shl(_id, 0x1), _outstandingTentacles)))
        }
    }
}
