// test/Odyssey.test.js
const Odyssey = artifacts.require('./Odyssey.sol');
const OdysseyRewards = artifacts.require('./OdysseyRewards.sol');

const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

var chai = require('chai');
const assert = chai.assert;

contract('Odyssey', function (accounts) {
  const [owner, holder1, holder2, holder3] = accounts;
  let contract;
  let transaction;
  let uniswapV2Pair;
  let tracker;

  beforeEach('setup contract for each test', async function() {
    contract = await Odyssey.new();
    uniswapV2Pair = await contract.uniswapV2Pair();
    tracker = await OdysseyRewards.new("OdysseyRewards", "ODSYRV1");
    await tracker.transferOwnership(contract.address, { from: owner });
    await contract.setRewardsTracker(tracker.address);
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
