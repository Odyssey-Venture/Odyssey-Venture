// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

interface DividendPayingTokenOptionalInterface {
  function accumulativeDividendOf(address _owner) external view returns(uint256);
  function withdrawableDividendOf(address _owner) external view returns(uint256);
  function withdrawnDividendOf(address _owner) external view returns(uint256);
}
