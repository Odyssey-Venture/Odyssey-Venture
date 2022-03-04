const OdysseyProject = artifacts.require('./OdysseyProject.sol');
const Odyssey = artifacts.require('./Odyssey.sol');

const { expectEvent, expectRevert } = require('@openzeppelin/test-helpers');

var chai = require('chai');

const assert = chai.assert;

const ZERO = '0x0000000000000000000000000000000000000000';

function toWei(count) {
  return `${count}000000000000000000`;
}

function fromWei(bn) {
  return (bn / toWei(1)).toFixed(2);
}

contract('OdysseyProject', function (accounts) {
  const [owner, holder1, holder2, holder3, holder4, holder5, holder6, holder7, holder8, holder9] = accounts;
  let contract;
  let transaction;
  let shareholders = [owner, holder1, holder2, holder3, holder4, holder5, holder6, holder7, holder8];
  let shares = [2000,2000,2000,1000,1000,500,500,500,500];

  beforeEach('setup contract for each test', async function() {
    contract = await OdysseyProject.new();
    await contract.setHolders(shareholders, shares);
  });

  it('sets Officer wallets', async function () {
    await contract.setOfficers([holder1, holder2, holder3, holder4]);
    assert.equal(await contract.ceo1(), holder1);
    assert.equal(await contract.ceo2(), holder2);
    assert.equal(await contract.cfo1(), holder3);
    assert.equal(await contract.cfo2(), holder4);
  });

  it('requires 4 Officer wallets to set', async function () {
    await expectRevert(contract.setOfficers([holder1, holder2, holder3]), '4 Officers required');
  });

  it('allows Officer wallets to initialize once', async function () {
    await contract.setOfficers([holder1, holder2, holder3, holder4]);
    await expectRevert(contract.setOfficers([holder1, holder2, holder3, holder4]), 'Officers already set');
  });

  it('replaceOfficer when approved by all other officers', async function () {
    await contract.setOfficers([holder1, holder2, holder3, holder4]);

    transaction = await contract.replaceOfficer(holder4, holder5, { from: holder1 }); // VOTE 1
    // EVENT EMIT
    expectEvent(transaction, 'OfficerVote', { officer: holder1, from: holder4, to: holder5 });
    // CHECK VOTES
    assert.equal((await contract.voteOfficer(holder1)).from, holder4);
    assert.equal((await contract.voteOfficer(holder1)).to, holder5);
    // CHECK STILL UNCHANGED
    assert.equal(await contract.cfo2(), holder4);

    transaction = await contract.replaceOfficer(holder4, holder5, { from: holder2 }); // VOTE 2
    expectEvent(transaction, 'OfficerVote', { officer: holder2, from: holder4, to: holder5 });
    assert.equal((await contract.voteOfficer(holder2)).from, holder4);
    assert.equal((await contract.voteOfficer(holder2)).to, holder5);
    assert.equal(await contract.cfo2(), holder4);

    transaction = await contract.replaceOfficer(holder4, holder5, { from: holder3 }); // VOTE 3
    expectEvent(transaction, 'OfficerVote', { officer: holder3, from: holder4, to: holder5 });
    // CHANGE APPROVED
    expectEvent(transaction, 'OfficerChanged', { from: holder4, to: holder5 });
    assert.notEqual(await contract.cfo2(), holder4);
    assert.equal(await contract.cfo2(), holder5);
    // RESET VOTERS
    assert.equal((await contract.voteOfficer(holder1)).from, ZERO);
    assert.equal((await contract.voteOfficer(holder2)).from, ZERO);
    assert.equal((await contract.voteOfficer(holder3)).from, ZERO);
    assert.equal((await contract.voteOfficer(holder5)).from, ZERO);
  });

  it('cancels replaceOfficer when conflicted -- 2 of 3', async function () {
    await contract.setOfficers([holder1, holder2, holder3, holder4]);

    await contract.replaceOfficer(holder4, holder5, { from: holder1 }); // VOTE 1
    assert.equal((await contract.voteOfficer(holder1)).from, holder4);

    await contract.replaceOfficer(holder4, holder5, { from: holder2 }); // VOTE 2
    assert.equal((await contract.voteOfficer(holder2)).from, holder4);

    transaction = await contract.replaceOfficer(holder4, holder6, { from: holder3 }); // DISAGREE
    expectEvent(transaction, 'OfficerVoteReset');
    // NO CHANGE
    assert.equal(await contract.cfo2(), holder4);
    // VOTES CLEARED
    assert.equal((await contract.voteOfficer(holder1)).from, ZERO);
    assert.equal((await contract.voteOfficer(holder2)).from, ZERO);
    assert.equal((await contract.voteOfficer(holder3)).from, ZERO);
    assert.equal((await contract.voteOfficer(holder5)).from, ZERO);
  });

  it('cancels replaceOfficer when conflicted -- 1 of 3', async function () {
    await contract.setOfficers([holder1, holder2, holder3, holder4]);

    await contract.replaceOfficer(holder4, holder5, { from: holder1 }); // VOTE 1
    assert.equal((await contract.voteOfficer(holder1)).from, holder4);

    await contract.replaceOfficer(holder4, holder6, { from: holder3 }); // DISAGREE
    expectEvent(transaction, 'OfficerVoteReset');
    // NO CHANGE
    assert.equal(await contract.cfo2(), holder4);
    // VOTES CLEARED
    assert.equal((await contract.voteOfficer(holder1)).from, ZERO);
    assert.equal((await contract.voteOfficer(holder2)).from, ZERO);
    assert.equal((await contract.voteOfficer(holder3)).from, ZERO);
    assert.equal((await contract.voteOfficer(holder5)).from, ZERO);
  });

  it('replaceContract when 4 of 4 vote', async function () {
    await contract.setOfficers([holder1, holder2, holder3, holder4]);
    let odyssey = await Odyssey.new();
    await contract.setToken(odyssey.address, {from: owner });
    await odyssey.setProjectWallet(contract.address, {from: owner });

    let newProject = await OdysseyProject.new({from: owner });

    transaction = await contract.replaceContract(newProject.address, { from: holder1 }); // VOTE 1
    expectEvent(transaction, 'ContractVote', { officer: holder1, to: newProject.address });
    assert.equal((await contract.voteContract(holder1)).to, newProject.address);

    transaction = await contract.replaceContract(newProject.address, { from: holder2 }); // VOTE 2
    expectEvent(transaction, 'ContractVote', { officer: holder2, to: newProject.address });
    assert.equal((await contract.voteContract(holder2)).to, newProject.address);

    transaction = await contract.replaceContract(newProject.address, { from: holder3 }); // VOTE 3
    expectEvent(transaction, 'ContractVote', { officer: holder3, to: newProject.address });
    assert.equal((await contract.voteContract(holder3)).to, newProject.address);

    transaction = await contract.replaceContract(newProject.address, { from: holder4 }); // VOTE 4
    expectEvent(transaction, 'ContractVote', { officer: holder4, to: newProject.address });

    expectEvent(transaction, 'ContractChanged', { from: contract.address, to: newProject.address });
    assert.equal(await odyssey.projectWallet(), newProject.address);

    // VOTES CLEARED
    assert.equal((await contract.voteContract(holder1)).to, ZERO);
    assert.equal((await contract.voteContract(holder2)).to, ZERO);
    assert.equal((await contract.voteContract(holder3)).to, ZERO);
    assert.equal((await contract.voteContract(holder4)).to, ZERO);
  });

  it('cancels replaceContract vote when disagree', async function () {
    await contract.setOfficers([holder1, holder2, holder3, holder4]);

    let newTracker = await OdysseyProject.new({from: owner });

    transaction = await contract.replaceContract(newTracker.address, { from: holder1 }); // VOTE 1
    expectEvent(transaction, 'ContractVote', { officer: holder1, to: newTracker.address });
    assert.equal((await contract.voteContract(holder1)).to, newTracker.address);

    transaction = await contract.replaceContract(holder9, { from: holder2 }); // DISAGREE
    expectEvent(transaction, 'ContractVote', { officer: holder2, to: holder9 });

    expectEvent(transaction, 'ContractVoteReset');

    // VOTES CLEARED
    assert.equal((await contract.voteContract(holder1)).to, ZERO);
    assert.equal((await contract.voteContract(holder2)).to, ZERO);
    assert.equal((await contract.voteContract(holder3)).to, ZERO);
    assert.equal((await contract.voteContract(holder4)).to, ZERO);
  });

  it('cancels replaceContract vote when disagree 3 of 4 vote', async function () {
    await contract.setOfficers([holder1, holder2, holder3, holder4]);

    let newTracker = await OdysseyProject.new({from: owner });

    await contract.replaceContract(newTracker.address, { from: holder1 }); // VOTE 1
    assert.equal((await contract.voteContract(holder1)).to, newTracker.address);
    await contract.replaceContract(newTracker.address, { from: holder2 }); // VOTE 2
    assert.equal((await contract.voteContract(holder2)).to, newTracker.address);
    await contract.replaceContract(newTracker.address, { from: holder3 }); // VOTE 3
    assert.equal((await contract.voteContract(holder3)).to, newTracker.address);
    transaction = await contract.replaceContract(holder9, { from: holder4 }); // DISAGREE

    expectEvent(transaction, 'ContractVoteReset');

    // VOTES CLEARED
    assert.equal((await contract.voteContract(holder1)).to, ZERO);
    assert.equal((await contract.voteContract(holder2)).to, ZERO);
    assert.equal((await contract.voteContract(holder3)).to, ZERO);
    assert.equal((await contract.voteContract(holder4)).to, ZERO);
  });

  it('requestFunds by CEO must be approved by CFO', async function () {
    await contract.setOfficers([holder1, holder2, holder3, holder4]);
    await contract.send(toWei(10), { from: holder5 });
    let before = await web3.eth.getBalance(holder5);

    transaction = await contract.requestFunds(holder5, toWei(1), { from: holder1 }); // VOTE CEO1
    // EVENT EMIT
    expectEvent(transaction, 'FundsRequest', { officer: holder1, to: holder5, amount: toWei(1) });
    // CHECK VOTES
    assert.equal((await contract.voteFunds(holder1)).amount, toWei(1));
    assert.equal((await contract.voteFunds(holder1)).to, holder5);
    // 2ND CEO DOES NOTHING
    transaction = await contract.requestFunds(holder5, toWei(1), { from: holder2 }); // VOTE CEO2
    assert.equal((await contract.voteFunds(holder2)).to, holder5);

    // CHECK STILL UNCHANGED
    assert.equal(fromWei(await web3.eth.getBalance(contract.address)), 10);

    transaction = await contract.requestFunds(holder5, toWei(1), { from: holder3 }); // VOTE CFO1
    expectEvent(transaction, 'FundsRequest', { officer: holder3, to: holder5, amount: toWei(1) });

    // REQ APPROVED
    expectEvent(transaction, 'FundsApproved', { to: holder5, amount: toWei(1) });
    // FUNDS DELIVERED
    assert.equal(fromWei(await web3.eth.getBalance(contract.address)), 9);
    assert.equal(fromWei(await web3.eth.getBalance(holder5)) - fromWei(before), 1);

    // RESET VOTERS
    assert.equal((await contract.voteFunds(holder1)).to, ZERO);
    assert.equal((await contract.voteFunds(holder2)).to, ZERO);
    assert.equal((await contract.voteFunds(holder3)).to, ZERO);
    assert.equal((await contract.voteFunds(holder4)).to, ZERO);
  });

  it('requestFunds by CFO must be approved by CEO', async function () {
    await contract.setOfficers([holder1, holder2, holder3, holder4]);
    await contract.send(toWei(10), { from: holder5 });
    let before = await web3.eth.getBalance(holder5);

    transaction = await contract.requestFunds(holder5, toWei(1), { from: holder3 }); // VOTE CFO
    // EVENT EMIT
    expectEvent(transaction, 'FundsRequest', { officer: holder3, to: holder5, amount: toWei(1) });
    // CHECK VOTES
    assert.equal((await contract.voteFunds(holder3)).amount, toWei(1));
    assert.equal((await contract.voteFunds(holder3)).to, holder5);
    // 2ND CFO DOES NOTHING
    transaction = await contract.requestFunds(holder5, toWei(1), { from: holder4 }); // VOTE CFO2
    assert.equal((await contract.voteFunds(holder4)).to, holder5);

    // CHECK STILL UNCHANGED
    assert.equal(fromWei(await web3.eth.getBalance(contract.address)), 10);

    transaction = await contract.requestFunds(holder5, toWei(1), { from: holder1 }); // VOTE CEO
    expectEvent(transaction, 'FundsRequest', { officer: holder1, to: holder5, amount: toWei(1) });

    // REQ APPROVED
    expectEvent(transaction, 'FundsApproved', { to: holder5, amount: toWei(1) });
    // FUNDS DELIVERED
    assert.equal(fromWei(await web3.eth.getBalance(contract.address)), 9);
    assert.equal(fromWei(await web3.eth.getBalance(holder5)) - fromWei(before), 1);

    // RESET VOTERS
    assert.equal((await contract.voteFunds(holder1)).to, ZERO);
    assert.equal((await contract.voteFunds(holder2)).to, ZERO);
    assert.equal((await contract.voteFunds(holder3)).to, ZERO);
    assert.equal((await contract.voteFunds(holder4)).to, ZERO);
  });

  it('cancels requestFunds vote when any disagree', async function () {
    await contract.setOfficers([holder1, holder2, holder3, holder4]);
    await contract.send(toWei(10), { from: holder5 });

    await contract.requestFunds(holder5, toWei(1), { from: holder1 }); // VOTE
    transaction = await contract.requestFunds(holder5, 0, { from: holder3 }); // DISAGREE
    expectEvent(transaction, 'FundsRequestReset');

    // CHECK STILL UNCHANGED
    assert.equal(fromWei(await web3.eth.getBalance(contract.address)), 10);

    // RESET VOTERS
    assert.equal((await contract.voteFunds(holder1)).to, ZERO);
    assert.equal((await contract.voteFunds(holder2)).to, ZERO);
    assert.equal((await contract.voteFunds(holder3)).to, ZERO);
    assert.equal((await contract.voteFunds(holder4)).to, ZERO);
  });
});
