const OdysseyProject = artifacts.require('./OdysseyProject.sol');
const Odyssey = artifacts.require('./Odyssey.sol');

const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

var chai = require('chai');

const assert = chai.assert;

function toWei(count) {
  return `${count}000000000000000000`;
}

function fromWei(bn) {
  return (bn / toWei(1)).toFixed(2);
}

const MIN_BALANCE = 10_000_000;

contract('OdysseyProject', function (accounts) {
  const [owner, holder1, holder2, holder3, holder4, holder5, holder6, holder7, holder8, holder9] = accounts;
  let contract;
  let odyssey;
  let transaction;
  let shareholders = [owner, holder1, holder2, holder3, holder4, holder5, holder6, holder7, holder8];
  let dollars = [2000,2000,2000,1000,1000,500,500,500,500];
  let totalDollars = dollars.reduce((m,x)=>m+=x, 0);

  beforeEach('setup contract for each test', async function() {
    contract = await OdysseyProject.new();
    await contract.setHolders(shareholders, dollars);
  });

  it('sets odyssey token', async function () {
    odyssey = await Odyssey.new();
    await contract.setToken(odyssey.address, {from: owner });
    assert.equal(await contract.odyssey(), odyssey.address);
  });

  it('sets odyssey token once', async function () {
    odyssey = await Odyssey.new();
    await contract.setToken(odyssey.address, {from: owner });
    await expectRevert(contract.setToken(odyssey.address, {from: owner }), 'Token already set');
  });

  it('sets project wallet in token', async function () {
    odyssey = await Odyssey.new();
    await contract.setToken(odyssey.address, {from: owner });
    await odyssey.setProjectWallet(contract.address, {from: owner });
    assert.equal(await odyssey.projectWallet(), contract.address);

    // VOTE TO REPLACE CONTRACT
    await contract.setOfficers([holder1, holder2, holder3, holder4]);
    await contract.replaceContract(holder9, { from: holder1 }); // VOTE 1
    await contract.replaceContract(holder9, { from: holder2 }); // VOTE 2
    await contract.replaceContract(holder9, { from: holder3 }); // VOTE 3
    transaction = await contract.replaceContract(holder9, { from: holder4 }); // VOTE 4
    expectEvent(transaction, 'ContractChanged', { from: contract.address, to: holder9 });

    // CHECK IT UPDATED IN ODYSSEY
    assert.equal(await odyssey.projectWallet(), holder9);

    // VOTE TO REPLACE CONTRACT
    await contract.replaceContract(holder8, { from: holder1 }); // VOTE 1
    await contract.replaceContract(holder8, { from: holder2 }); // VOTE 2
    await contract.replaceContract(holder8, { from: holder3 }); // VOTE 3
    await expectRevert(contract.replaceContract(holder8, { from: holder4 }), 'Value invalid');
  });

  it('initializes shareholders using arrays', async function () {
    report = await contract.getReport();
    assert.equal(report.holderCount, shareholders.length);
    assert.equal(report.totalDollars, totalDollars);
    assert.equal(fromWei(await contract.dividendsInBNB()), (totalDollars/333).toFixed(2));
    for (let idx=0;idx<9;idx++) {
      assert.equal((await contract.balanceOf(accounts[idx])).toNumber(), dollars[idx]);
    }
  });

  it('allows holder to view report by address or index', async function () {
    odyssey = await Odyssey.new();
    await contract.setToken(odyssey.address, {from: owner });
    await odyssey.transfer(holder1, toWei(MIN_BALANCE), { from: owner });

    report = await contract.getReportAccountAt(2);
    assert.equal(report.account, holder1);
    assert.equal(report.index, 2);
    assert.equal(report.shares, '2000');
    assert.equal(report.dividendsEarned, '0');
    assert.equal(report.dividendsClaimed, '0');

    report = await contract.getReportAccount(holder1);
    assert.equal(report.account, holder1);
    assert.equal(report.index, 2);
    assert.equal(report.shares, '2000');
    assert.equal(report.dividendsEarned, '0');
    assert.equal(report.dividendsClaimed, '0');
  });

  it('requires address or index to exist for reporting', async function () {
    await expectRevert(contract.getReportAccountAt(100), 'Value invalid');
  });

  it('distributes funds', async function () {
    odyssey = await Odyssey.new();
    await contract.setToken(odyssey.address, {from: owner });
    await odyssey.transfer(holder1, toWei(MIN_BALANCE), { from: owner });

    await contract.send(toWei(100), { from: holder9 });
    transaction = await contract.withdrawFunds(holder1);
    expectEvent(transaction, 'FundsWithdrawn', { account: holder1, amount: toWei(2) });
    report = await contract.getReportAccount(holder1);
    assert.equal(report.shares, '2000');
    assert.equal(report.dividendsEarned, toWei(2));
    assert.equal(report.dividendsClaimed, toWei(2));
  });

  it('only distributes funds if min balance', async function () {
    odyssey = await Odyssey.new();
    await contract.setToken(odyssey.address, {from: owner });
    await odyssey.transfer(holder1, toWei(MIN_BALANCE), { from: owner });

    await contract.send(toWei(100), { from: holder9 });
    await contract.processClaims(800_000); // UPDATES BALANCES

    report = await contract.getReportAccount(holder1);
    assert.equal(report.shares, '2000'); // TRACKED
    assert.equal(report.dividendsEarned, toWei(2));

    report = await contract.getReportAccount(holder3);
    assert.equal(report.shares, '0'); // NOT TRACKED
    assert.equal(report.dividendsEarned, toWei(1));

    await contract.send(toWei(10), { from: holder9 });

    report = await contract.getReportAccount(holder1);
    assert.notEqual(report.dividendsEarned, toWei(2)); // CHANGED

    report = await contract.getReportAccount(holder3);
    assert.equal(report.dividendsEarned, toWei(1)); // UNCHANGED

    await odyssey.transfer(holder3, toWei(MIN_BALANCE), { from: owner });
    await contract.processClaims(800_000); // UPDATES BALANCES
    report = await contract.getReportAccount(holder3);
    assert.equal(report.shares, '1000'); // BALANCE UPDATED

    await contract.send(toWei(10), { from: holder9 });
    report = await contract.getReportAccount(holder3);
    assert.equal(report.shares, '1000'); // TRACKED
    assert.notEqual(report.dividendsEarned, toWei(1)); // CHANGED
  });

  it('stops distributing funds after paid back', async function () {
    await contract.send(toWei(301), { from: holder9 }); // 10K should pay back 30 BNB so send in 300 since tax is 10%
    report = await contract.getReport();
    assert.equal(fromWei(report.totalDividends), '30.10');
    report = await contract.getReportAccount(holder1);
    assert.equal(fromWei(report.dividendsEarned), '6.02'); // holder1 paid 2k so should get back about 6 BNB

    // SENDING IN MORE BNB SHOULD NO LONG AFFECT DIVIDENDS
    await contract.send(toWei(10), { from: holder9 });
    report = await contract.getReport();
    assert.equal(fromWei(report.totalDividends), '30.10');
    report = await contract.getReportAccount(holder1);
    assert.equal(fromWei(report.dividendsEarned), '6.02');

    // SENDING IN MORE BNB SHOULD NO LONG AFFECT DIVIDENDS
    await contract.send(toWei(10), { from: holder9 });
    report = await contract.getReport();
    assert.equal(fromWei(report.totalDividends), '30.10');
    report = await contract.getReportAccount(holder1);
    assert.equal(fromWei(report.dividendsEarned), '6.02');
  });

  it('processes all shareholder', async function () {
    await contract.setToken(odyssey.address, {from: owner });
    for (let idx=1;idx<shareholders.length;idx++) {
      await odyssey.transfer(shareholders[idx], toWei(MIN_BALANCE), { from: owner });
    }

    await contract.send(toWei(301), { from: holder9 }); // 10K should pay back 30 BNB so send in 300 since tax is 10%
    report = await contract.getReport();
    assert.equal(fromWei(report.totalDividends), '30.10');
    report = await contract.getReportAccount(holder1);
    assert.equal(fromWei(report.dividendsEarned), '6.02'); // holder1 paid 2k so should get back about 6 BNB

    // SENDING IN MORE BNB SHOULD NO LONG AFFECT DIVIDENDS
    await contract.send(toWei(10), { from: holder9 });
    report = await contract.getReport();
    assert.equal(fromWei(report.totalDividends), '30.10');
    report = await contract.getReportAccount(holder1);
    assert.equal(fromWei(report.dividendsEarned), '6.02');

    // SENDING IN MORE BNB SHOULD NO LONG AFFECT DIVIDENDS
    await contract.send(toWei(10), { from: holder9 });
    report = await contract.getReport();
    assert.equal(fromWei(report.totalDividends), '30.10');
    report = await contract.getReportAccount(holder1);
    assert.equal(fromWei(report.dividendsEarned), '6.02');

    transaction = await contract.processClaims(800_000);

    let cnt = await contract.records();
    let sum = 0;
    for (let idx=1;idx<=cnt;idx++) {
      report = await contract.getReportAccountAt(idx);
      console.log(idx, report.index.toNumber(), report.shares.toNumber(), fromWei(report.dividendsClaimed));
      sum += fromWei(report.dividendsClaimed) * 1;
    }
    console.log(sum);
  });
});
