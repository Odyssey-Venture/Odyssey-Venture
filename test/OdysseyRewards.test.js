// test/Odyssey.test.js
const OdysseyRewards = artifacts.require('./OdysseyRewards.sol');

const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

var chai = require('chai');

const assert = chai.assert;
const expect = chai.expect;

const one_hour = 60 * 60;
const six_hours = 6 * one_hour;
const two_hours = 2 * one_hour;
const one_day = 24 *one_hour;

function toWei(count) {
  return `${count}000000000000000000`;
}

function findEvent(transaction, event) {
  for (const log of transaction.logs) if (log.event==event) return log;
  return {};
}

function eventArgs(transaction, name) {
  return findEvent(transaction, name).args;
}


function timeTravel(addSeconds) {
  const id = Date.now();

  return new Promise((resolve, reject) => {
    web3.currentProvider.send({
      jsonrpc: '2.0',
      method: 'evm_increaseTime',
      params: [ addSeconds ],
      id
    }, (err1) => {
      if (err1) return reject(err1);

      web3.currentProvider.send({
        jsonrpc: '2.0',
        method: 'evm_mine',
        id: id + 1
      }, (err2, res) => (err2 ? reject(err2) : resolve(res)));
    });
  });
}

contract('OdysseyRewards', function (accounts) {
  const [owner, holder1, holder2, holder3, holder4, holder5, holder6, holder7, holder8, holder9] = accounts;
  let contract;
  let transaction;

  beforeEach('setup contract for each test', async function() {
    contract = await OdysseyRewards.new('TestRewards', 'TST$');
  });

  it('has a name and symbol', async function () {
    assert.equal(await contract.name(), 'TestRewards');
    assert.equal(await contract.symbol(), 'TST$');
  });

  it('has a waiting period between reward claims', async function () {
    assert.equal(await contract.waitingPeriod(), six_hours);
  });

  it('allows only owner to set waiting period', async function () {
    await expectRevert(contract.setWaitingPeriod(two_hours, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to set waiting period', async function () {
    transaction = await contract.setWaitingPeriod(two_hours, { from: owner });
    expectEvent(transaction, 'WaitingPeriodChanged', { from: six_hours.toString(), to: two_hours.toString() });
    assert.equal(await contract.waitingPeriod(), two_hours);
  });

  it('requires the value of WaitingPeriod to change if updated', async function () {
    await expectRevert(contract.setWaitingPeriod(six_hours, { from: owner }), 'Value unchanged');
  });

  it('requires waiting period betweeen 1 hour to 1 day', async function () {
    await expectRevert(contract.setWaitingPeriod(one_hour - 1, { from: owner }), 'Value invalid');
    await expectRevert(contract.setWaitingPeriod(one_day + 1, { from: owner }), 'Value invalid');
  });

  it('allows holders to withdraw once per wait period', async function () {
    await contract.putBalance(holder1, 1, { from: owner });
    await contract.send(toWei(1), { from: owner });
    transaction = await contract.withdrawFunds(holder1);
    expectEvent(transaction, 'FundsWithdrawn', { account: holder1, amount: toWei(1) });
    await contract.send(toWei(1), { from: owner });
    await expectRevert(contract.withdrawFunds(holder1), 'Wait time active');
    await timeTravel(six_hours);
    transaction = await contract.withdrawFunds(holder1);
    expectEvent(transaction, 'FundsWithdrawn', { account: holder1, amount: toWei(1) });
  });

  it('has a minimum balance to earn rewards', async function () {
    assert.equal(await contract.minimumBalance(), 10_000_000);
  });

  it('allows only owner to set minimum balance', async function () {
    await expectRevert(contract.setMinimumBalance(1_000_000, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to set minimum balance', async function () {
    transaction = await contract.setMinimumBalance(1_000_000, { from: owner });
    expectEvent(transaction, 'MinimumBalanceChanged', { from: '10000000', to: '1000000' });
    assert.equal(await contract.minimumBalance(), 1_000_000);
  });

  it('requires the value of MinimumBalance to change if updated', async function () {
    await expectRevert(contract.setMinimumBalance(10_000_000, { from: owner }), 'Value unchanged');
  });

  it('allows only owner to exclude account from earning rewards', async function () {
    await expectRevert(contract.setExcludedAddress(holder1, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows only owner to allow account to earn rewards', async function () {
    await expectRevert(contract.setIncludedAddress(holder1, 0, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to exclude account from earning rewards', async function () {
    transaction = await contract.setExcludedAddress(holder1, { from: owner });
    expectEvent(transaction, 'IsExcludedChanged', { account: holder1, excluded: true });
    assert.isTrue(await contract.isExcluded(holder1));
  });

  it('requires the value of ExcludedAddress to change if updated', async function () {
    await contract.setExcludedAddress(holder1, { from: owner });
    await expectRevert(contract.setExcludedAddress(holder1, { from: owner }), 'Value unchanged');
  });

  it('allows owner to allow account to earn rewards', async function () {
    await contract.setExcludedAddress(holder1, { from: owner });
    transaction = await contract.setIncludedAddress(holder1, 0, { from: owner });
    expectEvent(transaction, 'IsExcludedChanged', { account: holder1, excluded: false });
    assert.isFalse(await contract.isExcluded(holder1));
  });

  it('requires the value of IncludedAddress to change if updated', async function () {
    await expectRevert(contract.setIncludedAddress(holder1, 0, { from: owner }), 'Value unchanged');
  });

  it('zeroes out tracked balance when excluding an account', async function () {
    await contract.setBalance(holder1, toWei(10_000_000), { from: owner });
    await contract.setExcludedAddress(holder1, { from: owner });
    expect(await contract.balanceOf(holder1)).to.be.a.bignumber.equal(toWei(0));
  });

  it('updates tracked balance when including an account', async function () {
    await contract.setExcludedAddress(holder1, { from: owner });
    await contract.setIncludedAddress(holder1, toWei(10_000_000), { from: owner });
    expect(await contract.balanceOf(holder1)).to.be.a.bignumber.equal(toWei(10_000_000));
  });

  it('allows only owner to set balance of an account', async function () {
    await expectRevert(contract.setBalance(holder1, 10_000_000, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to set balance of an account', async function () {
    await contract.setBalance(holder1, toWei(10_000_000), { from: owner });
    expect(await contract.balanceOf(holder1)).to.be.a.bignumber.equal(toWei(10_000_000));
  });

  it('requires balance of an account to be above minimum', async function () {
    await contract.setBalance(holder1, toWei(1_000), { from: owner });
    expect(await contract.balanceOf(holder1)).to.be.a.bignumber.equal('0');
  });

  it('tracks accounts that are over minimum balance', async function () {
    await contract.setBalance(holder1, toWei(10_000_000), { from: owner });
    assert.equal(await contract.getHolderCount(), 1);
  });

  it('does not track accounts under minimum balance', async function () {
    await contract.setBalance(holder1, toWei(1_000), { from: owner });
    assert.equal(await contract.getHolderCount(), 0);
  });

  it('stops tracking accounts that fall under minimum balance', async function () {
    await contract.setBalance(holder1, toWei(10_000_000), { from: owner });
    assert.equal(await contract.getHolderCount(), 1);
    await contract.setBalance(holder1, toWei(1_000), { from: owner });
    assert.equal(await contract.getHolderCount(), 0);
  });

  it('allows tracker settings to be read', async function () {
    await contract.setBalance(holder1, toWei(10_000_000), { from: owner });
    await contract.send(toWei(2), { from: holder4 });
    let data = await contract.getSettings();
    assert.equal(data.rewardsDistributed,  toWei(2));
    assert.equal(data.minBalance, 10_000_000);
    assert.equal(data.waitPeriodSeconds, six_hours);
    assert.equal(data.holderCount, 1);
    assert.equal(data.nextIndex, 0);
  });

  it('allows holder to view an account status report', async function () {
    await contract.setBalance(holder2, toWei(10_000_000), { from: owner });
    await contract.setBalance(holder1, toWei(10_000_000), { from: owner });
    await contract.send(toWei(2), { from: holder3 });
    await contract.withdrawFunds(holder1);
    let data = await contract.getReport(holder1);
    assert.isFalse(data.accountExcluded);
    assert.equal(data.accountIndex, 1);
    assert.equal(data.nextIndex, 0);
    assert.equal(data.trackedBalance, toWei(10_000_000));
    assert.equal(data.totalRewards.toString(), data.claimedRewards.toString());
    assert.equal(data.pendingRewards, 0);
    assert.equal(data.lastClaimTime.add(data.secondsRemaining).toString(), data.nextClaimTime.toString());
    assert.equal(data.secondsRemaining, six_hours);
  });

  it('allows excluded holder to view an account status report', async function () {
    await contract.putBalance(holder1, 1, { from: owner });
    await contract.send(toWei(1), { from: holder1 });
    await contract.setExcludedAddress(holder1, { from: owner });
    let data = await contract.getReport(holder1);
    assert.isTrue(data.accountExcluded);
    assert.equal(data.accountIndex, 0);
    assert.equal(data.nextIndex, 0);
    assert.equal(data.trackedBalance, '0');
    assert.equal(data.totalRewards.toString(), toWei(1));
    assert.equal(data.pendingRewards.toString(), toWei(1));
    assert.equal(data.claimedRewards, '0');
    assert.equal(data.lastClaimTime, 0);
    assert.equal(data.nextClaimTime, 0);
    assert.equal(data.secondsRemaining, 0);
  });

  it('allows holder withdraw earned rewards', async function () {
    await contract.putBalance(holder1, 1, { from: owner });
    await contract.send(toWei(1), { from: holder1 });
    transaction = await contract.withdrawFunds(holder1);
    expectEvent(transaction, 'FundsWithdrawn', { account: holder1, amount: toWei(1) });
  });

  it('allows excluded holder withdraw earned rewards', async function () {
    await contract.putBalance(holder1, 1, { from: owner });
    await contract.send(toWei(1), { from: holder3 });
    await contract.setExcludedAddress(holder1, { from: owner });
    transaction = await contract.withdrawFunds(holder1);
    expectEvent(transaction, 'FundsWithdrawn', { account: holder1, amount: toWei(1) });
  });


  it('properly bulk processes holders using index', async function () {
    await contract.setMinimumBalance(1, { from: owner });
    await contract.setBalance(holder1, toWei(10), { from: owner });
    await contract.setBalance(holder2, toWei(15), { from: owner });
    await contract.setBalance(holder3, toWei(25), { from: owner });
    await contract.setBalance(holder4, toWei(11), { from: owner });
    await contract.setBalance(holder5, toWei(22), { from: owner });
    await contract.setBalance(holder6, toWei(17), { from: owner });

    assert.equal(await contract.getHolderCount(), 6);
    assert.equal(await contract.totalBalance(), toWei(100));
    assert.equal(await contract.lastIndex(), 0);

    await contract.send(toWei(25), { from: holder6 });
    await contract.send(toWei(25), { from: holder7 });
    await contract.send(toWei(25), { from: holder8 });
    await contract.send(toWei(25), { from: holder9 });

    let before = [
      await web3.eth.getBalance(holder2),
      await web3.eth.getBalance(holder3),
      await web3.eth.getBalance(holder4),
      await web3.eth.getBalance(holder5)
    ];

    transaction = await contract.processClaims(200_000); // 4 iterations
    expectEvent(transaction, 'ClaimsProcessed');

    let args = eventArgs(transaction, 'ClaimsProcessed');
    let iterations = args.iterations.toString();
    console.log(`Processing cost ${args.gasUsed.toString()}`);

    let after = [
      await web3.eth.getBalance(holder2),
      await web3.eth.getBalance(holder3),
      await web3.eth.getBalance(holder4),
      await web3.eth.getBalance(holder5)
    ];

    after[0] = (after[0] - before[0]) / toWei(1);
    after[1] = (after[1] - before[1]) / toWei(1);
    after[2] = (after[2] - before[2]) / toWei(1);
    after[3] = (after[3] - before[3]) / toWei(1);

    expect(after[0]).to.be.equal(15);
    expectEvent(transaction, 'FundsWithdrawn', { account: holder2, amount: toWei(15) });
    expect(after[1]).to.be.equal(25);
    expectEvent(transaction, 'FundsWithdrawn', { account: holder3, amount: toWei(25) });
    expect(after[2]).to.be.equal(11);
    expectEvent(transaction, 'FundsWithdrawn', { account: holder4, amount: toWei(11) });
    if (iterations>3) {
      expect(after[3]).to.be.equal(22);
      expectEvent(transaction, 'FundsWithdrawn', { account: holder5, amount: toWei(22) });
    }
  });
});
