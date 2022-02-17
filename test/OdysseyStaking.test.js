// test/Odyssey.test.js
const Odyssey = artifacts.require('./Odyssey.sol');

const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');
var chai = require('chai');
const assert = chai.assert;

function toWei(count) {
  return `${count}000000000000000000`;
}

contract('Odyssey', function (accounts) {
  const [owner, holder1, holder2, holder3] = accounts;
  let contract;

  beforeEach('setup contract for each test', async function() {
    contract = await Odyssey.new();
  });

  it('allows only owner to turn staking on', async function () {
    await expectRevert(contract.setStaking(true, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('requires the value of staking on to change if updated', async function () {
    await expectRevert(contract.setStaking(false, { from: owner }), 'Value unchanged');
  });

  it('allows owner to toggle staking option for contract', async function () {
    await contract.setStaking(true, { from: owner });
    assert.isTrue(await contract.isStakingOn());
  });

  it('only the holder can toggle staking option', async function () {
    await expectRevert(contract.setRewardsStaking(holder1, true, { from: owner }), 'Value invalid');
    assert.isFalse(await contract.isStaked(holder1));
  });

  it('holder can only turn on staking if rewards staking is on', async function () {
    await expectRevert(contract.setRewardsStaking(holder1, true, { from: holder1 }), 'Rewards staking not active');
    assert.isFalse(await contract.isStaked(holder1));
  });

  it('holder can only turn on staking if min tokens held', async function () {
    await contract.setStaking(true, { from: owner });
    await expectRevert(contract.setRewardsStaking(holder1, true, { from: holder1 }), 'Rewards staking not available');
    assert.isFalse(await contract.isStaked(holder1));
  });

  it('holder can turn on staking if min tokens held', async function () {
    await contract.setStaking(true, { from: owner });
    await contract.transfer(holder1, toWei(10_000_000), { from: owner });
    await contract.setRewardsStaking(holder1, true, { from: holder1 })
    assert.isTrue(await contract.isStaked(holder1));
  });

  it('holder can turn off staking without conditions', async function () {
    await contract.setStaking(true, { from: owner });
    await contract.transfer(holder1, toWei(10_000_000), { from: owner });
    await contract.setRewardsStaking(holder1, true, { from: holder1 });
    assert.isTrue(await contract.isStaked(holder1));
    await contract.setStaking(false, { from: owner });
    await contract.setRewardsStaking(holder1, false, { from: holder1 });
    assert.isFalse(await contract.isStaked(holder1));
  });

  it('holder cannot reduce balance while staked', async function() {
    await contract.setStaking(true, { from: owner });
    await contract.transfer(holder1, toWei(10_000_000), { from: owner });
    await contract.setPresale(holder1, true, { from: owner });
    await contract.setRewardsStaking(holder1, true, { from: holder1 });
    await expectRevert(contract.transfer(holder2, toWei(10_000_000), { from: holder1 }), 'Account is staked for rewards');
    assert.equal(await contract.balanceOf(holder1), toWei(10_000_000));
    await contract.setRewardsStaking(holder1, false, { from: holder1 });
    await contract.transfer(holder2, toWei(10_000_000), { from: holder1 });
    assert.equal(await contract.balanceOf(holder2), toWei(10_000_000));
  });
});
