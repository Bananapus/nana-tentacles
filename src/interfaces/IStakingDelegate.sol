// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

interface IStakingDelegate {
    function stakingTokenBalance(uint256 tokenId) external view returns (uint256 amount);
    function isApprovedOrOwner(address spender, uint256 tokenId) external view returns (bool isAllowed);
    function lockManager(uint256 tokenId) external view returns (address lockManager);
}
