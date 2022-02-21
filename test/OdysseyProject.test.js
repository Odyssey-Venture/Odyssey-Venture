const OdysseyProject = artifacts.require('./OdysseyProject.sol');

const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

var chai = require('chai');

const assert = chai.assert;
const expect = chai.expect;

const five_mins = 5 * 60;
const one_hour = 60 * 60;
const six_hours = 6 * one_hour;
const two_hours = 2 * one_hour;
const one_day = 24 * one_hour;

function toWei(count) {
  return `${count}000000000000000000`;
}

function fromWei(bn) {
  return (bn / toWei(1)).toFixed(2);
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

contract('OdysseyProject', function (accounts) {
  const [owner, holder1, holder2, holder3, holder4, holder5, holder6, holder7, holder8, holder9] = accounts;
  let contract;
  let odyssey;
  let report;
  let transaction;
  let shareholders = [owner, holder1, holder2, holder3, holder4, holder5, holder6, holder7, holder8];
  let shares = [200,200,200,100,100,50,50,50,50];

  beforeEach('setup contract for each test', async function() {
    contract = await OdysseyProject.new('TestProject', 'TST$');
    await contract.setHolders(shareholders, shares);
  });

  it('has a name and symbol', async function () {
    assert.equal(await contract.name(), 'TestProject');
    assert.equal(await contract.symbol(), 'TST$');
  });

  it('initializes shareholders using arrays', async function () {
    report = await contract.getReport();
    assert.equal(report.holderCount, shareholders.length);
    assert.equal(report.totalShares, shares.reduce((m,x)=>m+=x, 0));
    assert.equal(await contract.balanceOf(holder8), shares[8]);
  });

  it('only allows holders to request funds from contract', async function () {
    await expectRevert(contract.requestWithdraw(toWei(1), { from: holder9 }), 'No shares');
  });

  it('only protects from overdraft', async function () {
    await expectRevert(contract.requestWithdraw(toWei(1), { from: holder4 }), 'Overdraft');
  });

  it('allows a holder to request funds from contract', async function () {
    await contract.send(toWei(2), { from: holder9 });
    await contract.requestWithdraw(toWei(1), { from: holder4 });
    assert.equal(await contract.withdrawTo(), holder4);
    assert.equal(await contract.withdrawAmount(), toWei(1));
    assert.notEqual(await contract.withdrawExpires(), '0');
  });

  it('allows only one request at a time', async function () {
    await contract.send(toWei(2), { from: holder9 });
    await contract.requestWithdraw(toWei(1), { from: holder4 });
    await expectRevert(contract.requestWithdraw(toWei(1), { from: holder1 }), 'Pending request active');
  });

  it('only allows holders to approve requests', async function () {
    await expectRevert(contract.requestWithdraw(toWei(1), { from: holder9 }), 'No shares');
  });

  it('requires a request before approving', async function () {
    await expectRevert(contract.approveWithdraw({ from: holder1 }), 'No pending request');
  });

  it('automatically approves own request', async function () {
    await contract.send(toWei(2), { from: holder9 });
    await contract.requestWithdraw(toWei(1), { from: holder4 });
    assert.notEqual((await contract.holder(holder4)).approved, '0');
  });

  it('cannot approve request twice', async function () {
    await contract.send(toWei(2), { from: holder9 });
    await contract.requestWithdraw(toWei(1), { from: holder4 });
    await expectRevert(contract.approveWithdraw({ from: holder4 }), 'Already approved');
  });

  it('allows approving a request', async function () {
    await contract.send(toWei(2), { from: holder9 });
    await contract.requestWithdraw(toWei(1), { from: holder4 });
    await contract.approveWithdraw({ from: holder1 });
    assert.equal((await contract.totalApproval()).toNumber(), shares[1]+shares[4]);
  });

  it('only allows holders to unapprove requests', async function () {
    await expectRevert(contract.unapproveWithdraw({ from: holder9 }), 'No shares');
  });

  it('requires a request approved before unapproving', async function () {
    await expectRevert(contract.unapproveWithdraw({ from: holder1 }), 'Not approved');
  });

  it('allows unapproving a request', async function () {
    await contract.send(toWei(2), { from: holder9 });
    await contract.requestWithdraw(toWei(1), { from: holder4 });
    await contract.approveWithdraw({ from: holder1 });
    await contract.unapproveWithdraw({ from: holder1 });
    assert.equal((await contract.totalApproval()).toNumber(), shares[4]);
  });

  it('unapproving own request cancels and resets', async function () {
    await contract.send(toWei(2), { from: holder9 });
    await contract.requestWithdraw(toWei(1), { from: holder4 });
    await contract.unapproveWithdraw({ from: holder4 });

    assert.equal(await contract.withdrawTo(), '0x0000000000000000000000000000000000000000');
    assert.equal(await contract.withdrawAmount(), '0');
    assert.equal(await contract.withdrawExpires(), '0');
    assert.equal((await contract.holder(holder4)).approved, '0');
  });

  it('pays out once request is approved', async function () {
    await contract.send(toWei(2), { from: holder9 });
    await contract.requestWithdraw(toWei(1), { from: holder1 });
    let bal = await web3.eth.getBalance(holder1) / toWei(1);
    await contract.approveWithdraw({ from: holder2 });
    await contract.approveWithdraw({ from: holder3 });
    bal = (await web3.eth.getBalance(holder1)) / toWei(1) - bal;
    assert.equal(bal.toFixed(2), 1);
  });

  it('resets request and votes once payment complete', async function () {
    await contract.send(toWei(2), { from: holder9 });
    await contract.requestWithdraw(toWei(1), { from: holder1 });
    await contract.approveWithdraw({ from: holder2 });
    await contract.approveWithdraw({ from: holder3 });

    assert.equal(await contract.withdrawTo(), '0x0000000000000000000000000000000000000000');
    assert.equal(await contract.withdrawAmount(), '0');
    assert.equal(await contract.withdrawExpires(), '0');

    assert.equal((await contract.holder(holder1)).approved, '0');
    assert.equal((await contract.holder(holder2)).approved, '0');
    assert.equal((await contract.holder(holder3)).approved, '0');
    assert.equal((await contract.totalApproval()), '0');
  });

  it('resets request and votes once request expires', async function () {
    await contract.send(toWei(2), { from: holder9 });
    await contract.requestWithdraw(toWei(1), { from: holder4 });
    await timeTravel(one_day);
    await contract.approveWithdraw({ from: holder2 });

    assert.equal(await contract.withdrawTo(), '0x0000000000000000000000000000000000000000');
    assert.equal(await contract.withdrawAmount(), '0');
    assert.equal(await contract.withdrawExpires(), '0');
    assert.equal((await contract.holder(holder2)).approved, '0');
  });

  it('allows new request once previous has expired', async function () {
    await contract.send(toWei(3), { from: holder9 });
    await contract.requestWithdraw(toWei(1), { from: holder4 });

    assert.equal(await contract.withdrawTo(), holder4);
    assert.equal(fromWei(await contract.withdrawAmount()), 1);

    await timeTravel(one_day);
    await contract.requestWithdraw(toWei(2), { from: holder2 });

    assert.equal(await contract.withdrawTo(), holder2);
    assert.equal(fromWei(await contract.withdrawAmount()), 2);
  });
});
