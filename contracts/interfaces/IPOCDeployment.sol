// SPDX-License-Identifier: BUSL-1.1

pragma solidity ^0.8.4;

interface IPOCDeployment {
    function updateCounter(
        uint16 _chainId,
        bytes memory _dstAddress,
        int256 _amount,
        string memory _method
    ) external payable;

    function sendCounter(
        uint16 _dstChainId,
        bytes memory _dstAddress,
        uint16 _srcChainId
    ) external payable;
}
