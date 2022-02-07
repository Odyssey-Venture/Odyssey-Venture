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
  minTrackerBalance: 10_000_000,
  maxTrackerBalance: 100_000_000
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
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
  });

  it('has publically viewable tracker', async function() {
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
    assert.equal(await tracker.name(), 'OdysseyRewards');
  });

  it('allows requires the contract to own to update tracker', async function() {
    let newTracker = await OdysseyRewards.new('OdysseyRewards', 'ODSYRV2');
    await expectRevert(contract.setRewardsTracker(newTracker.address, { from: owner }), 'Token must own tracker');
  });

  it('allows owner to update tracker', async function() {
    let newTracker = await OdysseyRewards.new('OdysseyRewards', 'ODSYRV2');
    // console.log(await tracker.owner());
    // console.log(await tracker.address);
    // await newTracker.transferOwnership(tracker.address, { from: tracker.owner() });
    // transaction = await contract.setRewardsTracker(newTracker);
    // expectEvent(transaction, 'RewardsTrackerChanged', { from: owner, to: contract });
    // assert.equal(await contract.odysseyRewards(), newTracker);
    // assert.equal(await tracker.symbol(), 'ODSYRV2');
  });

  it('requires the value of RewardsTracker to change if updated', async function() {
    await expectRevert(contract.setRewardsTracker(tracker, { from: owner }), 'Value unchanged');
  });

  it('can read tracker settings', async function() {
    await contract.transfer(holder1, toWei(defaults.minTrackerBalance), { from: owner });
    let data = await contract.getRewardsSettings();
    assert.equal(data.holderCount, 1);
  });

  it('can read tracker rewards report', async function() {
    await contract.transfer(holder1, toWei(defaults.minTrackerBalance), { from: owner });
    let data = await contract.getRewardsReport(holder1);
    assert.equal(data.trackedBalance, toWei(defaults.minTrackerBalance));
  });

  it('allows only owner to in/exclude account from rewards', async function () {
    await expectRevert(contract.setRewardsExcludedAddress(holder1, false, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to exclude account from earning rewards', async function () {
    transaction = await contract.setRewardsExcludedAddress(holder1, true, { from: owner });
    expectEvent.inTransaction(transaction.tx, tracker, 'IsExcludedChanged', { account: holder1, excluded: true });
    assert.isTrue((await contract.getRewardsReport(holder1)).accountExcluded);
  });

  it('clears tracker balance when excluding an account from earning rewards', async function () {
    await contract.transfer(holder1, toWei(defaults.minTrackerBalance), { from: owner });
    await contract.setRewardsExcludedAddress(holder1, true, { from: owner });
    assert.equal((await contract.getRewardsReport(holder1)).trackedBalance, '0');
  });

  it('allows owner to include account for earning rewards', async function () {
    await contract.setRewardsExcludedAddress(holder1, true, { from: owner });
    transaction = await contract.setRewardsExcludedAddress(holder1, false, { from: owner });
    expectEvent.inTransaction(transaction.tx, tracker, 'IsExcludedChanged', { account: holder1, excluded: false });
    // assert.isFalse((await contract.getRewardsReport(holder1)).accountExcluded);
  });

  it('sets tracker balance when including an account for earning rewards', async function () {
    await contract.transfer(holder1, toWei(defaults.minTrackerBalance), { from: owner });
    await contract.setRewardsExcludedAddress(holder1, true, { from: owner });
    await contract.setRewardsExcludedAddress(holder1, false, { from: owner });
    assert.equal((await contract.getRewardsReport(holder1)).trackedBalance, toWei(defaults.minTrackerBalance));
  });

  it('allows only owner to set minimum balance', async function () {
    await expectRevert(contract.setRewardsMinimumBalance(defaults.minTrackerBalance, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to set minimum balance', async function () {
    transaction = await contract.setRewardsMinimumBalance(defaults.minTrackerBalance+1, { from: owner });
    expectEvent.inTransaction(transaction.tx, tracker, 'MinimumBalanceChanged', { from: '10000000', to: '10000001' });
  });

  it('requires owner to set a valid minimum balance', async function () {
    await expectRevert(contract.setRewardsMinimumBalance(defaults.minTrackerBalance-1, { from: owner }), 'Value invalid');
    await expectRevert(contract.setRewardsMinimumBalance(defaults.maxTrackerBalance+1, { from: owner }), 'Value invalid');
  });

  it('allows only owner to set waiting period', async function () {
    await expectRevert(contract.setRewardsWaitingPeriod(two_hours, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('allows owner to set waiting period', async function () {
    transaction = await contract.setRewardsWaitingPeriod(two_hours, { from: owner });
    expectEvent.inTransaction(transaction.tx, tracker, 'WaitingPeriodChanged', { from: six_hours.toString(), to: two_hours.toString() });
  });

  it('allows holder withdraw earned rewards', async function () {
    await contract.transfer(holder1, toWei(defaults.minTrackerBalance), { from: owner });
    await tracker.send(toWei(1), { from: holder1 });
    transaction = await contract.withdrawRewardsFunds({ from: holder1 });
    expectEvent.inTransaction(transaction.tx, tracker, 'FundsWithdrawn', { account: holder1 });
  });

  it('allows bulk processing of earned reward withdraws', async function () {
    await contract.transfer(holder1, toWei(defaults.minTrackerBalance), { from: owner });
    await contract.transfer(holder2, toWei(defaults.minTrackerBalance), { from: owner });
    await tracker.send(toWei(1), { from: holder1 });
    transaction = await contract.processRewardsClaims({ from: owner });
    expectEvent.inTransaction(transaction.tx, tracker, 'ClaimsProcessed', { claims: '2' });
  });
});
