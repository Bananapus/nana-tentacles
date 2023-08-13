// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

interface IStakingDelegate {
   function stakingTokenBalance(uint256 _tokenId) external view returns (uint256 _amount);
   function isApprovedOrOwner(address _spender, uint256 _tokenId) external view returns (bool _isAllowed);
   function lockManager(uint256 _tokenID) external view returns (address _lockManager);
}