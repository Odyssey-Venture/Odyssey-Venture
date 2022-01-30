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

  mapping (address => bool) public excludedAccounts;
  mapping (address => uint256) public lastClaimTimes;

  uint256 public claimWait = 6 hours;
  uint256 public minimumBalance = 10_000_000; // must hold 10,000,000+ tokens
  uint256 public minimumBalanceExtended; // EXTENDED TO 10e18

  event Claim(address indexed account, uint256 amount, bool indexed automatic);
  event ExcludedFromDividends(address indexed account, bool isExcluded);
  event SetClaimWait(uint256 indexed previousValue, uint256 indexed newValue);
  event MinimumBalanceChanged(uint256 indexed previousValue, uint256 indexed newValue);

  constructor() DividendPayingToken("OdysseyRewards", "ODSYRV1") {
    excludedAccounts[address(this)] = true;
    minimumBalanceExtended = minimumBalance * 1 ether;
  }

  function getAccountInfo(address _account) public view returns (address account, int256 index, int256 iterationsUntilProcessed, uint256 withdrawableDividends, uint256 totalDividends, uint256 lastClaimTime, uint256 nextClaimTime, uint256 secondsUntilAutoClaimAvailable) {
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

    withdrawableDividends = this.getWithdrawable(account);
    totalDividends = getAccumulated(account);
    lastClaimTime = lastClaimTimes[account];
    nextClaimTime = (lastClaimTime > 0) ? lastClaimTime.add(claimWait) : 0;
    secondsUntilAutoClaimAvailable = (nextClaimTime > block.timestamp) ? nextClaimTime.sub(block.timestamp) : 0;
  }

  function getAccountInfoAtIndex(uint256 index) public view returns (address, int256, int256, uint256, uint256, uint256, uint256, uint256) {
    if (index >= tokenHoldersMap.size()) return (0x0000000000000000000000000000000000000000, -1, -1, 0, 0, 0, 0, 0);

    address account = tokenHoldersMap.getKeyAtIndex(index);
    return getAccountInfo(account);
  }

  // function getLastProcessedIndex() external view returns(uint256) {
  //   return lastProcessedIndex;
  // }

  function getHolderCount() external view returns(uint256) {
    return tokenHoldersMap.keys.length;
  }

  function setExcludedAccount(address account, bool exclude) external onlyOwner {
    require(excludedAccounts[account] != exclude, "ODSYDividendTracker: Value already set");

    excludedAccounts[account] = exclude;
    emit ExcludedFromDividends(account, exclude);
  }

  function processClaims(uint256 gas) public returns (uint256, uint256, uint256) {
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
        if (processClaim(payable(account), true)) claims++;
      }
      iterations++;
      uint256 newGasLeft = gasleft();
      if (gasLeft > newGasLeft) gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
      gasLeft = newGasLeft;
    }

    lastProcessedIndex = _lastProcessedIndex;

    return (iterations, claims, lastProcessedIndex);
  }

  function processClaim(address payable account, bool automatic) public onlyOwner returns (bool) {
    uint256 amount = processWithdraw(account);

    if (amount > 0) {
      lastClaimTimes[account] = block.timestamp;
      emit Claim(account, amount, automatic);
      return true;
    }

    return false;
  }

  function setBalance(address payable account, uint256 newBalance) external onlyOwner {
    if (excludedAccounts[account]) return;
    if (newBalance >= minimumBalanceExtended) { // * 10e18
      changeBalance(account, newBalance);
      tokenHoldersMap.set(account, newBalance);
    } else {
      changeBalance(account, 0);
      tokenHoldersMap.remove(account);
    }
    processClaim(account, true);
  }

  function setClaimWait(uint256 secondsBetweenClaims) external onlyOwner {
    require(secondsBetweenClaims != claimWait, "ODSYDividendTracker: Value already set");
    require(secondsBetweenClaims >= 1 hours && secondsBetweenClaims <= 1 days, "ODSYDividendTracker: claimWait must be between 1 and 24 hours");
    emit SetClaimWait(claimWait, secondsBetweenClaims);
    claimWait = secondsBetweenClaims;
  }

  function setMinimumBalance(uint256 newBalance) external onlyOwner {
    require(newBalance != minimumBalance, "ODSYDividendTracker: Value already set");
    emit MinimumBalanceChanged(minimumBalance, newBalance);
    minimumBalance = newBalance;
    minimumBalanceExtended = minimumBalance * 1 ether; // EXTENDED TO 10e18 // * 10e18
  }

  function withdrawRewards() pure public override {
    require(false, "ODSYDividendTracker: Withdrawls must use the `claim` function on the main ODSY contract.");
  }

  // PRIVATE

  function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
    if (lastClaimTime > block.timestamp) return false;
    return block.timestamp.sub(lastClaimTime) >= claimWait;
  }
}
