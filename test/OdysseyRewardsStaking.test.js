// test/Odyssey.test.js
const OdysseyRewards = artifacts.require('./OdysseyRewards.sol');

const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

var chai = require('chai');

const expect = chai.expect;
const assert = chai.assert;

const one_hour = 60 * 60;
const six_hours = 6 * one_hour;
const one_day = 24 *one_hour;

function fromWei(bn) {
  return (bn / toWei(1)).toFixed(2);
}

function prettyWei(bn) {
  return (fromWei(bn) * 1.0).toLocaleString();
}

function toWei(count) {
  return `${count}000000000000000000`;
}

function showData(data) {
  Object.keys(data).forEach(function(key) {
    if (key.length > 2) console.log(key, data[key].toString());
  });
}

function dumpEvents(transaction, event) {
  for (const log of transaction.logs) {
    if (log.event==event) {
      log.args.name = log.event;
      showData(log.args);
    }
  }
}

function findWithdraw(transaction, account) {
  for (const log of transaction.logs)
    if (log.event=='FundsWithdrawn' && log.args.account==account)
      return fromWei(log.args.amount);
  return 0;
}

function ratio(one,two) {
  one = one / toWei(1);
  two = two / toWei(1);
  return one/(one+two);
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
  let uniswapV2Pair;

  const wallets = {
    project: '0xfB0f7207B2e682c8a7A6bdb2b2012a395a653584',
    liquidity: owner
  };

  beforeEach('setup contract for each test', async function() {
    contract = await OdysseyRewards.new('TestRewards', 'TST$');
  });

  it('allows only owner to turn staking on', async function () {
    await expectRevert(contract.setStaking(true, { from: holder1 }), 'Ownable: caller is not the owner');
  });

  it('requires the value of staking on to change if updated', async function () {
    await expectRevert(contract.setStaking(false, { from: owner }), 'Value unchanged');
  });

  it('allows owner to change staking option for contract', async function () {
    await contract.setStaking(true, { from: owner });
    assert.isTrue(await contract.isStakingOn());
  });

  it('allows only owner to stake an account', async function () {
    await expectRevert(contract.stakeAccount(holder1, true, { from: holder1 }), 'Ownable: caller is not the owner');
    assert.isFalse(await contract.isStaked(holder1));
  });

  it('requires contract level staking on for a holder to stake', async function () {
    await contract.trackBuy(holder1, toWei(10_000_000), { from: owner });
    await expectRevert(contract.stakeAccount(holder1, true, { from: owner }), 'Rewards staking not available');
    assert.isFalse(await contract.isStaked(holder1));
    await contract.setStaking(true, { from: owner });
    await contract.stakeAccount(holder1, true, { from: owner });
    assert.isTrue(await contract.isStaked(holder1));
  });

  it('requires holder over max to begin staking', async function () {
    await contract.setStaking(true, { from: owner });
    await expectRevert(contract.stakeAccount(holder1, true, { from: owner }), 'Rewards staking not available');
    assert.isFalse(await contract.isStaked(holder1));
    await contract.trackBuy(holder1, toWei(10_000_000), { from: owner });
    await contract.stakeAccount(holder1, true, { from: owner });
    assert.isTrue(await contract.isStaked(holder1));
  });

  it('requires holder not be excluded to begin staking', async function () {
    await contract.setStaking(true, { from: owner });
    await contract.trackBuy(holder1, toWei(10_000_000), { from: owner });
    await contract.setExcludedAddress(holder1, { from: owner });
    await expectRevert(contract.stakeAccount(holder1, true, { from: owner }), 'Rewards staking not available');
    assert.isFalse(await contract.isStaked(holder1));
    await contract.setIncludedAddress(holder1, toWei(10_000_000), { from: owner });
    await contract.stakeAccount(holder1, true, { from: owner });
    assert.isTrue(await contract.isStaked(holder1));
  });

  it('gives max rewards when staking is off', async function () {
    await contract.trackBuy(holder1, toWei(10_000_000), { from: owner });
    let data = await contract.getReportAccount(holder1);
    assert.equal(data.tokens, toWei(10_000_000));
    assert.equal(data.stakedPercent, '100');
    assert.equal(data.stakedTokens, toWei(10_000_000));
    assert.equal(data.stakedDays, '0');
  });

  it('gives variable rewards when staking is on', async function () {
    await contract.setStaking(true, { from: owner });
    await contract.trackBuy(holder1, toWei(10_000_000), { from: owner });
    let data = await contract.getReportAccount(holder1);
    assert.equal(data.tokens, toWei(10_000_000));
    assert.equal(data.stakedPercent, '40');
    assert.equal(data.stakedTokens, toWei(4_000_000));
    assert.equal(data.stakedDays, '0');
  });

  it('increases variable rewards based on length of stake', async function () {
    await contract.setStaking(true, { from: owner });

    await contract.trackBuy(holder2, toWei(10_000_000), { from: owner });
    await contract.stakeAccount(holder2, true, { from: owner });

    await timeTravel(one_day * 31); // FULLY STAKED ACCOUNT2
    transaction = await contract.processClaims(200_000); // UPDATES STAKING %S
    let data = await contract.getReportAccount(holder2);
    assert.equal(data.stakedPercent, '100');
    assert.equal(data.stakedTokens, toWei(10_000_000));
    let stake2 = data.stakedTokens;
    let ratios = 0;
    let funds = 0;

    await contract.trackBuy(holder1, toWei(10_000_000), { from: owner });
    await contract.stakeAccount(holder1, true, { from: owner });

    let stakedPercent = 40;
    let tokens = 10_000_000;
    let stakedTokens = 0;
    let total = 0;
    for (let idx=0;idx<35;idx++) {
      stakedTokens = tokens * stakedPercent / 100;
      data = await contract.getReportAccount(holder1); // showData(data);
      assert.equal(data.stakedDays.toNumber(), idx);
      assert.equal(data.stakedPercent.toNumber(), stakedPercent);
      assert.equal(data.stakedTokens, toWei(stakedTokens));
      total = stake2 / toWei(1) + data.stakedTokens / toWei(1);
      await contract.send(toWei(10), { from: owner });
      transaction = await contract.processClaims(200_000);
      ratios = ratio(data.stakedTokens, stake2) * 10;
      funds = findWithdraw(transaction, holder1);
      assert.equal(funds, ratios.toFixed(2));
      console.log('  - staked rate', data.stakedPercent.toNumber(),
        'staked tokens', prettyWei(data.stakedTokens).padStart(12, ' '),
        'total staked', total.toFixed().padStart(12, ' '),
        'expected ratio', ratios.toFixed(2),
        'holder', funds.padStart(6, ' '),
        'full stake holder', findWithdraw(transaction, holder2).padStart(6, ' ')
      );
      await timeTravel(one_day);
      await contract.processClaims(200_000); // UPDATES STAKING %S
      stakedPercent += 2;
      if (stakedPercent > 100) stakedPercent = 100;
    }
  });

  it('increases variable rewards based on length of stake', async function () {
    await contract.setStaking(true, { from: owner });
    let cnt = 9;
    for (let jdx=1;jdx<=cnt;jdx++) {
      await contract.trackBuy(accounts[jdx], toWei(10_000_000), { from: owner });
      await contract.stakeAccount(accounts[jdx], true, { from: owner });
      await timeTravel(six_hours * (10 - jdx));
    }
    await contract.stakeAccount(holder9, false, { from: owner });
    console.log('  * Holder 9 is unstaked');
    await contract.processClaims(800_000); // UPDATES STAKING %S
    let data;
    let ratios = 0;
    let funds = 0;
    let send = 10;
    let sent = 0;
    let rando = 0;
    let f = function(one,two) { return one/two; }

    for (let idx=0;idx<60;idx++) {
      let datas = [];
      let total = 0;
      sent += send;
      await contract.send(toWei(send), { from: owner });
      transaction = await contract.processClaims(800_000);
      for (let jdx=1;jdx<=cnt;jdx++) datas.push(await contract.getReportAccount(accounts[jdx]));
      for (let jdx=1;jdx<=cnt;jdx++) total += datas[jdx-1].stakedTokens / toWei(1);
      assert.equal(total, fromWei(await contract.totalBalance()));

      console.log('day', idx, 'total tokens staked', total.toLocaleString(), 'total BNB rewarded', sent);

      let sumRatio = 0;
      let sumClaim = 0;
      for (let jdx=1;jdx<=cnt;jdx++) {
        funds = findWithdraw(transaction, accounts[jdx]);
        data = datas[jdx-1];
        ratios = f(data.stakedTokens / toWei(1), total) * 100;
        sumRatio += ratios;
        sumClaim += data.rewardsClaimed / toWei(1);
        console.log(
          '  - holder', jdx,
          'tokens staked/total', prettyWei(data.stakedTokens).padStart(12, ' '), '/', prettyWei(data.tokens).padStart(12, ' '),
          '| percent staked/total', data.stakedPercent.toNumber().toFixed(1).padStart(5, ' ')+'%', '/', ratios.toFixed(1).padStart(5, ' ')+'%',
          '| today', funds.padStart(6, ' '),
          'total', prettyWei(data.rewardsClaimed).padStart(6, ' ')
        );
      }
      assert.equal(sumRatio.toFixed(1), 100);
      assert.equal(sumClaim.toFixed(2), sent.toFixed(2));

      await timeTravel(one_day);

      if (rando==0 && Math.random() < .1) {
        rando = Math.ceil(Math.random() * 8)+1;
        if (rando > 8) rando = 4;
        await contract.stakeAccount(accounts[rando], false, { from: owner });
        console.log('  * Holder ', rando, ' is unstaked');
      }

      if (rando!=0 && Math.random() < .2) {
        await contract.stakeAccount(accounts[rando], true, { from: owner });
        console.log('  * Holder ', rando, ' is staked');
        rando = 0;
      }

      await contract.processClaims(800_000); // UPDATES STAKING %S
    }

    data = await contract.getReport();
    showData(data);

    // assert.equal(data.holderCount, 9);
    // assert.isFalse(data.stakingOn);
    // assert.equal(data.totalTokensTracked, toWei(10_000_000));
    // assert.equal(data.totalTokensStaked, toWei(10_000_000));
    assert.equal(data.totalRewardsPaid, toWei(sent));

  });


});
