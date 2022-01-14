// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "./DividendPayingToken.sol";
import "./IterableMapping.sol";

contract ODSYDividendTracker is DividendPayingToken {
  using SafeMath for uint256;
  using SafeMathInt for int256;
  using IterableMapping for IterableMapping.Map;

  IterableMapping.Map private tokenHoldersMap;
  uint256 public lastProcessedIndex;

  mapping (address => bool) public excludedFromDividends;
  mapping (address => uint256) public lastClaimTimes;

  uint256 public claimWait = 3600;
  uint256 public minimumTokenBalanceForDividends = 300_000_000 ether; //must hold 300,000,000+ tokens

  event Claim(address indexed account, uint256 amount, bool indexed automatic);
  event ExcludeFromDividends(address indexed account);
  event IncludeInDividends(address indexed account);
  event SetClaimWait(uint256 indexed previousValue, uint256 indexed newValue);

  constructor() DividendPayingToken() {
    excludedFromDividends[address(this)] = true;
  }

  function excludeFromDividends(address account) external onlyOwner {
    require(!excludedFromDividends[account], "ODSYDividendTracker: Value already set");
    excludedFromDividends[account] = true;
    changeBalance(account, 0);
    tokenHoldersMap.remove(account);
    emit ExcludeFromDividends(account);
  }

  function includeInDividends(address account) external onlyOwner {
    require(excludedFromDividends[account], "ODSYDividendTracker: Value already set");
    excludedFromDividends[account] = false;
    emit IncludeInDividends(account);
  }

  function setClaimWait(uint256 secondsBetweenClaims) external onlyOwner {
    require(secondsBetweenClaims >= 3600 && secondsBetweenClaims <= 86400, "ODSYDividendTracker: claimWait must be between 1 and 24 hours");
    require(secondsBetweenClaims != claimWait, "ODSYDividendTracker: Value already set");
    emit SetClaimWait(claimWait, secondsBetweenClaims);
    claimWait = secondsBetweenClaims;
  }

  function withdrawDividend() pure public override {
    require(false, "ODSYDividendTracker: withdrawDividend disabled. Use the 'claim' function on the main ODSY contract.");
  }

  function updateMinimumTokenBalanceForDividends(uint256 _newMinimumBalance) external onlyOwner {
    require(_newMinimumBalance != minimumTokenBalanceForDividends, "ODSYDividendTracker: New mimimum balance for dividend cannot be same as current minimum balance");
    minimumTokenBalanceForDividends = _newMinimumBalance * (10**18);
  }

  function getLastProcessedIndex() external view returns(uint256) {
    return lastProcessedIndex;
  }

  function getNumberOfTokenHolders() external view returns(uint256) {
    return tokenHoldersMap.keys.length;
  }

  function getAccount(address _account) public view returns (address account, int256 index, int256 iterationsUntilProcessed, uint256 withdrawableDividends, uint256 totalDividends, uint256 lastClaimTime, uint256 nextClaimTime, uint256 secondsUntilAutoClaimAvailable) {
    account = _account;
    index = tokenHoldersMap.getIndexOfKey(account);
    iterationsUntilProcessed = -1;
    if (index >= 0) {
      if (uint256(index) > lastProcessedIndex) {
        iterationsUntilProcessed = index.sub(int256(lastProcessedIndex));
      } else {
        uint256 processesUntilEndOfArray = (tokenHoldersMap.keys.length > lastProcessedIndex) ? tokenHoldersMap.keys.length.sub(lastProcessedIndex) : 0;
        iterationsUntilProcessed = index.add(int256(processesUntilEndOfArray));
      }
    }

    withdrawableDividends = withdrawableDividendOf(account);
    totalDividends = accumulativeDividendOf(account);
    lastClaimTime = lastClaimTimes[account];
    nextClaimTime = (lastClaimTime > 0) ? lastClaimTime.add(claimWait) : 0;
    secondsUntilAutoClaimAvailable = (nextClaimTime > block.timestamp) ? nextClaimTime.sub(block.timestamp) : 0;
  }

  function getAccountAtIndex(uint256 index) public view returns (address, int256, int256, uint256, uint256, uint256, uint256, uint256) {
    if (index >= tokenHoldersMap.size()) {
      return (0x0000000000000000000000000000000000000000, -1, -1, 0, 0, 0, 0, 0);
    }
    address account = tokenHoldersMap.getKeyAtIndex(index);
    return getAccount(account);
  }

  function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
    if (lastClaimTime > block.timestamp) return false;
    return block.timestamp.sub(lastClaimTime) >= claimWait;
  }

  function setBalance(address payable account, uint256 newBalance) external onlyOwner {
    if (excludedFromDividends[account]) return;

    if (newBalance >= minimumTokenBalanceForDividends) {
      changeBalance(account, newBalance);
      tokenHoldersMap.set(account, newBalance);
    } else {
      changeBalance(account, 0);
      tokenHoldersMap.remove(account);
    }
    processAccount(account, true);
  }

  function process(uint256 gas) public returns (uint256, uint256, uint256) {
    uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;
    if (numberOfTokenHolders == 0) return (0, 0, lastProcessedIndex);

    uint256 _lastProcessedIndex = lastProcessedIndex;
    uint256 gasUsed = 0;
    uint256 gasLeft = gasleft();
    uint256 iterations = 0;
    uint256 claims = 0;

    while (gasUsed < gas && iterations < numberOfTokenHolders) {
      _lastProcessedIndex++;
      if (_lastProcessedIndex >= tokenHoldersMap.keys.length) _lastProcessedIndex = 0;

      address account = tokenHoldersMap.keys[_lastProcessedIndex];

      if (canAutoClaim(lastClaimTimes[account])) {
        if (processAccount(payable(account), true)) claims++;
      }
      iterations++;
      uint256 newGasLeft = gasleft();
      if (gasLeft > newGasLeft) gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
      gasLeft = newGasLeft;
    }

    lastProcessedIndex = _lastProcessedIndex;

    return (iterations, claims, lastProcessedIndex);
  }

  function processAccount(address payable account, bool automatic) public onlyOwner returns (bool) {
    uint256 amount = withdrawDividendOfUser(account);

    if (amount > 0) {
      lastClaimTimes[account] = block.timestamp;
      emit Claim(account, amount, automatic);
      return true;
    }

    return false;
  }
}
