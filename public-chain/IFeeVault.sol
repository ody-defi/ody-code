// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IFeeVault {
    function feeToken() external view returns (address);
    function feeBalance() external view returns (uint256);
    function settleBatchFee(uint256 batchId, address beneficiary, uint256 amount) external;
}
