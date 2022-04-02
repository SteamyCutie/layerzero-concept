// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

interface IPOCDeployment {

    function updateCounter(uint16 _chainId, bytes memory _dstAddress, uint _amount, string memory _method) external payable;

    function requestCounter(uint16 _chainId, bytes memory _dstAddress) external payable;

}