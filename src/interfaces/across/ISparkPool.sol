// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity >=0.8.0;

interface ISparkPool {
    function depositV3(
        address depositor,
        address recipient,
        address inputToken,
        address outputToken,
        uint256 inputAmount,
        uint256 outputAmount,
        uint256 destinationChainId,
        address exclusiveRelayer,
        uint32 quoteTimestamp,
        uint32 fillDeadline,
        uint32 exclusivityDeadline,
        bytes calldata message
    ) external payable;

    function fillDeadlineBuffer() external view returns (uint32);
}
