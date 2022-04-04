const CHAIN_ID = require('../constants/chainIds.json')
const { getDeploymentAddresses } = require('../utils/readStatic')

module.exports = async function (taskArgs, hre) {
  const dstChainId = CHAIN_ID[taskArgs.targetNetwork]
  const dstAddr = getDeploymentAddresses(taskArgs.targetNetwork)["SatelliteChain"]
  // get local contract instance
  const masterChain = await ethers.getContract("MasterChain")
  console.log(`[source] masterChain.address: ${masterChain.address}`)

  // setRemote() on the local contract, so it can receive message from the remote contract
  try {
    let tx = await (await masterChain.setRemote(
      dstChainId,
      dstAddr
    )).wait()
    console.log(`✅ [${hre.network.name}] setRemote(${dstChainId}, ${dstAddr})`)
    console.log(` tx: ${tx.transactionHash}`)
  } catch (e) {
    if (e.error?.message.includes("The remote address has already been set for the chainId")) { console.log('*remote already set*') }
    else { console.log(e) }
  }
}