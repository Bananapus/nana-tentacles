// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;
// import {StdStorage, stdStorage} from "./StdStorage.sol";

import {Test, console2, StdStorage, stdStorage} from "forge-std/Test.sol";
import "../util/DSTestFull.sol";
import "../../src/BPLockManager.sol";
import "../../src/interfaces/IBPTentacle.sol";

contract LockManagerUnitTest is DSTestFull {
    using stdStorage for StdStorage;

    error NOT_SET_AS_LOCKMANAGER(uint256 _tokenId);
    error TENTACLE_NOT_SET(uint8 _tentacleID);

    StdStorage _storage;

    ForTest_BPLockManager _lockManager;

    address owner = _newAddress();

    // Mocks
    IStakingDelegate _delegate = IStakingDelegate(_mockContract("delegate"));

    function setUp() public {
        _lockManager = new ForTest_BPLockManager(_delegate, owner);
    }

    function test_create(address _user, address _beneficiary, uint256 _tokenID, uint256 _tokenStake, uint8 _tentacleID)
        public
    {
        // Mock the tentacle
        IBPTentacle _tentacle = configure_and_mock_tentacle(_lockManager, _tentacleID);

        // Mock the delegate
        mock_delegate_tokenStake(_tokenID, _tokenStake);
        mock_delegate_approval(_tokenID, _user, true);
        mock_delegate_lockManagerIsSet(_tokenID, _lockManager);

        // It should call the tentacle to perform the mint
        vm.expectCall(address(_tentacle), abi.encodeCall(_tentacle.mint, (_beneficiary, _tokenStake)));

        // Check that the tentacle has not been created yet
        assertEq(_lockManager.tentacleCreated(_tokenID, _tentacleID), false);

        vm.prank(_user);
        _lockManager.create(_tentacleID, _tokenID, _beneficiary, IBPTentacleHelper(address(0)));

        // Check that it is not registered
        assertEq(_lockManager.tentacleCreated(_tokenID, _tentacleID), true);
    }

    function test_create_lockManagerNotSet_reverts(
        address _user,
        address _beneficiary,
        uint256 _tokenID,
        uint256 _tokenStake,
        uint8 _tentacleID,
        BPLockManager _configuredLockManager
    ) public {
        vm.assume(_lockManager != _configuredLockManager);

        // Mock the tentacle
        configure_and_mock_tentacle(_lockManager, _tentacleID);

        // Mock the delegate
        mock_delegate_tokenStake(_tokenID, _tokenStake);
        mock_delegate_approval(_tokenID, _user, true);
        mock_delegate_lockManagerIsSet(_tokenID, _configuredLockManager);

        // It should call the tentacle to perform the mint
        vm.expectRevert(abi.encodeWithSelector(NOT_SET_AS_LOCKMANAGER.selector, _tokenID));

        vm.prank(_user);
        _lockManager.create(_tentacleID, _tokenID, _beneficiary, IBPTentacleHelper(address(0)));
    }

    function test_create_tentacleNotSet(
        address _user,
        address _beneficiary,
        uint256 _tokenID,
        uint256 _tokenStake,
        uint8 _tentacleID
    ) public {
        // Mock the delegate
        mock_delegate_tokenStake(_tokenID, _tokenStake);
        mock_delegate_approval(_tokenID, _user, true);
        mock_delegate_lockManagerIsSet(_tokenID, _lockManager);

        // It should call the tentacle to perform the mint
        vm.expectRevert(abi.encodeWithSelector(TENTACLE_NOT_SET.selector, _tentacleID));

        vm.prank(_user);
        _lockManager.create(_tentacleID, _tokenID, _beneficiary, IBPTentacleHelper(address(0)));
    }

    function mock_delegate_lockManagerIsSet(uint256 _tokenID, BPLockManager __lockManager) internal {
        // Build the mock call
        vm.mockCall(address(_delegate), 0, abi.encodeCall(_delegate.lockManager, (_tokenID)), abi.encode(__lockManager));
    }

    function mock_delegate_approval(uint256 _tokenID, address _spender, bool _state) internal {
        // Build the mock call
        vm.mockCall(
            address(_delegate), 0, abi.encodeCall(_delegate.isApprovedOrOwner, (_spender, _tokenID)), abi.encode(_state)
        );
    }

    function mock_delegate_tokenStake(uint256 _tokenID, uint256 _tokenStake) internal {
        // Build the mock call
        vm.mockCall(
            address(_delegate), 0, abi.encodeCall(_delegate.stakingTokenBalance, (_tokenID)), abi.encode(_tokenStake)
        );
    }

    function configure_and_mock_tentacle(ForTest_BPLockManager __lockManager, uint8 _tentacleId)
        internal
        returns (IBPTentacle)
    {
        IBPTentacle _tentacle = IBPTentacle(_mockContract("tentacle"));

        __lockManager.setTentacleConfiguration(
            _tentacleId,
            BPTentacleConfiguration({
                hasDefaultHelper: false,
                forceDefault: false,
                revertIfDefaultForcedAndOverriden: false,
                tentacle: _tentacle
            })
        );

        // // TODO: fix, this sets a simple address but it should be a struct, but this is not supported by stdStorage
        // _storage.target(address(__lockManager))
        //     .sig(__lockManager.tentacles.selector)
        //     .with_key(_tentacleId)
        //     .checked_write(address(_tentacle));

        return _tentacle;
    }

    // function testToggle(bytes32 _outstandingTentacles, uint8 _id) public pure {
    //     // Get the state it was in initially
    //     TENTACLE_STATE _state = _getTentacle(_outstandingTentacles, _id);

    //     // Toggle the value
    //     if(_state == TENTACLE_STATE.NONE )
    //         _outstandingTentacles = _setTentacle(_outstandingTentacles, _id);
    //     else
    //         _outstandingTentacles = _unsetTentacle(_outstandingTentacles, _id);

    //     // Get the new state
    //     TENTACLE_STATE _newState = _getTentacle(_outstandingTentacles, _id);

    //     // Make sure that it was toggeled
    //     assert(
    //         _state != _newState
    //     );
    // }
}

contract ForTest_BPLockManager is BPLockManager {
    constructor(IStakingDelegate _stakingDelegate, address _owner) BPLockManager(_stakingDelegate, _owner) {}

    function setTentacleConfiguration(uint8 _tentacleID, BPTentacleConfiguration memory _configuration) public {
        tentacles[_tentacleID] = _configuration;
    }
}
