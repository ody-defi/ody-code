// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {EconomyTypes} from "./EconomyTypes.sol";

interface IEconomyBank {
    function getBalanceSheet(address player) external view returns (EconomyTypes.BalanceSheet memory);
    function getRecord(bytes32 recordId) external view returns (EconomyTypes.SinkSourceRecord memory);
}
