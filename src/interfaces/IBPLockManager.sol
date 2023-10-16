// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IBPLockManager {
    event TentacleStateUpdated(
        uint256 indexed tokenId,
        uint8 tentacleId,
        bool created
    );

    function onRegistration(address beneficiary, uint256 stakingAmount, uint256[] memory tokenIds, bytes calldata data)
        external;
    function onRedeem(uint256 tokenId, address owner) external;
    function isUnlocked(address delegate, uint256 id) external view returns (bool);
}
