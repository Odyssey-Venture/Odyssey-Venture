// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface IDividendPayingToken {
  function getAccumulated(address _owner) external view returns(uint256);
  function getWithdrawable(address _owner) external view returns(uint256);
  function getWithdrawn(address _owner) external view returns(uint256);
  function distributeFunds() external payable;
  function name() external view returns (string memory);
  function symbol() external view returns (string memory);
  function withdrawRewards() external;

  event DividendsWithdrawn(address indexed to, uint256 amount);
  event DistributedFunds(address indexed from, uint256 amount);
}
