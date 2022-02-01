// test/Odyssey.test.js
const Odyssey = artifacts.require('./Odyssey.sol');
const OdysseyRewards = artifacts.require('./OdysseyRewards.sol');

const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

var chai = require('chai');

const chaiAlmost = require('chai-almost');
chai.use(chaiAlmost());

const BN = web3.utils.BN;
const chaiBN = require('chai-bn')(BN);
chai.use(chaiBN);

const assert = chai.assert;
const expect = chai.expect;

const secs_in_hour = 60 * 60;

function toWei(count) {
  return `${count}000000000000000000`;
}

contract('Odyssey', function (accounts) {
  const [owner, holder1, holder2, holder3] = accounts;
  let contract;
  let tracker;
  let transaction;

  beforeEach('setup contract for each test', async function() {
    contract = await Odyssey.new();
    let newTracker = await contract.odysseyRewards();
    tracker = await OdysseyRewards.at(newTracker);
    await contract.openToPublic();
  });

  it('has a tracker and owns it :snaps:', async function () {
    console.log('Checking contract has a tracker for rewards.');
    assert.equal(await tracker.owner(), contract.address, "Dude, where's my tracker?");
  });

  it('allows owner to exclude wallets from rewards', async function () {
    console.log('Checking only owner can exclude from rewards.');
    await expectRevert(contract.setRewardsExcludedAccount(holder1, true, { from: holder1 }), 'Ownable: caller is not the owner');
    assert.isFalse(await tracker.excludedAddresses(holder1));
    console.log('Checking owner can exclude from rewards.');
    transaction = await contract.setRewardsExcludedAccount(holder1, true, { from: owner });
    expectEvent.inTransaction(transaction.tx, tracker, 'ExcludedFromRewards', { account: holder1, isExcluded: true });
    assert.isTrue(await tracker.excludedAddresses(holder1), 'Wallet should be in exclusions');
    console.log('Checking same wallet cannot be excluded twice.');
    await expectRevert(contract.setRewardsExcludedAccount(holder1, true, { from: owner }), 'OdysseyRewards: Value already set');
    console.log('Checking owner can remove exclusion from rewards');
    transaction = await contract.setRewardsExcludedAccount(holder1, false, { from: owner });
    expectEvent.inTransaction(transaction.tx, tracker, 'ExcludedFromRewards', { account: holder1, isExcluded: false });
    assert.isFalse(await tracker.excludedAddresses(holder1), 'Wallet should not be in exclusions');
  });

  it('allows owner to set waiting period between reward claims', async function () {
    console.log('Checking only owner can change claim waiting period.');
    await expectRevert(contract.setRewardsClaimWaitingPeriod(100, { from: holder1 }), 'Ownable: caller is not the owner');
    console.log('Checking owner can change claim waiting period to a value between 1 hour and 1 day');
    await expectRevert(contract.setRewardsClaimWaitingPeriod(secs_in_hour - 1, { from: owner }), 'OdysseyRewards: claimWaitingPeriod must be between 1 and 24 hours');
    await expectRevert(contract.setRewardsClaimWaitingPeriod(secs_in_hour * 25, { from: owner }), 'OdysseyRewards: claimWaitingPeriod must be between 1 and 24 hours');
    transaction = await contract.setRewardsClaimWaitingPeriod(secs_in_hour * 3, { from: owner });
    expectEvent.inTransaction(transaction.tx, tracker, 'ClaimWaitingPeriodChanged', { from: '21600', to: '10800' });
  });

  it('allows owner to set minimum balance for earning rewards', async function () {
    console.log('Checking only owner can setRewardsMinimumBalance.');
    await expectRevert(contract.setRewardsMinimumBalance(20_000_000, { from: holder1 }), 'Ownable: caller is not the owner');
    console.log('Checking minimum balance for earning rewards has a minimum');
    await expectRevert(contract.setRewardsMinimumBalance(9_999_999, { from: owner }), 'Value invalid');
    await expectRevert(contract.setRewardsMinimumBalance(100_000_001, { from: owner }), 'Value invalid');
    console.log('Checking owner can change setRewardsMinimumBalance.');
    transaction = await contract.setRewardsMinimumBalance(20_000_000, { from: owner });
    expectEvent.inTransaction(transaction.tx, tracker, 'MinimumBalanceChanged', { from: '10000000', to: '20000000' });
  });

  it('requires a minimum balance of tokens to be tracked', async function () {
    console.log('Checking transfers under minimum balance are not tracked.');
    await contract.transfer(holder1, toWei(9_000_000), { from: owner }); // NOT ENOUGH
    expect(await tracker.getHolderCount()).to.be.a.bignumber.equal('0');
    expect(await tracker.balanceOf(holder1)).to.be.a.bignumber.equal('0');
    console.log('Checking transfers over minimum balance are tracked.');
    await contract.transfer(holder2, toWei(20_000_000), { from: owner });
    expect(await tracker.getHolderCount()).to.be.a.bignumber.equal('1');
    expect(await tracker.balanceOf(holder2)).to.be.a.bignumber.equal(toWei(20_000_000));
    console.log('Checking transfers are tracked and can be viewed by holders.');
    await contract.transfer(holder3, toWei(30_000_000), { from: owner });
    expect(await tracker.balanceOf(holder3)).to.be.a.bignumber.equal(toWei(30_000_000));
    expect(await tracker.getHolderCount({ from: holder3 })).to.be.a.bignumber.equal('2');
  });


  it('can read rewards info', async function () {
    console.log(await contract.getRewardsSettings());
  });

  it('properly splits and distributes rewards', async function () {
    console.log('Checking no holders have any balances yet.');
    expect(await tracker.getAccumulated(holder1)).to.be.a.bignumber.equal('0');
    expect(await tracker.getAccumulated(holder2)).to.be.a.bignumber.equal('0');
    expect(await tracker.getAccumulated(holder3)).to.be.a.bignumber.equal('0');
    expect(await tracker.getPending(holder1)).to.be.a.bignumber.equal('0');
    expect(await tracker.getPending(holder2)).to.be.a.bignumber.equal('0');
    expect(await tracker.getPending(holder3)).to.be.a.bignumber.equal('0');

    console.log('Checking transfers record holders but do not show rewards yet.');
    await contract.transfer(holder1, toWei(10_000_000), { from: owner });
    await contract.transfer(holder2, toWei(20_000_000), { from: owner });
    await contract.transfer(holder3, toWei(30_000_000), { from: owner });
    expect(await tracker.getHolderCount()).to.be.a.bignumber.equal('3');
    console.log('Checking no holders have any balances yet.');
    expect(await tracker.getAccumulated(holder1)).to.be.a.bignumber.equal('0');
    expect(await tracker.getAccumulated(holder2)).to.be.a.bignumber.equal('0');
    expect(await tracker.getAccumulated(holder3)).to.be.a.bignumber.equal('0');
    expect(await tracker.getPending(holder1)).to.be.a.bignumber.equal('0');
    expect(await tracker.getPending(holder2)).to.be.a.bignumber.equal('0');
    expect(await tracker.getPending(holder3)).to.be.a.bignumber.equal('0');

    // await web3.eth.sendTransaction({from: holder1, to: owner, value: await web3.eth.getBalance(holder1)});
    // await web3.eth.sendTransaction({from: holder2, to: owner, value: await web3.eth.getBalance(holder2)});
    // await web3.eth.sendTransaction({from: holder3, to: owner, value: await web3.eth.getBalance(holder3)});

    // console.log(await web3.eth.getBalance(holder1));
    // console.log(await web3.eth.getBalance(holder2));
    // console.log(await web3.eth.getBalance(holder3));

    console.log('Checking sending eth to tracker triggers splitting of funds to active holders.');
    transaction = await tracker.send(toWei(30), { from: owner });
    expectEvent(transaction, 'FundsReceived', { from: owner, amount: toWei(30) });
    expectEvent(transaction, 'FundsDistributed', { from: owner, amount: toWei(30) });

    let accum = [
      await tracker.getAccumulated(holder1),
      await tracker.getAccumulated(holder2),
      await tracker.getAccumulated(holder3)
    ];

    expect(accum[0] / toWei(1)).to.be.equal(5);
    expect(accum[1] / toWei(1)).to.be.equal(10);
    expect(accum[2] / toWei(1)).to.be.equal(15);
    expect(await tracker.getPending(holder1)).to.be.a.bignumber.equal(accum[0]);
    expect(await tracker.getPending(holder2)).to.be.a.bignumber.equal(accum[1]);
    expect(await tracker.getPending(holder3)).to.be.a.bignumber.equal(accum[2]);

    let balances = [
      await web3.eth.getBalance(holder1),
      await web3.eth.getBalance(holder2),
      await web3.eth.getBalance(holder3)
    ];

    await contract.processRewardsClaims({ from: owner });

    let changes = [
      await web3.eth.getBalance(holder1),
      await web3.eth.getBalance(holder2),
      await web3.eth.getBalance(holder3)
    ]

    changes[0] = (changes[0] - balances[0]) / toWei(1);
    changes[1] = (changes[1] - balances[1]) / toWei(1);
    changes[2] = (changes[2] - balances[2]) / toWei(1);

    console.log(changes);

    expect(changes[0]).to.be.equal(5);
    expect(changes[1]).to.be.equal(10);
    expect(changes[2]).to.be.equal(15);

    expect((await tracker.getAccumulated(holder1)) / toWei(1)).to.be.equal(changes[0]);
    expect((await tracker.getAccumulated(holder2)) / toWei(1)).to.be.equal(changes[1]);
    expect((await tracker.getAccumulated(holder3)) / toWei(1)).to.be.equal(changes[2]);
    expect(await tracker.getPending(holder1)).to.be.a.bignumber.equal('0');
    expect(await tracker.getPending(holder2)).to.be.a.bignumber.equal('0');
    expect(await tracker.getPending(holder3)).to.be.a.bignumber.equal('0');

    expect(await tracker.totalDistributed()).to.be.a.bignumber.equal(toWei('30'));

    console.log(await contract.getRewardsReport(holder3));
  });


  // it('has allows holders to claim rewards', async function () {
  //   console.log('Checking only holder can change claim waiting period.');
  //   transaction = await contract.claim({ from: holder1 });
  //   console.log(transaction);
  // });

});
