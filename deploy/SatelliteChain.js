const LZ_ENDPOINTS = require('../constants/layerzeroEndpoints.json')

module.exports = async function () {
  const {
    deployments: { deploy },
    getNamedAccounts,
  } = hre;
  const { deployer } = await getNamedAccounts();
  console.log(`>>> SatelliteChain Owner address: ${deployer}`);

  // get the Endpoint address
  const endpointAddr = LZ_ENDPOINTS[hre.network.name];
  console.log(`[${hre.network.name}] Endpoint address: ${endpointAddr}`);

  await deploy("SatelliteChain", {
    from: deployer,
    args: [endpointAddr],
    log: true,
    waitConfirmations: 1,
  });
};

module.exports.tags = ["SatelliteChain"];
