const OdysseyRewards = artifacts.require("./OdysseyRewards.sol");
const OdysseyProject = artifacts.require("./OdysseyProject.sol");
const IterableMapping = artifacts.require("./IterableMapping.sol");
const Odyssey = artifacts.require("./Odyssey.sol");

module.exports = function (deployer) {
  deployer.deploy(IterableMapping);
  deployer.link(IterableMapping, OdysseyRewards);
  deployer.deploy(OdysseyRewards, 'test', '$TEST');
  deployer.link(IterableMapping, Odyssey);
  deployer.deploy(Odyssey);
  deployer.link(IterableMapping, OdysseyProject);
  deployer.deploy(OdysseyProject);
};
