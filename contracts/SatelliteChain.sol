// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;
pragma abicoder v2;

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
    // keep track of how many messages have been received from other chains
    uint256 public counter;
    // required: the LayerZero endpoint which is passed in the constructor
    ILayerZeroEndpoint public endpoint;

    uint16 remoteChainId;
    bytes remoteAddress;

    constructor(address _endpoint) {
        endpoint = ILayerZeroEndpoint(_endpoint);
    }

    function getCounter() public view returns (uint256) {
        return counter;
    }

    function sendCounter(uint16 _remoteChainId, bytes memory _remoteAddress)
        public
        payable
    {
        endpoint.send{value: msg.value}(
            _remoteChainId,
            _remoteAddress,
            abi.encodePacked(counter),
            payable(msg.sender),
            address(0x0),
            bytes("")
        );
    }

    function requestCounter(uint16 _chainId, bytes memory _dstAddress)
        external
        payable
    {
        endpoint.send{value: msg.value}(
            _chainId,
            _dstAddress,
            bytes(""),
            payable(msg.sender),
            address(0x0),
            bytes("COUNTER")
        );
    }

    function toUint256(bytes memory _bytes) internal pure returns (uint256) {
        require(_bytes.length >= 32, "toUint256_outOfBounds");
        uint256 tempUint;
        assembly {
            tempUint := mload(add(_bytes, 0x20))
        }
        return tempUint;
    }

    // overrides lzReceive function in ILayerZeroReceiver.
    // automatically invoked on the receiving chain after the source chain calls endpoint.send(...)
    function lzReceive(
        uint16 _srcChainId,
        bytes memory _srcAddress,
        uint64, /*_nonce*/
        bytes memory _payload
    ) external override {
        // boilerplate: only allow this endpiont to be the caller of lzReceive!
        require(msg.sender == address(endpoint));
        // owner must have setRemote() to allow its remote contracts to send to this contract
        require(
            _srcChainId == remoteChainId &&
                _srcAddress.length == remoteAddress.length &&
                keccak256(_srcAddress) == keccak256(remoteAddress),
            "Invalid remote sender address. owner should call setRemote() to enable remote contract"
        );
        bytes memory expect = bytes("COUNTER");
        if (
            _payload.length == expect.length &&
            keccak256(_payload) == keccak256(expect)
        ) sendCounter(remoteChainId, remoteAddress);
        else {
            counter = toUint256(_payload);
            sendCounter(remoteChainId, remoteAddress);
        }
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
    // _remoteAddress - the contract address on the remote chainId
    // the owner must set remote contract addresses.
    // in lzReceive(), a require() ensures only messages
    // from known contracts can be received.
    function setRemote(uint16 _chainId, bytes calldata _remoteAddress)
        external
        onlyOwner
    {
        require(
            remoteAddress.length == 0,
            "The remote address has already been set for the chainId!"
        );
        remoteChainId = _chainId;
        remoteAddress = _remoteAddress;
    }

    // set the inbound block confirmations
    function setInboundConfirmations(
        uint16 _remoteChainId,
        uint16 _confirmations
    ) external {
        endpoint.setConfig(
            endpoint.getSendVersion(address(this)),
            _remoteChainId,
            2, // CONFIG_TYPE_INBOUND_BLOCK_CONFIRMATIONS
            abi.encode(_confirmations)
        );
    }

    // set outbound block confirmations
    function setOutboundConfirmations(
        uint16 _remoteChainId,
        uint16 _confirmations
    ) external {
        endpoint.setConfig(
            endpoint.getSendVersion(address(this)),
            _remoteChainId,
            5, // CONFIG_TYPE_OUTBOUND_BLOCK_CONFIRMATIONS
            abi.encode(_confirmations)
        );
    }

    // allow this contract to receive ether
    fallback() external payable {}

    receive() external payable {}
}
