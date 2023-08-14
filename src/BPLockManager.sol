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

    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//
    error ONLY_DELEGATE();
    error INVALID_DELEGATE();
    error NOT_SET_AS_LOCKMANAGER(uint256 _tokenId);
    error NOT_ALLOWED(uint256 _tokenId);
    error ALREADY_CREATED(uint8 _tentacleID, uint256 _tokenId);
    error TENTACLE_NOT_SET(uint8 _tentacleID);


    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /**
     * @dev
     * The delegate that this lockManager is for.
     */
    IStakingDelegate immutable stakingDelegate;


    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /**
     * @dev 
     * The outstanding tentacles for each token. The index of the activated bits identify which tentacles are outstanding. 
     * ex. `0x5` means that both tentacleId 0 and 2 are outstanding
     */
    mapping(uint256 _tokenID => bytes32) outstandingTentacles;

    /**
     * @dev 
     * Limited to be a `uint8` since this is the limit of the `outstandingTentacles` bitmap.
     */
    mapping(uint8 => IBPTentacle) public tentacles;


    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    function isUnlocked(
        address _token,
        uint256 _id
    ) external view override returns (bool) {
        // Safety precaution to make sure if another delegate accidentally has this as its lockManager it will not lock any tokens indefinetly
        if(_token != address(stakingDelegate)) return true;
        // Check if no bits are set, if none are then this token is unlocked
        return uint256(outstandingTentacles[_id]) == 0;
    }

    function tenacleCreated(uint256 _tokenID, uint8 _tentacleID) external view returns (bool) {
        return _getTentacle(outstandingTentacles[_tokenID], _tentacleID) == TENTACLE_STATE.CREATED;
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    constructor(IStakingDelegate _stakingDelegate) {
        stakingDelegate = _stakingDelegate;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /**
     * @notice hook that (optionally) gets called upon registration as a lockManager.
     * @param _payer the person who send the transaction and paid for the staked position
     * @param _beneficiary the person who received the staked position
     * @param _tokenID The tokenID that got registered.
     * @param _data data regarding the lock as send by the user
     */
    function onRegistration(
        address _payer,
        address _beneficiary,
        uint256 _tokenID,
        bytes calldata _data
    ) external override {
        // Make sure only the delegate can call this
        if(msg.sender != address(stakingDelegate)) revert ONLY_DELEGATE();
        // Decode data
        (uint8[] memory _tentacleIds) = abi.decode(_data, (uint8[]));

        // Get the value of the token
        uint256 _amount = stakingDelegate.stakingTokenBalance(_tokenID);

        uint256 _nTentacles = _tentacleIds.length;
        for(uint256 _i; _i < _nTentacles;) {
            _create(_tentacleIds[_i], _tokenID, _beneficiary, _amount);

            unchecked {
                ++_i;
            }
        }

        // TODO: emit event?
    }

    /**
     * @notice hook called upon redemption
     * @param _tokenID the id of the token being redeemed
     * @param _owner the current owner of the token
     */
    function onRedeem(
        uint256 _tokenID,
        address _owner
    ) external override {
        _tokenID;
        // Make sure only the delegate can call this
        if(msg.sender != address(stakingDelegate)) revert ONLY_DELEGATE();
        bytes32 _outstandingTentacles = outstandingTentacles[_tokenID];

        // Perform a quick check to see if any are set, if none are set we can do a quick return
        if(uint256(_outstandingTentacles) == 0) return;
        
        for(uint256 _i; _i < 256;) {
            // Check if the tentacle has been created, if it has attempt to destroy it
            if (_getTentacle(_outstandingTentacles, uint8(_i)) == TENTACLE_STATE.CREATED)
                _destroy(uint8(_i), _tokenID, _owner, _owner);

            unchecked {
                ++_i;
            }
        }
    }

    function create(uint8 _tentacleID, uint256 _tokenID, address _beneficiary) external {
        // Make sure that this lockManager is in control of locking the token
        if(stakingDelegate.lockManager(_tokenID) != address(this)) revert NOT_SET_AS_LOCKMANAGER(_tokenID);
        // Check that the sender has permission to create tentacles for the token
        if(!stakingDelegate.isApprovedOrOwner(msg.sender, _tokenID)) revert NOT_ALLOWED(_tokenID);

        // Get the value of the token
        uint256 _amount = stakingDelegate.stakingTokenBalance(_tokenID);

        _create(_tentacleID, _tokenID, _beneficiary, _amount);
        
        // TODO: emit event?
    }

    function destroy(uint8 _tentacleID, uint256 _tokenID) external {
        // Check that the sender has permission to destroy tentacles for the token
        if(!stakingDelegate.isApprovedOrOwner(msg.sender, _tokenID)) revert NOT_ALLOWED(_tokenID);

        _destroy(_tentacleID, _tokenID, msg.sender, msg.sender);

        // TODO: emit event?
    }

    function setTentacle(uint8 _tentacleID, IBPTentacle _tentacle) external {
        // NOTICE
        // TODO: Add owner check!

        // Should we allow a tentacle to be replaced? 
        tentacles[_tentacleID] = _tentacle;

        // TODO: emit event
    }

    //*********************************************************************//
    // ---------------------- internal transactions ---------------------- //
    //*********************************************************************//

    function _create(uint8 _tentacleID, uint256 _tokenID, address _beneficiary, uint256 _amount) internal {
        // NOTICE: this does not perform access control checks!

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
        _tentacle.burn(_caller, _from, _amount);

        // Update to reflect that the tentacle has been destroyed
        outstandingTentacles[_tokenID] = _unsetTentacle(_outstandingTentacles, _tentacleID);
    }

    //*********************************************************************//
    // ------------------------- internal pure --------------------------- //
    //*********************************************************************//

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
