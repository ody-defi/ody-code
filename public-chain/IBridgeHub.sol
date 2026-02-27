// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {L2Types} from "./L2Types.sol";

interface IBridgeHub {
    function initiateDeposit(address token, address to, uint256 amount, bytes calldata data) external payable returns (bytes32 depositId);
    function initiateWithdrawal(address token, address l1Receiver, uint256 amount, bytes calldata data) external returns (bytes32 withdrawalId);
    function finalizeWithdrawal(L2Types.Withdrawal calldata w, bytes calldata proof) external;
}
