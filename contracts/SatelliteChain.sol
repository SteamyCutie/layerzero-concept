// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./interfaces/ILayerZeroReceiver.sol";
import "./interfaces/ILayerZeroEndpoint.sol";
import "./interfaces/ILayerZeroUserApplicationConfig.sol";
import "./interfaces/IPOCDeployment.sol";

contract SatelliteChain is
    Ownable,
    ILayerZeroReceiver,
    ILayerZeroUserApplicationConfig
{
    mapping(uint16 => int256) public counters;
    ILayerZeroEndpoint public endpoint;

    uint16 masterChainId;
    bytes masterAddress;

    constructor(address _endpoint) {
        endpoint = ILayerZeroEndpoint(_endpoint);
    }

    function getCounter(uint16 chainId) public view returns (int256) {
        return counters[chainId];
    }

    function sendCounter() public payable {
        bytes memory _params = abi.encode(
            "SET",
            uint16(0),
            bytes(""),
            counters[endpoint.getChainId()]
        );
        endpoint.send{value: msg.value}(
            masterChainId,
            masterAddress,
            _params,
            payable(msg.sender),
            address(0x0),
            bytes("")
        );
    }

    function requestCounter(uint16 _chainId, bytes memory _dstAddress)
        external
        payable
    {
        bytes memory _params = abi.encode(
            "GET",
            _chainId,
            _dstAddress,
            int256(0)
        );
        endpoint.send{value: msg.value}(
            masterChainId,
            masterAddress,
            _params,
            payable(msg.sender),
            address(0x0),
            bytes("")
        );
    }

    // overrides lzReceive function in ILayerZeroReceiver.
    // automatically invoked on the receiving chain after the source chain calls endpoint.send(...)
    function lzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64, /*_nonce*/
        bytes memory _payload
    ) external override {
        require(msg.sender == address(endpoint));
        require(
            _srcChainId == masterChainId &&
                _srcAddress.length == masterAddress.length &&
                keccak256(_srcAddress) == keccak256(masterAddress),
            "Invalid remote sender address. owner should call setRemote() to enable remote contract"
        );
        string memory method;
        uint16 chainId;
        int256 amount;
        (method, chainId, amount) = abi.decode(
            _payload,
            (string, uint16, int256)
        );
        if (keccak256(bytes(method)) == keccak256(bytes("SET"))) {
            counters[chainId] = amount;
        }
        sendCounter();
    }

    function setConfig(
        uint16, /*_version*/
        uint16 _chainId,
        uint256 _configType,
        bytes calldata _config
    ) external override {
        endpoint.setConfig(
            endpoint.getSendVersion(address(this)),
            _chainId,
            _configType,
            _config
        );
    }

    function getConfig(
        uint16, /*_dstChainId*/
        uint16 _chainId,
        address,
        uint256 _configType
    ) external view returns (bytes memory) {
        return
            endpoint.getConfig(
                endpoint.getSendVersion(address(this)),
                _chainId,
                address(this),
                _configType
            );
    }

    function setSendVersion(uint16 version) external override {
        endpoint.setSendVersion(version);
    }

    function setReceiveVersion(uint16 version) external override {
        endpoint.setReceiveVersion(version);
    }

    function getSendVersion() external view returns (uint16) {
        return endpoint.getSendVersion(address(this));
    }

    function getReceiveVersion() external view returns (uint16) {
        return endpoint.getReceiveVersion(address(this));
    }

    function forceResumeReceive(uint16 _srcChainId, bytes calldata _srcAddress)
        external
        override
    {
        //
    }

    // set the Oracle to be used by this UA for LayerZero messages
    function setOracle(uint16 dstChainId, address oracle) external {
        uint256 TYPE_ORACLE = 6; // from UltraLightNode
        // set the Oracle
        endpoint.setConfig(
            endpoint.getSendVersion(address(this)),
            dstChainId,
            TYPE_ORACLE,
            abi.encode(oracle)
        );
    }

    // _chainId - the chainId for the remote contract
    // _masterAddress - the contract address on the remote chainId
    // the owner must set remote contract addresses.
    // in lzReceive(), a require() ensures only messages
    // from known contracts can be received.
    function setRemote(uint16 _chainId, bytes calldata _masterAddress)
        external
        onlyOwner
    {
        require(
            masterAddress.length == 0,
            "The remote address has already been set for the chainId!"
        );
        masterChainId = _chainId;
        masterAddress = _masterAddress;
    }

    // set the inbound block confirmations
    function setInboundConfirmations(
        uint16 _masterChainId,
        uint16 _confirmations
    ) external {
        endpoint.setConfig(
            endpoint.getSendVersion(address(this)),
            _masterChainId,
            2, // CONFIG_TYPE_INBOUND_BLOCK_CONFIRMATIONS
            abi.encode(_confirmations)
        );
    }

    // set outbound block confirmations
    function setOutboundConfirmations(
        uint16 _masterChainId,
        uint16 _confirmations
    ) external {
        endpoint.setConfig(
            endpoint.getSendVersion(address(this)),
            _masterChainId,
            5, // CONFIG_TYPE_OUTBOUND_BLOCK_CONFIRMATIONS
            abi.encode(_confirmations)
        );
    }

    // allow this contract to receive ether
    fallback() external payable {}

    receive() external payable {}
}
