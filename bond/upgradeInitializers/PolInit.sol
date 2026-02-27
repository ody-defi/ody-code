// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibPolStorage} from "../libraries/LibPolStorage.sol";
import {IDiamondCut} from "../interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "../interfaces/IDiamondLoupe.sol";
import {IERC173} from "../interfaces/IERC173.sol";

/**
 * @title PolInit
 * @notice Initialization entry after deploying/upgrading the Diamond (via diamondCut)
 */
contract PolInit {
    using LibPolStorage for LibPolStorage.POLStorage;

    /// @notice Initialization args
    struct InitArgs {
        address odyToken; // ODY token
        address usdtToken; // USDT token
        address odyMinter; // ODY mint gateway
        uint8 usdtDecimals; // USDT decimals (0 to autodetect)
        uint256 minTwapWindow; // Min TWAP window, recommend 1800
        uint256 maxTwapWindow; // Max TWAP window, recommend 7200
        bool requireSignature; // Whether to enforce signature gate
        address signer; // Initial signer (optional)
        address lpReceiver; // LP receiver (bond common config)
        address stakingVault; // Staking vault
        address rewardVault; // Reward vault
        address router; // Router address
        address pair; // Pricing pair
        bool odyIsToken0; // Whether ODY is token0 for pricing
    }

    /**
     * @notice Initialize storage, called via diamondCut _init delegatecall
     */
    function init(InitArgs calldata args) external {
        LibDiamond.enforceIsContractOwner();
        require(args.odyToken != address(0), "POL: ody zero");
        require(args.usdtToken != address(0), "POL: usdt zero");
        require(args.odyMinter != address(0), "POL: minter zero");
        require(args.lpReceiver != address(0), "POL: lpReceiver zero");
        require(args.stakingVault != address(0), "POL: stakingVault zero");
        require(args.rewardVault != address(0), "POL: rewardVault zero");
        require(args.router != address(0), "POL: router zero");
        require(args.pair != address(0), "POL: pair zero");

        LibPolStorage.POLStorage storage ps = LibPolStorage.polStorage();
        ps.odyToken = args.odyToken;
        ps.usdtToken = args.usdtToken;
        ps.odyMinter = args.odyMinter;
        ps.usdtDecimals = args.usdtDecimals;
        ps.minTwapWindow = args.minTwapWindow == 0 ? 30 minutes : args.minTwapWindow;
        ps.maxTwapWindow = args.maxTwapWindow == 0 ? 2 hours : args.maxTwapWindow;
        ps.requireSignature = args.requireSignature;
        ps.reentrancyStatus = 1; // Initialize as not entered

        ps.bondCommonConfig.lpReceiver = args.lpReceiver;
        ps.bondCommonConfig.stakingVault = args.stakingVault;
        ps.bondCommonConfig.rewardVault = args.rewardVault;
        ps.bondCommonConfig.router = args.router;
        ps.bondCommonConfig.pair = args.pair;
        ps.bondCommonConfig.odyIsToken0 = args.odyIsToken0;

        if (args.signer != address(0)) {
            ps.signers[args.signer] = true;
        }

        // RESCUE_ROLE: for residue withdrawal, default to owner
        ps.rescueRoleHolder = LibDiamond.diamondStorage().contractOwner;
        // Fee recipient: default to owner, adjustable via BondFacet later
        ps.feeRecipient = LibDiamond.diamondStorage().contractOwner;

        // Declare EIP-165 interfaces for frontends/loupe
        LibDiamond.DiamondStorage storage ds = LibDiamond.diamondStorage();
        ds.supportedInterfaces[type(IDiamondCut).interfaceId] = true;
        ds.supportedInterfaces[type(IDiamondLoupe).interfaceId] = true;
        ds.supportedInterfaces[type(IERC173).interfaceId] = true;
    }
}
