// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {IBPTentacle} from "./interfaces/IBPTentacle.sol";
import {IBPTentacleHelper} from "./interfaces/IBPTentacleHelper.sol";
import {IBPLockManager} from "./interfaces/IBPLockManager.sol";
import {IStakingDelegate} from "./interfaces/IStakingDelegate.sol";

import {BPConstants} from "./libraries/BPConstants.sol";
import {BPTentacleCreateData} from "./structs/BPTentacleCreateData.sol";
import {BPTentacleConfiguration} from "./structs/BPTentacleConfiguration.sol";

import {Ownable, Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

/// @notice A contract that manages the locking of staked 721s.
contract BPLockManager is Ownable2Step, IBPLockManager {
    //*********************************************************************//
    // --------------------------- custom errors ------------------------- //
    //*********************************************************************//

    error ONLY_DELEGATE();
    error NOT_SET_AS_LOCKMANAGER(uint256 _tokenId);
    error ALREADY_CREATED(uint8 _tentacleId, uint256 _tokenId);
    error NOT_CREATED(uint8 _tentacleId, uint256 _tokenId);
    error TENTACLE_NOT_SET(uint8 _tentacleId);
    error TENTACLE_HAS_DEFAULT_HELPER(uint8 _tentacleId);
    error UNAUTHORIZED(uint256 _tokenId);
    error TENTACLE_ALREADY_EXISTS(uint8 _tentacleId);

    //*********************************************************************//
    // ---------------- public immutable stored properties --------------- //
    //*********************************************************************//

    /// @notice The 721 staking delegate that this lock manager manages.
    IStakingDelegate immutable stakingDelegate;

    //*********************************************************************//
    // --------------------- public stored properties -------------------- //
    //*********************************************************************//

    /// @notice The outstanding tentacles for each staked 721.
    /// @dev The index of the activated bits identify which tentacles are outstanding. ex. `0x5` means that both tentacles with IDs 0 and 2 are outstanding
    /// @custom:param The token ID to which the outstanding tentacles belong.
    mapping(uint256 _tokenId => bytes32) public outstandingTentacles;

    /// @notice The available tentacles for stakers to take out.
    /// @dev Limited to be a `uint8` since this is the limit of the `outstandingTentacles` bitmap.
    /// @custom:param The tentacle ID of each configuration.
    mapping(uint8 _tentacleId => BPTentacleConfiguration) public tentacles;

    /// @notice The implementation of tentacle creation for each ID.
    /// @custom:param The tentacle ID of each default helper.
    mapping(uint8 _tentacleId => IBPTentacleHelper) public defaultTentacleHelper;

    //*********************************************************************//
    // ------------------------- external views -------------------------- //
    //*********************************************************************//

    /// @notice A flag indicating if the tentacle is unlocked.
    /// @param _stakingDelegate The staking delegate address relative to which the lock being checked applies.
    /// @param _tokenId The ID of the token to check.
    function isUnlocked(address _stakingDelegate, uint256 _tokenId) external view override returns (bool) {
        // Only check locking status for the expected staking delegate.
        if (_stakingDelegate != address(stakingDelegate)) return true;

        // Check if no bits are set, if none are then this token is unlocked
        return uint256(outstandingTentacles[_tokenId]) == 0;
    }

    /// @notice A flag indicating if the specified tentacle has been created for the specified token ID.
    /// @param _tokenId The ID of the token to check for.
    /// @param _tentacleId The ID of the tentacle to check.
    /// @return A flag indicating if the tentacle is outstanding.
    function tentacleCreated(uint256 _tokenId, uint8 _tentacleId) external view returns (bool) {
        return _tentacleIsOutstanding(outstandingTentacles[_tokenId], _tentacleId);
    }

    //*********************************************************************//
    // -------------------------- constructor ---------------------------- //
    //*********************************************************************//

    /// @param _stakingDelegate The 721 staking delegate that this lock manager manages.
    /// @param _owner The owner of the lockManager
    constructor(IStakingDelegate _stakingDelegate, address _owner) Ownable(_owner) {
        stakingDelegate = _stakingDelegate;
    }

    //*********************************************************************//
    // ---------------------- external transactions ---------------------- //
    //*********************************************************************//

    /// @notice A hook called by the staking delegate upon token creation.
    /// @param _beneficiary The address who received the staked position.
    /// @param _stakingAmount The amount of tokens being staked.
    /// @param _tokenIds The ids of the tokens being redeemed.
    /// @param _data Metadata sent by the staker.
    function onRegistration(
        address _beneficiary,
        uint256 _stakingAmount,
        uint256[] memory _tokenIds,
        bytes calldata _data
    ) external override {
        _stakingAmount;

        // Make sure only the hook is being called by the staking delegate.
        if (msg.sender != address(stakingDelegate)) revert ONLY_DELEGATE();

        // Parse the data needed to create tentacles from the metadata sent by the staker.
        // NOTICE: The user provides this data we have to make sure we protect against specifying the same tentacle multiple times
        (BPTentacleCreateData[] memory _tentacleData) = abi.decode(_data, (BPTentacleCreateData[]));

        // Keep a reference to the number of tokens.
        uint256 _numberOfTokens = _tokenIds.length;

        // Verify that these all these tokens can be registered for the tentacles and register them 
        uint256 _totalTokenCount;
        for(uint256 _i; _i < _numberOfTokens;) {
            _registerTentacles(_tokenIds[_i], _tentacleData);
            _totalTokenCount += stakingDelegate.stakingTokenBalance(_tokenIds[_i]);
            unchecked {
                ++_i;
            }
        }

        // For each tentacle we mint all the positions at once
        uint256 _nTentacles = _tentacleData.length;
        for (uint256 _i; _i < _nTentacles;) {
            _create(_tentacleData[_i].id, _tokenIds, _beneficiary, _totalTokenCount, _tentacleData[_i].helper);
            unchecked {
                ++_i;
            }
        }
    }

    /// @notice A hook called by the staking delegate upon token redemption.
    /// @param _tokenId The id of the token being redeemed.
    /// @param _owner The current owner of the token.
    function onRedeem(uint256 _tokenId, address _owner) external override {
        // Make sure only the hook is being called by the staking delegate.
        if (msg.sender != address(stakingDelegate)) revert ONLY_DELEGATE();

        // Keep a refeerence to the outstanding tentacles for the token being redeemed.
        bytes32 _outstandingTentacles = outstandingTentacles[_tokenId];

        // If no tentacles are set, there's nothing to do.
        if (uint256(_outstandingTentacles) == 0) return;

        // Attempt to destroy each entry in the bitmap outstanding.
        for (uint256 _i; _i < 256;) {
            // Check if the tentacle has been created and attempt to destroy it.
            if (_tentacleIsOutstanding(_outstandingTentacles, uint8(_i))) _destroy(uint8(_i), _tokenId, _owner, _owner);

            unchecked {
                ++_i;
            }
        }
    }

    /// @notice Create an outstanding tentacle.
    /// @param _tentacleId The ID of the tentacle being created.
    /// @param _tokenId The ID of the token to which the tentacle belongs.
    /// @param _beneficiary The address that the tentacle being created should belong to.
    /// @param _helperOverride not sure
    function create(uint8 _tentacleId, uint256 _tokenId, address _beneficiary, IBPTentacleHelper _helperOverride)
        external
    {
        // Make sure that this lock manager is in control of locking the specified token.
        if (stakingDelegate.lockManager(_tokenId) != address(this)) revert NOT_SET_AS_LOCKMANAGER(_tokenId);

        // Make sure the caller owns the token being destroyed, or has been approved by the owner.
        if (!stakingDelegate.isApprovedOrOwner(msg.sender, _tokenId)) revert UNAUTHORIZED(_tokenId);

        // Get the value of the token
        uint256 _amount = stakingDelegate.stakingTokenBalance(_tokenId);
        uint256[] memory _tokenIds = new uint256[](1);
        _tokenIds[0] = _tokenId;

        // Check if the tentacle can be registered and set it as registered
        _registerTentacle(_tokenId, _tentacleId);
        // Create the position
        _create(_tentacleId, _tokenIds, _beneficiary, _amount, _helperOverride);
    }

    /// @notice Destroys an outstanding tentacle.
    /// @param _tentacleId The ID of the tentacle being destroyed.
    /// @param _tokenId The ID of the token to which the tentacle belongs.
    function destroy(uint8 _tentacleId, uint256 _tokenId) external {
        // Make sure the caller owns the token being destroyed, or has been approved by the owner.
        if (!stakingDelegate.isApprovedOrOwner(msg.sender, _tokenId)) revert UNAUTHORIZED(_tokenId);

        // Destroy the tentacle.
        _destroy(_tentacleId, _tokenId, msg.sender, msg.sender);
    }

    /// @notice Sets a tentacle implementation for the given ID.
    /// @param _tentacleId The ID to set the tentacle for.
    /// @param _configuration The details of the tentacle being set.
    /// @param _defaultHelper not sure
    function setTentacle(
        uint8 _tentacleId,
        BPTentacleConfiguration calldata _configuration,
        IBPTentacleHelper _defaultHelper
    ) external onlyOwner {
        // Make sure the tentacle doesn't already exist
        if (address(tentacles[_tentacleId].tentacle) != address(0))
            revert TENTACLE_ALREADY_EXISTS(_tentacleId);
        
        tentacles[_tentacleId] = _configuration;
        defaultTentacleHelper[_tentacleId] = _defaultHelper;

        emit TentacleSet(
            _tentacleId,
            _configuration.hasDefaultHelper,
            _configuration.forceDefault,
            _configuration.revertIfDefaultForcedAndOverriden,
            address(_defaultHelper),
            address(_configuration.tentacle)
        );
    }

    //*********************************************************************//
    // ---------------------- internal transactions ---------------------- //
    //*********************************************************************//

    /// @notice Updates a tokenId to set multiple tentacles as registered.
    /// @param _tokenId the token ID to update the tentacles for
    /// @param _tentacles the tentacles to set as registered
    function _registerTentacles(
        uint256 _tokenId,
        BPTentacleCreateData[] memory _tentacles
    ) internal {
        bytes32 _outstandingTentacles = outstandingTentacles[_tokenId];

        for (uint256 _i; _i < _tentacles.length;) {
            // Check if this tentacle has already been registered
            if (_tentacleIsOutstanding(_outstandingTentacles, _tentacles[_i].id)) {
                revert ALREADY_CREATED(_tentacles[_i].id, _tokenId);
            }

            // Register it
            _outstandingTentacles = _setTentacle(_outstandingTentacles, _tentacles[_i].id);

            emit TentacleStateUpdated(
                _tokenId,
                _tentacles[_i].id,
                true
            );

            unchecked {
                ++_i;
            }
        }

        // Update all the newly registered tentacles at once
        outstandingTentacles[_tokenId] = _outstandingTentacles;
    }

    /// @notice Updates a tokenId to set a tentacles as registered.
    /// @param _tokenId the token ID to update the tentacles for
    /// @param _tentacleId the tentacle to set as registered
    function _registerTentacle(
        uint256 _tokenId,
        uint8 _tentacleId
    ) internal {
         // Check that the tentacle hasn't been created yet for this token
        bytes32 _outstandingTentacles = outstandingTentacles[_tokenId];
        if (_tentacleIsOutstanding(_outstandingTentacles, _tentacleId)) {
            revert ALREADY_CREATED(_tentacleId, _tokenId);
        }

        // Update to reflect that the tentacle has been created
        outstandingTentacles[_tokenId] = _setTentacle(_outstandingTentacles, _tentacleId);

        emit TentacleStateUpdated(
            _tokenId,
            _tentacleId,
            true
        );
    }

    /// @notice Creates a tentacle.
    /// @param _tentacleId The ID of the tentacle being created.
    /// @param _tokenIds The IDs of the staked tokens to which the tentacle belongs.
    /// @param _beneficiary The address that the tentacle being created should belong to.
    /// @param _size The amount of the new tentacle being created.
    /// @param _helperOverride not sure
    function _create(
        uint8 _tentacleId,
        uint256[] memory _tokenIds,
        address _beneficiary,
        uint256 _size,
        IBPTentacleHelper _helperOverride
    ) internal {
        // NOTICE: this does not perform access control checks!

        // Keep a reference to the tentacle that is being created.
        BPTentacleConfiguration memory _tentacle = tentacles[_tentacleId];

        // Make sure the tentacle exists.
        if (address(_tentacle.tentacle) == address(0)) revert TENTACLE_NOT_SET(_tentacleId);

        // Figure out the helper we should use
        IBPTentacleHelper _helper = _helperOverride;
        if (_tentacle.hasDefaultHelper && (_tentacle.forceDefault || address(_helper) == address(0))) {
            IBPTentacleHelper _defaultHelper = defaultTentacleHelper[_tentacleId];

            if (
                _tentacle.revertIfDefaultForcedAndOverriden && _helperOverride != _defaultHelper
                    && address(_helperOverride) != address(0)
            ) revert TENTACLE_HAS_DEFAULT_HELPER(_tentacleId);

            _helper = _defaultHelper;
        }

        // If the passed helper is the no helper constant the user wants to not have any helper at all.
        if (address(_helper) == BPConstants.NO_HELPER_CONTRACT)
            _helper = IBPTentacleHelper(address(0));

        // Perform the mint, either use the helper flow or the regular flow
        if (address(_helper) != address(0)) {
            // Mint to the helper
            _tentacle.tentacle.mint(address(_helper), _size);
            // Call the helper to perform its actions
            _helper.createFor(_tentacleId, _tentacle.tentacle, _tokenIds, _size, _beneficiary);
        } else {
            // Call tentacle to mint tokens
            _tentacle.tentacle.mint(_beneficiary, _size);
        }
    }

    /// @notice Destroys a tentacle.
    /// @param _tentacleId The ID of the tentacle being destroyed.
    /// @param _tokenId The ID of the staked token to which the tentacle belongs.
    /// @param _caller The address that is destroying the tentacle.
    /// @param _from The address that the tentacle is being destroyed from.
    function _destroy(uint8 _tentacleId, uint256 _tokenId, address _caller, address _from) internal {
        // Keep a reference to the outstanding tentacles for the token.
        bytes32 _outstandingTentacles = outstandingTentacles[_tokenId];

        // Make sure the tentacle being destroyed is outstanding.
        if (!_tentacleIsOutstanding(_outstandingTentacles, _tentacleId)) revert NOT_CREATED(_tentacleId, _tokenId);

        // Get the tentacle that is being destroyed.
        BPTentacleConfiguration memory _tentacleConfiguration = tentacles[_tentacleId];

        // Make sure the tentacle exists.
        if (address(_tentacleConfiguration.tentacle) == address(0)) revert TENTACLE_NOT_SET(_tentacleId);

        // Keep a reference to the amount of staked tokens represented by the token.
        uint256 _stakedAmount = stakingDelegate.stakingTokenBalance(_tokenId);

        // Destroy the tentacle.
        _tentacleConfiguration.tentacle.burn(_caller, _from, _stakedAmount);

        // Store the new outstanding tentacle state.
        outstandingTentacles[_tokenId] = _unsetTentacle(_outstandingTentacles, _tentacleId);

        emit TentacleStateUpdated(
            _tokenId,
            _tentacleId,
            false
        );
    }

    //*********************************************************************//
    // ------------------------- internal pure --------------------------- //
    //*********************************************************************//

    /// @notice Wraps a bitshift operation to set the given ID in the given bitmap.
    /// @param _outstandingTentacles The bitmap to set within.
    /// @param _id The ID to set within the bitmap.
    /// @return updatedOutstandingTentacles The new bitmap.
    function _setTentacle(bytes32 _outstandingTentacles, uint8 _id)
        internal
        pure
        returns (bytes32 updatedOutstandingTentacles)
    {
        assembly {
            updatedOutstandingTentacles := or(shl(_id, 1), _outstandingTentacles)
        }
    }

    /// @notice Wraps a bitshift operation to unset the given ID in the given bitmap.
    /// @param _outstandingTentacles The bitmap to unset within.
    /// @param _id The ID to unset within the bitmap.
    /// @return updatedOutstandingTentacles The new bitmap.
    function _unsetTentacle(bytes32 _outstandingTentacles, uint8 _id)
        internal
        pure
        returns (bytes32 updatedOutstandingTentacles)
    {
        assembly {
            updatedOutstandingTentacles := and(shl(_id, 0), _outstandingTentacles)
        }
    }

    /// @notice Wraps a bitshift operation to check if the given ID is marked as outstanding in the given bitmap.
    /// @param _outstandingTentacles The bitmap to check within.
    /// @param _id The ID to check within the bitmap.
    /// @return flag A flag indicating if the specified tentacle is outstanding.
    function _tentacleIsOutstanding(bytes32 _outstandingTentacles, uint8 _id) internal pure returns (bool flag) {
        assembly {
            flag := iszero(iszero(and(shl(_id, 0x1), _outstandingTentacles)))
        }
    }
}
