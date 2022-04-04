const CHAIN_ID = require('../constants/chainIds.json')

function sleep(millis) {
  return new Promise((resolve) => setTimeout(resolve, millis))
}

module.exports = async function (taskArgs, hre) {
  const dstChainId = CHAIN_ID[taskArgs.targetNetwork]
  console.log(`owner:`, (await ethers.getSigners())[0].address)
  const satelliteChain = await ethers.getContract("SatelliteChain")
  console.log(`SatelliteChain: ${satelliteChain.address}`)

  while (true) {
    let counter = await satelliteChain.getCounter(dstChainId)
    console.log(`[${hre.network.name}] ${new Date().toISOString().split("T")[1].split(".")[0]} counter...    ${counter}`)
    await sleep(1000)
  }
}