// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IOpStackCompatibility {
    // Messenger alias surface
    function l1CrossDomainMessenger() external view returns (address);
    function l2CrossDomainMessenger() external view returns (address);

    // Portal / bridge alias surface
    function optimismPortal() external view returns (address);
    function l1StandardBridge() external view returns (address);
    function l2StandardBridge() external view returns (address);

    // Output/finality alias surface
    function l2OutputOracle() external view returns (address);
    function challengeWindow() external view returns (uint256);

    // Sequencer/system config alias surface
    function systemConfig() external view returns (address);
    function sequencerInbox() external view returns (address);
}
