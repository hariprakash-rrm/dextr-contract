const { deployProxy, upgradeProxy } = require('@openzeppelin/truffle-upgrades');
const dextrStaking = artifacts.require("DextrStaking");

module.exports = async function (deployer) {
  // await deployProxy(dextrStaking,{ deployer, kind: "uups" });
  // await upgradeProxy("0x9f8Bdd838d5A6A90F921B11b65A4E7Cd9AdBc808", dextrStaking, { deployer });

};
