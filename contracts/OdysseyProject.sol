// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.11;

import "./Odyssey.sol";
import "./RewardsTracker.sol";

contract OdysseyProject is RewardsTracker {
  using SafeMath for uint256;
  using SafeMathInt for int256;

  struct Holder {
    uint256 index;
    uint256 share;
  }

  uint256 public holders = 0;
  uint256 public currentHolder = 0;
  mapping (uint256 => address) public holderAt;
  mapping (address => Holder) public holder;

  Odyssey public odyssey;

  uint256 public dividends = 10;
  uint256 public dividendsInBNB = 0;
  uint256 public funds = 0;
  address public ceo1 = address(0);
  address public ceo2 = address(0);
  address public cfo1 = address(0);
  address public cfo2 = address(0);

  uint256 public minimumBalance = 10_000_000 ether; // 10M TOKENS REQ FOR DIVIDENDS

  struct VoteOfficer {
    address from;
    address to;
    bool voted;
  }

  struct VoteContract {
    address to;
    bool voted;
  }

  struct VoteFunds {
    address to;
    uint256 amount;
    bool voted;
  }

  mapping (address => VoteContract) public voteContract;
  mapping (address => VoteOfficer) public voteOfficer;
  mapping (address => VoteFunds) public voteFunds;

  event ClaimsProcessed(uint256 iterations, uint256 claims, uint256 lastIndex, uint256 gasUsed);
  event ContractChanged(address from, address to);
  event ContractVote(address officer, address to);
  event ContractVoteReset();
  event FundsApproved(address to, uint256 amount);
  event FundsRequest(address officer, address to, uint256 amount);
  event FundsRequestReset();
  event OfficerChanged(address from, address to);
  event OfficerVote(address officer, address from, address to);
  event OfficerVoteReset();
  event MinimumBalanceChanged(uint256 from, uint256 to);

  constructor() RewardsTracker() { }

  modifier onlyOfficer() {
    require(msg.sender==ceo1 || msg.sender==ceo2 || msg.sender==cfo1 || msg.sender==cfo2, "Invalid Officer");
    _;
  }

  function getReport() public view returns (uint256 holderCount, uint256 totalDollars, uint256 totalDividends) {
    holderCount = holders;
    totalDollars = totalBalance;
    totalDividends = totalDistributed;
  }

  function getReportAccount(address key) public view returns (address account, uint256 index, uint256 shares, uint256 dividendsEarned, uint256 dividendsClaimed) {
    account = key;
    index = holder[account].index;
    shares = balanceOf[account];
    dividendsEarned = getAccumulated(account);
    dividendsClaimed = withdrawnRewards[account];
  }

  function getReportAccountAt(uint256 indexOf) public view returns (address account, uint256 index, uint256 shares, uint256 dividendsEarned, uint256 dividendsClaimed) {
    require(indexOf > 0 && indexOf <= holders, "Value invalid");

    return getReportAccount(holderAt[indexOf]);
  }

  function processClaims(uint256 gas) external {
    if (holders==0) return;

    uint256 gasUsed = 0;
    uint256 gasLeft = gasleft();
    uint256 iterations = 0;
    uint256 claims = 0;

    while (gasUsed < gas && iterations <= holders) {
      currentHolder = (currentHolder % holders) + 1;
      if (pushFunds(payable(holderAt[currentHolder]))) claims++;
      iterations++;
      uint256 newGasLeft = gasleft();
      if (gasLeft > newGasLeft) gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
      gasLeft = newGasLeft;
    }

    emit ClaimsProcessed(iterations, claims, currentHolder, gasUsed);
  }

  function replaceContract(address to) external onlyOfficer {
    voteContract[msg.sender].to = to;
    voteContract[msg.sender].voted = true;
    emit ContractVote(msg.sender, to);

    bool unanimous = (voteContract[ceo1].to==to && voteContract[ceo2].to==to && voteContract[cfo1].to==to && voteContract[cfo2].to==to);

    if (unanimous) {
      odyssey.setProjectWallet(to);
      emit ContractChanged(address(this), to);
    }

    bool disagree = (voteContract[ceo1].voted && voteContract[ceo1].to!=to) ||
                    (voteContract[ceo2].voted && voteContract[ceo2].to!=to) ||
                    (voteContract[cfo1].voted && voteContract[cfo1].to!=to) ||
                    (voteContract[cfo2].voted && voteContract[cfo2].to!=to);

    if (unanimous || disagree) {
      delete voteContract[ceo1];
      delete voteContract[ceo2];
      delete voteContract[cfo1];
      delete voteContract[cfo2];
      if (disagree) emit ContractVoteReset();
    }
  }

  function replaceOfficer(address from, address to) external onlyOfficer {
    require(from!=address(0) && to!=address(0), "Value invalid");
    require(from!=msg.sender && to!=msg.sender, "Value invalid");
    require(from==ceo1 || from==ceo2 || from==cfo1 || from==cfo2, "Invalid Officer");
    require(to!=ceo1 || to!=ceo2 || to!=cfo1 || to!=cfo2, "Existing Officer");

    voteOfficer[msg.sender].from = from;
    voteOfficer[msg.sender].to = to;
    voteOfficer[msg.sender].voted = true;
    emit OfficerVote(msg.sender, from, to);

    bool unanimous =
      (from==ceo1 || voteOfficer[ceo1].from==from && voteOfficer[ceo1].to==to) &&
      (from==ceo2 || voteOfficer[ceo2].from==from && voteOfficer[ceo2].to==to) &&
      (from==cfo1 || voteOfficer[cfo1].from==from && voteOfficer[cfo1].to==to) &&
      (from==cfo2 || voteOfficer[cfo2].from==from && voteOfficer[cfo2].to==to);

    if (unanimous) { // unanimous
      if (from==ceo1) ceo1 = to;
      if (from==ceo2) ceo2 = to;
      if (from==cfo1) cfo1 = to;
      if (from==cfo2) cfo2 = to;
      emit OfficerChanged(from, to);
    }

    bool disagree =
      (voteOfficer[ceo1].voted && (voteOfficer[ceo1].from!=from || voteOfficer[ceo1].to!=to)) ||
      (voteOfficer[ceo2].voted && (voteOfficer[ceo2].from!=from || voteOfficer[ceo2].to!=to)) ||
      (voteOfficer[cfo1].voted && (voteOfficer[cfo1].from!=from || voteOfficer[cfo1].to!=to)) ||
      (voteOfficer[cfo2].voted && (voteOfficer[cfo2].from!=from || voteOfficer[cfo2].to!=to));

    if (unanimous || disagree) {
      delete voteOfficer[ceo1];
      delete voteOfficer[ceo2];
      delete voteOfficer[cfo1];
      delete voteOfficer[cfo2];
      if (disagree) emit OfficerVoteReset();
    }
  }

  function requestFunds(address to, uint256 amount) external onlyOfficer {
    require(funds > amount, "Overdraft");

    voteFunds[msg.sender].to = to;
    voteFunds[msg.sender].amount = amount;
    voteFunds[msg.sender].voted = true;
    emit FundsRequest(msg.sender, to, amount);

    // IF CEO IS REQUESTING, CHECK IF EITHER CFO APPROVED AND VISE VERSA
    bool approved = (msg.sender==ceo1 || msg.sender==ceo2) ?
                    (voteFunds[cfo1].to==to && voteFunds[cfo1].amount==amount) || (voteFunds[cfo2].to==to && voteFunds[cfo2].amount==amount) :
                    (voteFunds[ceo1].to==to && voteFunds[ceo1].amount==amount) || (voteFunds[ceo2].to==to && voteFunds[ceo2].amount==amount);

    if (approved) {
      funds -= amount;
      (bool success,) = payable(to).call{ value: amount, gas: 3000 }("");
      if (success) {
        emit FundsApproved(to, amount);
      } else {
        funds += amount;
      }
    }

    bool disagree = (voteFunds[ceo1].voted && (voteFunds[ceo1].to!=to || voteFunds[ceo1].amount!=amount)) ||
                    (voteFunds[ceo2].voted && (voteFunds[ceo2].to!=to || voteFunds[ceo2].amount!=amount)) ||
                    (voteFunds[cfo1].voted && (voteFunds[cfo1].to!=to || voteFunds[cfo1].amount!=amount)) ||
                    (voteFunds[cfo2].voted && (voteFunds[cfo2].to!=to || voteFunds[cfo2].amount!=amount));

    if (approved || disagree) {
      delete voteFunds[ceo1];
      delete voteFunds[ceo2];
      delete voteFunds[cfo1];
      delete voteFunds[cfo2];
      if (disagree) emit FundsRequestReset();
    }
  }

  function setHolders(address[] memory wallets, uint256[] memory dollars) external onlyOwner {
    require(totalBalance==0, "Shares already set.");
    require(wallets.length < 100, "100 wallets max");

    for (uint256 idx=0;idx<wallets.length;idx++) {
      setHolder(wallets[idx], dollars[idx]);
    }

    dividendsInBNB = (totalBalance * 1 ether).div(333); // FOR EACH 1K DOLLARS RETURN 3 BNB TO INVESTORS - ADJUST TO CURRENT BNB PRICE AT LAUNCH
  }

  function setOfficers(address[] memory wallets) external onlyOwner {
    require(ceo1==address(0), "Officers already set");
    require(wallets.length==4, "4 Officers required");

    ceo1 = wallets[0];
    ceo2 = wallets[1];
    cfo1 = wallets[2];
    cfo2 = wallets[3];
  }

  function setMinimumBalance(uint256 amount) external onlyOfficer {
    require(amount >= 1_000_000 && amount <= 10_000_000, "Value invalid");
    uint256 balance = (amount * 1 ether);
    require(balance != minimumBalance, "Value unchanged");
    require(minimumBalance > balance, "Value cannot increase");

    emit MinimumBalanceChanged(minimumBalance, balance);
    minimumBalance = balance;
  }

  function setToken(address token) external onlyOwner {
    require(address(odyssey)==address(0), "Token already set");

    odyssey = Odyssey(payable(token));
  }

  function withdrawFunds(address payable account) public override {
    require(getPending(account) > 0, "No funds");

    verifyMinimumBalance(account);
    super.withdrawFunds(account);
  }

  // PRIVATE

  function distributeFunds(uint256 amount) internal override {
    if (totalDistributed > dividendsInBNB) { // PAID IN FULL, NO MORE DISTRIBUTIONS
      funds += amount;
      return;
    }
    uint256 share = amount.mul(dividends).div(100);
    funds += amount.sub(share);
    super.distributeFunds(share);
  }

  function holderSet(address key, uint256 share) internal {
    if (holder[key].index==0) {
      holders++;
      holderAt[holders] = key;
      holder[key].index = holders;
    }
    holder[key].share = share;
  }

  function setHolder(address account, uint256 dollars) internal {
    putBalance(account, dollars);
    holderSet(account, dollars);
  }

  function pushFunds(address payable account) internal returns (bool) {
    verifyMinimumBalance(account);

    if (getPending(account)==0) return false;

    super.withdrawFunds(account);

    return true;
  }

  function verifyMinimumBalance(address account) internal {
    if (minimumBalance==0) return;

    if (balanceOf[account] > 0 && odyssey.balanceOf(account) < minimumBalance) {
      putBalance(account, 0);
    } else if (balanceOf[account] == 0 && odyssey.balanceOf(account) >= minimumBalance) {
      putBalance(account, holder[account].share);
    }
  }
}
