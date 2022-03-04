const Odyssey = artifacts.require('./Odyssey.sol');
const OdysseyRewards = artifacts.require('./OdysseyRewards.sol');

const { expectRevert } = require('@openzeppelin/test-helpers');
var chai = require('chai');
const assert = chai.assert;

contract('Odyssey', function (accounts) {
  const [owner, holder1, holder2, holder3] = accounts;
  let contract;

  beforeEach('setup contract for each test', async function() {
    contract = await Odyssey.new();
    tracker = await OdysseyRewards.new("OdysseyRewards", "ODSYRV1");
    await tracker.transferOwnership(contract.address, { from: owner });
    await contract.setRewardsTracker(tracker.address);
  });

  it('allows only owner to turn staking on', async function () {
    await expectRevert(contract.setRewardsStaking(true, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('requires the value of staking on to change if updated', async function () {
    await expectRevert(contract.setRewardsStaking(false, { from: owner }), 'Value unchanged');
  });

  it('allows owner to toggle staking option for contract', async function () {
    await contract.setRewardsStaking(true, { from: owner });
    let data = await contract.getRewardsReport({ from: owner });
    assert.isTrue(data.stakingOn);
  });
});
