// test/Odyssey.test.js
const Odyssey = artifacts.require('./Odyssey.sol');
const OdysseyRewards = artifacts.require('./OdysseyRewards.sol');

const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

var chai = require('chai');
const assert = chai.assert;

const defaults = {
  totalSupply: 50_000_000_000,
  maxWallet: 5_000_000_000,
  maxSell: 500_000_000,
  swapThreshold: 100_000_000,
  minTrackerBalance: 1_000_000,
  maxTrackerBalance: 15_000_000
};

const one_hour = 60 * 60;
const six_hours = 6 * one_hour;
const two_hours = 2 * one_hour;
const one_day = 24 *one_hour;

function toWei(count) {
  return `${count}000000000000000000`;
}

contract('Odyssey', function (accounts) {
  const [owner, holder1, holder2, holder3] = accounts;
  let contract;
  let transaction;
  let uniswapV2Pair;
  let tracker;

  const wallets = {
    project: '0xfB0f7207B2e682c8a7A6bdb2b2012a395a653584',
    liquidity: owner
  };

  beforeEach('setup contract for each test', async function() {
    contract = await Odyssey.new();
    uniswapV2Pair = await contract.uniswapV2Pair();
  });

  it('has publically viewable tracker', async function() {
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
    assert.equal(await tracker.name(), 'OdysseyRewards');
  });

  it('allows requires the contract to own new tracker', async function() {
    let newTracker = await OdysseyRewards.new('OdysseyRewards', 'ODSYRV2');
    await expectRevert(contract.setRewardsTracker(newTracker.address, { from: owner }), 'Token must own tracker');
  });

  it('allows owner to update tracker', async function() {
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
    let newTracker = await OdysseyRewards.new('OdysseyRewards', 'ODSYRV2', {from: owner });
    await newTracker.transferOwnership(contract.address, { from: owner });
    transaction = await contract.setRewardsTracker(newTracker.address);
    expectEvent(transaction, 'RewardsTrackerChanged', { from: tracker.address, to: newTracker.address });
    assert.equal(await contract.odysseyRewards(), newTracker.address);
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
    assert.equal(await tracker.symbol(), 'ODSYRV2');
  });

  it('requires the value of RewardsTracker to change if updated', async function() {
    await expectRevert(contract.setRewardsTracker(tracker, { from: owner }), "Value unchanged");
  });

  it('can read tracker settings', async function() {
    await contract.transfer(holder1, toWei(defaults.maxTrackerBalance), { from: owner });
    let data = await contract.getRewardsReport();
    assert.equal(data.holderCount, 1);
  });

  it('can read tracker rewards report', async function() {
    await contract.transfer(holder1, toWei(defaults.maxTrackerBalance), { from: owner });
    let data = await contract.getRewardsReportAccount(holder1);
    assert.equal(data.tokens, toWei(defaults.maxTrackerBalance));
  });

  it('allows only owner to in/exclude account from rewards', async function () {
    await expectRevert(contract.setRewardsExcludedAddress(holder1, false, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to exclude account from earning rewards', async function () {
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
    transaction = await contract.setRewardsExcludedAddress(holder1, true, { from: owner });
    expectEvent.inTransaction(transaction.tx, tracker, 'ExcludedChanged', { account: holder1, excluded: true });
    assert.isTrue((await contract.getRewardsReportAccount(holder1)).excluded);
  });

  it('clears tracker balance when excluding an account from earning rewards', async function () {
    await contract.transfer(holder1, toWei(defaults.maxTrackerBalance), { from: owner });
    await contract.setRewardsExcludedAddress(holder1, true, { from: owner });
    assert.equal((await contract.getRewardsReportAccount(holder1)).tokens, '0');
  });

  it('allows owner to include account for earning rewards', async function () {
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
    await contract.setRewardsExcludedAddress(holder1, true, { from: owner });
    transaction = await contract.setRewardsExcludedAddress(holder1, false, { from: owner });
    expectEvent.inTransaction(transaction.tx, tracker, 'ExcludedChanged', { account: holder1, excluded: false });
  });

  it('sets tracker balance when including an account for earning rewards', async function () {
    await contract.transfer(holder1, toWei(defaults.maxTrackerBalance), { from: owner });
    await contract.setRewardsExcludedAddress(holder1, true, { from: owner });
    await contract.setRewardsExcludedAddress(holder1, false, { from: owner });
    assert.equal((await contract.getRewardsReportAccount(holder1)).tokens, toWei(defaults.maxTrackerBalance));
  });

  it('allows only owner to set minimum balance', async function () {
    await expectRevert(contract.setRewardsMinimumBalance(defaults.maxTrackerBalance, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to set minimum balance', async function () {
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
    transaction = await contract.setRewardsMinimumBalance(defaults.minTrackerBalance+1, { from: owner });
    expectEvent.inTransaction(transaction.tx, tracker, 'MinimumBalanceChanged', { from: toWei(defaults.maxTrackerBalance), to: toWei(defaults.minTrackerBalance+1) });
  });

  it('only allows minimum balance to be set lower than previous value', async function () {
    await contract.setRewardsMinimumBalance(10_000_000, { from: owner });
    await expectRevert(contract.setRewardsMinimumBalance(11_000_000, { from: owner }), 'Value cannot increase');
  });

  it('requires owner to set a valid minimum balance', async function () {
    await expectRevert(contract.setRewardsMinimumBalance(defaults.minTrackerBalance-1, { from: owner }), 'Value invalid');
    await expectRevert(contract.setRewardsMinimumBalance(defaults.maxTrackerBalance+1, { from: owner }), 'Value invalid');
  });

  it('allows only owner to set waiting period', async function () {
    await expectRevert(contract.setRewardsWaitingPeriod(two_hours, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to set waiting period', async function () {
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
    transaction = await contract.setRewardsWaitingPeriod(two_hours, { from: owner });
    expectEvent.inTransaction(transaction.tx, tracker, 'WaitingPeriodChanged', { from: six_hours.toString(), to: two_hours.toString() });
  });

  it('allows holder withdraw earned rewards', async function () {
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
    await contract.transfer(holder1, toWei(defaults.maxTrackerBalance), { from: owner });
    await tracker.send(toWei(1), { from: holder1 });
    transaction = await contract.withdrawRewards({ from: holder1 });
    expectEvent.inTransaction(transaction.tx, tracker, 'FundsWithdrawn', { account: holder1 });
  });

  it('allows bulk processing of earned reward withdraws', async function () {
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
    await contract.transfer(holder1, toWei(defaults.maxTrackerBalance), { from: owner });
    await contract.transfer(holder2, toWei(defaults.maxTrackerBalance), { from: owner });
    await tracker.send(toWei(1), { from: holder1 });
    transaction = await contract.processRewardsClaims({ from: owner });
    expectEvent.inTransaction(transaction.tx, tracker, 'ClaimsProcessed', { claims: '2' });
  });
});
