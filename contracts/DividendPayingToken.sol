// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./SafeMathInt.sol";
import "./SafeMathUint.sol";
import "./IDividendPayingToken.sol";

contract DividendPayingToken is Ownable, IDividendPayingToken {
  using SafeMath for uint256;
  using SafeMathUint for uint256;
  using SafeMathInt for int256;

  uint256 constant internal magnifier = 2**128;
  uint256 internal magnifiedBalanceOf;
  uint256 public totalBalance = 0;
  uint256 public totalDistributed;
  uint256 public ownerTotalSupply = 0;

  string private tracker_name;
  string private tracker_symbol;

  mapping(address => int256) internal magnifiedCorrections;
  mapping(address => uint256) internal withdrawnDividends;
  mapping (address => uint256) public balanceOf;

  event ReceivedFunds(address indexed from, uint amount);
  event SetDividendToken(address indexed previousValue, address indexed newValue);
  event SetOwnerTotalSupply(uint256 totalSupply);

  receive() external payable {
    emit ReceivedFunds(msg.sender, msg.value);
    distributeFunds();
  }

  constructor(string memory name_, string memory symbol_) {
    tracker_name = name_;
    tracker_symbol = symbol_;
  }

  function name() public view virtual override returns (string memory) {
    return tracker_name;
  }

  function symbol() public view virtual override returns (string memory) {
    return tracker_symbol;
  }

  function getAccumulated(address _owner) public view override returns(uint256) {
    return magnifiedBalanceOf.mul(balanceOf[_owner]).toInt256Safe().add(magnifiedCorrections[_owner]).toUint256Safe() / magnifier;
  }

  function distributeFunds() public override payable {
    require(totalBalance > 0);
    uint256 amount = msg.value;
    if (amount > 0) {
      magnifiedBalanceOf = magnifiedBalanceOf.add((amount).mul(magnifier) / totalBalance);
      emit DistributedFunds(msg.sender, amount);
      totalDistributed = totalDistributed.add(amount);
    }
  }

  function setOwnerTotalSupply(uint256 totalSupply) external virtual onlyOwner { // TO DO - USE THIS IN MIN/MAX BALANCE
    require(totalSupply > 0);
    ownerTotalSupply = totalSupply;
    emit SetOwnerTotalSupply(totalSupply);
  }

  function withdrawRewards() public virtual override {
    processWithdraw(payable(msg.sender));
  }

  function getWithdrawable(address _owner) external view override returns(uint256) {
    return getAccumulated(_owner).sub(withdrawnDividends[_owner]);
  }

  function getWithdrawn(address _owner) public view override returns(uint256) {
    return withdrawnDividends[_owner];
  }

  // PRIVATE

  function changeBalance(address account, uint256 newBalance) internal {
    uint256 currentBalance = balanceOf[account];
    balanceOf[account] = newBalance;
    if (newBalance > currentBalance) {
      uint256 increaseAmount = newBalance.sub(currentBalance);
      increaseBalance(account, increaseAmount);
      totalBalance += increaseAmount;
    } else if(newBalance < currentBalance) {
      uint256 reduceAmount = currentBalance.sub(newBalance);
      decreaseBalance(account, reduceAmount);
      totalBalance -= reduceAmount;
    }
  }

  function decreaseBalance(address account, uint256 value) internal {
    magnifiedCorrections[account] = magnifiedCorrections[account].add((magnifiedBalanceOf.mul(value)).toInt256Safe());
  }

  function increaseBalance(address account, uint256 value) internal {
    magnifiedCorrections[account] = magnifiedCorrections[account].sub((magnifiedBalanceOf.mul(value)).toInt256Safe());
  }

  function processWithdraw(address payable user) internal returns (uint256) {
    uint256 dividends = this.getWithdrawable(user);
    if (dividends <= 0) return 0;
    withdrawnDividends[user] = withdrawnDividends[user].add(dividends);
    emit DividendsWithdrawn(user, dividends);
    (bool success,) = user.call{value: dividends, gas: 3000}("");
    if (!success) {
      withdrawnDividends[user] = withdrawnDividends[user].sub(dividends);
      return 0;
    }
    return dividends;
  }
}
