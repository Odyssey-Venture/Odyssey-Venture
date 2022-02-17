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

  it('allows owner to update tracker', async function() {
    let newTracker = await OdysseyRewards.new('OdysseyRewards', 'ODSYRV2', {from: owner });
    await newTracker.transferOwnership(contract.address, { from: owner });
    transaction = await contract.setRewardsTracker(newTracker.address);
    expectEvent(transaction, 'RewardsTrackerChanged', { from: tracker.address, to: newTracker.address });
    assert.equal(await contract.odysseyRewards(), newTracker.address);
    tracker = await OdysseyRewards.at(await contract.odysseyRewards());
    assert.equal(await tracker.symbol(), 'ODSYRV2');
  });

});
