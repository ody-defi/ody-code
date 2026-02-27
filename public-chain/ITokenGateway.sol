// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {L2Types} from "./L2Types.sol";

interface ITokenGateway {
    function registerTokenPair(L2Types.TokenPair calldata pair) external;
    function updateTokenPairStatus(address l1Token, address l2Token, bool active) external;
    function getTokenPairByL1(address l1Token) external view returns (L2Types.TokenPair memory);
    function getTokenPairByL2(address l2Token) external view returns (L2Types.TokenPair memory);
}
