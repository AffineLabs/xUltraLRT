// SPDX-License-Identifier: BUSL-1.1
pragma solidity =0.8.20;

interface IUltraLRT {
    function getRate() external view returns (uint256);
    function governance() external view returns (address);
    function asset() external view returns (address);
    function decimals() external view returns (uint8);
    function convertToAssets(uint256 _shares) external view returns (uint256);
}
