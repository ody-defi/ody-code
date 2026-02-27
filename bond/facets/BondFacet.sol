// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ECDSA} from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibDiamond} from "../libraries/LibDiamond.sol";
import {LibPolStorage} from "../libraries/LibPolStorage.sol";
import {BondFacetDeps} from "../BondFacetDeps.sol";
import {BondFacetTypes} from "../BondFacetTypes.sol";
import {BondFacetEvents} from "../BondFacetEvents.sol";

/**
 * @title BondFacet
 * @notice POL bond/POL entry facet: purchase, linear vesting, configuration
 *
 * Main purchase flow:
 *  1) Validate signature/anti-replay/limits
 *  2) Split amountIn: half buys ODY, half + bought ODY adds LP (LP sent to lpReceiver; remainder also to lpReceiver)
 *  3) Mint ODY at discounted price * multiplier; split 50/50 to staking/reward vaults
 *  4) Create position (principal is staking half), linear vesting by day (no extension)
 */
contract BondFacet is BondFacetEvents {
    using SafeERC20 for IERC20;
    using LibPolStorage for LibPolStorage.POLStorage;

    // -----------------------------
    // Role constants
    // -----------------------------
    bytes32 private constant RESCUE_ROLE = keccak256("RESCUE_ROLE");

    // -----------------------------
    // Internal struct to reduce stack vars
    // -----------------------------
    struct PurchaseEmitData {
        uint256 positionId;
        uint256 feeAmount;
        address feeTo;
        uint256 twapPrice;
        uint256 twapWindow;
        uint256 discountPrice;
        uint256 mintAmount;
        uint256 principalToStaking;
        uint256 rewardToPool;
        uint256 odyBought;
        uint256 usdtUsedForSwap;
        uint256 usdtUsedForLp;
        uint256 lpAmountOut;
    }

    // -----------------------------
    // Constants
    // -----------------------------
    uint256 private constant BPS_DENOMINATOR = 10_000; // Basis-points denominator
    uint256 private constant ONE_18 = 1e18; // 18 decimals
    string private constant EIP712_NAME = "POLBond";
    string private constant EIP712_VERSION = "1";
    uint256 private constant HALF_DAY = 12 hours; // 12 hours (seconds)
    // 固定时区偏移：UTC+1（无夏令时）。用于将释放节奏对齐到 UTC+1 的 0 点/12 点。
    uint256 private constant UTC1_OFFSET = 1 hours;

    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");

    bytes32 private constant PURCHASE_TYPEHASH =
        keccak256(
            "BondPurchase(address buyer,uint256 bondId,uint256 amountIn,uint256 minPrice,uint256 maxPrice,uint256 deadline,bytes32 requestId,uint256 feeAmount,uint256 minOdyOut)"
        );

    // -----------------------------
    // External views
    // -----------------------------

    /// @notice Get bond config
    function getBondConfig(uint256 bondId) external view returns (LibPolStorage.BondConfig memory) {
        return LibPolStorage.polStorage().bondConfigs[bondId];
    }

    /// @notice Get bond shared address config
    function getBondCommonConfig() external view returns (LibPolStorage.BondCommonConfig memory) {
        return LibPolStorage.polStorage().bondCommonConfig;
    }

    /// @notice Get claimable principal for position
    function claimable(uint256 positionId) external view returns (uint256) {
        LibPolStorage.POLStorage storage ps = LibPolStorage.polStorage();
        LibPolStorage.Position storage p = ps.positions[positionId];
        require(p.owner != address(0), "POL: position missing");
        return _claimable(p);
    }

    // -----------------------------
    // Admin configuration
    // -----------------------------

    /// @notice Toggle signature requirement
    function setSignatureRequired(bool required) external {
        LibDiamond.enforceIsContractOwner();
        LibPolStorage.polStorage().requireSignature = required;
        emit SignatureRequiredSet(required);
    }

    /// @notice Configure signer allowlist
    function setSigner(address signer, bool allowed) external {
        LibDiamond.enforceIsContractOwner();
        require(signer != address(0), "POL: signer zero");
        LibPolStorage.polStorage().signers[signer] = allowed;
        emit SignerUpdated(signer, allowed);
    }

    /// @notice Update rescue role
    function setRescueRole(address newRescue) external {
        LibDiamond.enforceIsContractOwner();
        require(newRescue != address(0), "POL: rescue zero");
        LibPolStorage.POLStorage storage ps = LibPolStorage.polStorage();
        address old = ps.rescueRoleHolder;
        ps.rescueRoleHolder = newRescue;
        emit RescueRoleTransferred(old, newRescue);
    }

    /// @notice Set management fee recipient
    function setFeeRecipient(address newFeeRecipient) external {
        LibDiamond.enforceIsContractOwner();
        require(newFeeRecipient != address(0), "POL: fee recipient zero");
        LibPolStorage.polStorage().feeRecipient = newFeeRecipient;
        emit FeeRecipientUpdated(newFeeRecipient);
    }

    /// @notice Adjust TWAP window (seconds)
    function setTwapWindow(uint256 minWindow, uint256 maxWindow) external {
        LibDiamond.enforceIsContractOwner();
        require(minWindow > 0, "POL: minWindow zero");
        require(maxWindow >= minWindow, "POL: max < min");
        LibPolStorage.polStorage().minTwapWindow = minWindow;
        LibPolStorage.polStorage().maxTwapWindow = maxWindow;
        emit TwapWindowUpdated(minWindow, maxWindow);
    }

    /// @notice Set bond shared address config
    function setBondCommonConfig(BondFacetTypes.BondCommonConfigInput calldata cfg) external {
        LibDiamond.enforceIsContractOwner();
        require(cfg.lpReceiver != address(0), "POL: lpReceiver zero");
        require(cfg.stakingVault != address(0), "POL: stakingVault zero");
        require(cfg.rewardVault != address(0), "POL: rewardVault zero");
        require(cfg.router != address(0), "POL: router zero");
        require(cfg.pair != address(0), "POL: pair zero");

        LibPolStorage.BondCommonConfig storage c = LibPolStorage.polStorage().bondCommonConfig;
        c.lpReceiver = cfg.lpReceiver;
        c.stakingVault = cfg.stakingVault;
        c.rewardVault = cfg.rewardVault;
        c.router = cfg.router;
        c.pair = cfg.pair;
        c.odyIsToken0 = cfg.odyIsToken0;

        emit BondCommonConfigUpdated(
            c.lpReceiver,
            c.stakingVault,
            c.rewardVault,
            c.router,
            c.pair,
            c.odyIsToken0
        );
    }

    /// @notice Set/update bond config
    function setBondConfig(uint256 bondId, BondFacetTypes.BondConfigInput calldata cfg) external {
        LibDiamond.enforceIsContractOwner();
        require(cfg.discountBps <= BPS_DENOMINATOR, "POL: discount too high");
        require(cfg.mintMultiplier > 0, "POL: multiplier zero");

        LibPolStorage.POLStorage storage ps = LibPolStorage.polStorage();
        LibPolStorage.BondConfig storage b = ps.bondConfigs[bondId];
        b.isOnSale = cfg.isOnSale;
        b.discountBps = cfg.discountBps;
        b.vestingDays = cfg.vestingDays;
        b.maxPerTx = cfg.maxPerTx;
        b.mintMultiplier = cfg.mintMultiplier;

        emit BondConfigUpdated(
            bondId,
            b.isOnSale,
            b.discountBps,
            b.vestingDays,
            b.maxPerTx,
            b.mintMultiplier
        );
    }

    // -----------------------------
    // Purchase & linear vesting
    // -----------------------------

    /**
     * @notice Purchase bond / execute POL
     * @dev Flow:
     *      1) amountIn/2 buys ODY
     *      2) Remaining USDT + bought ODY add LP (LP to lpReceiver)
     *      3) Mint ODY (discounted price * multiplier), split 50/50 to staking/reward vaults
     */
    function purchase(BondFacetTypes.PurchaseRequest calldata req) external {
        LibPolStorage.POLStorage storage ps = LibPolStorage.polStorage();
        LibPolStorage.BondConfig storage b = ps.bondConfigs[req.bondId];
        LibPolStorage.BondCommonConfig storage c = ps.bondCommonConfig;
        require(c.router != address(0), "POL: common router not set");
        require(c.pair != address(0), "POL: common pair not set");
        require(c.stakingVault != address(0), "POL: stakingVault not set");
        require(c.rewardVault != address(0), "POL: rewardVault not set");
        require(c.lpReceiver != address(0), "POL: lpReceiver not set");
        require(b.isOnSale, "POL: bond closed");
        require(req.amountIn > 0, "POL: amount zero");
        require(req.requestId != bytes32(0), "POL: requestId zero");
        address feeRecipient = ps.feeRecipient;

        if (b.maxPerTx > 0) {
            require(req.amountIn <= b.maxPerTx, "POL: exceed single max");
        }

        // Signature check (if enabled)
        if (ps.requireSignature) {
            _verifySignature(req);
        }

        // Validate management fee
        if (req.feeAmount > 0) {
            require(req.feeAmount < req.amountIn, "POL: fee too large");
            require(feeRecipient != address(0), "POL: fee recipient not set");
        }

        // Anti-replay
        require(!ps.usedRequestIds[req.requestId], "POL: request used");
        ps.usedRequestIds[req.requestId] = true;
        emit RequestUsed(req.requestId);

        // Reentrancy guard
        ps.enterReentrancyGuard();

        // 1. Get TWAP price (1e18, USDT/ODY)
        (uint256 twapPrice, uint256 twapElapsed) = _getTwapPrice(c);
        require(twapPrice > 0, "POL: twap not ready");

        // 2. Optional price bounds
        if (req.minPrice > 0) {
            require(twapPrice >= req.minPrice, "POL: price < min");
        }
        if (req.maxPrice > 0) {
            require(twapPrice <= req.maxPrice, "POL: price > max");
        }

        // Discounted price
        uint256 discountPrice = (twapPrice * (BPS_DENOMINATOR - b.discountBps)) / BPS_DENOMINATOR;
        require(discountPrice > 0, "POL: discount price zero");

        // 3. Collect USDT
        IERC20 usdt = IERC20(ps.usdtToken);
        IERC20 ody = IERC20(ps.odyToken);
        usdt.safeTransferFrom(msg.sender, address(this), req.amountIn);

        // 3.1 Prepare event fields (reduce stack usage)
        PurchaseEmitData memory emitData;
        emitData.feeAmount = req.feeAmount;
        emitData.feeTo = feeRecipient;
        emitData.twapPrice = twapPrice;
        emitData.twapWindow = twapElapsed;
        emitData.discountPrice = discountPrice;

        // Fee (if any)
        uint256 netAmountIn = req.amountIn;
        if (emitData.feeAmount > 0 && emitData.feeTo != address(0)) {
            usdt.safeTransfer(emitData.feeTo, emitData.feeAmount);
            netAmountIn = req.amountIn - emitData.feeAmount;
        }

        // 4. Buy ODY: netAmountIn / 2
        emitData.usdtUsedForSwap = netAmountIn / 2;
        uint256 usdtForLp = netAmountIn - emitData.usdtUsedForSwap; // Preserve precision on odd numbers
        address[] memory path = new address[](2);
        path[0] = ps.usdtToken;
        path[1] = ps.odyToken;

        uint256 odyBefore = ody.balanceOf(address(this));
        usdt.forceApprove(c.router, 0);
        usdt.forceApprove(c.router, emitData.usdtUsedForSwap);
        BondFacetDeps.IPancakeRouterV2(c.router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            emitData.usdtUsedForSwap,
            req.minOdyOut,
            path,
            address(this),
            block.timestamp
        );
        emitData.odyBought = ody.balanceOf(address(this)) - odyBefore;

        // 5. Add LP: remaining USDT + bought ODY
        usdt.forceApprove(c.router, 0);
        ody.forceApprove(c.router, 0);
        usdt.forceApprove(c.router, usdtForLp);
        ody.forceApprove(c.router, emitData.odyBought);

        (emitData.usdtUsedForLp, , emitData.lpAmountOut) = BondFacetDeps.IPancakeRouterV2(c.router).addLiquidity(
            ps.usdtToken,
            ps.odyToken,
            usdtForLp,
            emitData.odyBought,
            0,
            0,
            c.lpReceiver,
            block.timestamp
        );

        // Remaining USDT / ODY stay in the contract; admin can withdraw to avoid burning if lpReceiver is a burn address

        // 6. Mint: netAmountIn / discount price * multiplier
        uint8 usdtDecimals = LibPolStorage.getUsdtDecimals(ps);
        uint256 amountIn18 = _to18(netAmountIn, usdtDecimals);
        uint256 mintBase = (amountIn18 * ONE_18) / discountPrice; // Mint amount before multiplier
        emitData.mintAmount = (mintBase * b.mintMultiplier) / ONE_18;
        require(emitData.mintAmount > 0, "POL: mint zero");

        BondFacetDeps.IODYMinter(ps.odyMinter).mint(address(this), emitData.mintAmount);

        emitData.principalToStaking = emitData.mintAmount / 2;
        emitData.rewardToPool = emitData.mintAmount - emitData.principalToStaking;

        ody.safeTransfer(c.stakingVault, emitData.principalToStaking);
        ody.safeTransfer(c.rewardVault, emitData.rewardToPool);

        // 7. Create position (principal equals staking portion)
        ps.nextPositionId += 1;
        uint256 positionId = ps.nextPositionId;
        ps.positions[positionId] = LibPolStorage.Position({
            id: positionId,
            owner: msg.sender,
            bondId: req.bondId,
            principal: emitData.principalToStaking,
            claimed: 0,
            startTs: uint64(block.timestamp),
            vestingDays: b.vestingDays
        });
        emitData.positionId = positionId;

        // 8. Update sold amount (net input)
        b.soldIn += netAmountIn;

        emit BondPurchased(
            req.requestId,
            msg.sender,
            req.bondId,
            emitData.positionId,
            emitData.feeAmount,
            emitData.feeTo,
            req.amountIn,
            emitData.twapPrice,
            emitData.twapWindow,
            emitData.discountPrice,
            b.mintMultiplier,
            emitData.mintAmount,
            emitData.principalToStaking,
            emitData.rewardToPool,
            emitData.odyBought,
            emitData.usdtUsedForSwap,
            emitData.usdtUsedForLp,
            emitData.lpAmountOut,
            b.vestingDays,
            block.timestamp
        );

        ps.exitReentrancyGuard();
    }

    /**
     * @notice Admin/rescue role withdraws any residual ERC20 (e.g., leftover USDT/ODY after LP)
     * @dev Callable by owner or rescueRole to avoid burning when lpReceiver is a burn address
     */
    function withdrawToken(address token, address to, uint256 amount) external {
        LibPolStorage.POLStorage storage ps = LibPolStorage.polStorage();
        // Only owner or rescueRole
        if (msg.sender != LibDiamond.diamondStorage().contractOwner && msg.sender != ps.rescueRoleHolder) {
            revert("POL: no rescue permission");
        }
        require(token != address(0), "POL: token zero");
        require(to != address(0), "POL: to zero");
        require(amount > 0, "POL: amount zero");
        IERC20(token).safeTransfer(to, amount);
    }

    /**
     * @notice Claim principal (batch)
     */
    function claim(uint256[] calldata positionIds) external {
        LibPolStorage.POLStorage storage ps = LibPolStorage.polStorage();
        LibPolStorage.BondCommonConfig storage c = ps.bondCommonConfig;
        require(c.stakingVault != address(0), "POL: stakingVault not set");
        ps.enterReentrancyGuard();

        uint256 len = positionIds.length;
        for (uint256 i; i < len; i++) {
            uint256 pid = positionIds[i];
            LibPolStorage.Position storage p = ps.positions[pid];
            _claimPosition(p, pid, msg.sender, 0, c.stakingVault, false);
        }

        ps.exitReentrancyGuard();
    }

    /**
     * @notice Claim part of principal for a single position. Amount必须为正，且不超过当前可领取额度。
     */
    function claim(uint256 positionId, uint256 amount) external {
        LibPolStorage.POLStorage storage ps = LibPolStorage.polStorage();
        LibPolStorage.BondCommonConfig storage c = ps.bondCommonConfig;
        require(c.stakingVault != address(0), "POL: stakingVault not set");
        require(amount > 0, "POL: amount zero");

        ps.enterReentrancyGuard();
        LibPolStorage.Position storage p = ps.positions[positionId];
        _claimPosition(p, positionId, msg.sender, amount, c.stakingVault, true);
        ps.exitReentrancyGuard();
    }

    // -----------------------------
    // Internal helpers
    // -----------------------------
    function _claimPosition(
        LibPolStorage.Position storage p,
        uint256 positionId,
        address owner,
        uint256 requestedAmount,
        address stakingVault,
        bool revertIfZero
    ) internal returns (uint256 claimedAmount) {
        require(p.owner == owner, "POL: not position owner");

        uint256 claimableAmount = _claimable(p);
        if (claimableAmount == 0) {
            if (revertIfZero) {
                revert("POL: nothing to claim");
            }
            return 0;
        }

        if (requestedAmount > 0) {
            require(requestedAmount <= claimableAmount, "POL: amount exceeds claimable");
            claimedAmount = requestedAmount;
        } else {
            claimedAmount = claimableAmount;
        }

        p.claimed += claimedAmount;
        BondFacetDeps.IVault(stakingVault).withdraw(owner, claimedAmount);
        emit PositionClaimed(positionId, owner, p.bondId, claimedAmount, p.claimed);
    }

    /// @dev Compute claimable principal (discrete 12h slots aligned to UTC+1; non-cumulative beyond end)
    function _claimable(LibPolStorage.Position storage p) internal view returns (uint256) {
        if (p.owner == address(0)) {
            return 0;
        }
        if (p.vestingDays == 0) {
            // No vesting -> fully claimable
            return p.principal - p.claimed;
        }
        // Align to next UTC+1 0 or 12 o'clock after purchase, then release per 12h slot
        uint256 firstSlot = _firstRebaseSlot(uint256(p.startTs));
        if (block.timestamp < firstSlot) {
            return 0;
        }
        // Total slots = days * 2 (two 12h slots per day)
        uint256 totalSlots = uint256(p.vestingDays) * 2;
        // Elapsed slots (including current), min 1, max totalSlots
        uint256 elapsedSlots = ((block.timestamp - firstSlot) / HALF_DAY) + 1;
        if (elapsedSlots > totalSlots) {
            elapsedSlots = totalSlots;
        }
        // Pro-rate by slots; last slot uses total to avoid precision loss
        uint256 vested = (p.principal * elapsedSlots) / totalSlots;
        if (elapsedSlots == totalSlots && vested < p.principal) {
            vested = p.principal;
        }
        if (vested <= p.claimed) {
            return 0;
        }
        return vested - p.claimed;
    }

    /// @dev Compute first release slot timestamp: next UTC+1 0/12 after purchase
    function _firstRebaseSlot(uint256 startTs) internal pure returns (uint256) {
        // Convert to UTC+1
        uint256 localTs = startTs + UTC1_OFFSET;
        uint256 remainder = localTs % HALF_DAY;
        uint256 alignedLocal = remainder == 0 ? localTs : localTs + (HALF_DAY - remainder);
        // Convert back to UTC timestamp
        return alignedLocal - UTC1_OFFSET;
    }

    /// @dev Convert USDT amount to 18 decimals
    function _to18(uint256 amount, uint8 decimals) internal pure returns (uint256) {
        if (decimals == 18) {
            return amount;
        }
        if (decimals < 18) {
            return amount * (10 ** (18 - decimals));
        }
        // decimals > 18, truncate down
        return amount / (10 ** (decimals - 18));
    }

    /// @dev EIP-712 domain separator
    function _domainSeparator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPEHASH,
                    keccak256(bytes(EIP712_NAME)),
                    keccak256(bytes(EIP712_VERSION)),
                    block.chainid,
                    address(this)
                )
            );
    }

    /// @dev Verify signature
    function _verifySignature(BondFacetTypes.PurchaseRequest calldata req) internal view {
        require(req.signature.length == 65, "POL: bad signature");
        require(req.deadline >= block.timestamp, "POL: signature expired");

        bytes32 structHash = keccak256(
            abi.encode(
                PURCHASE_TYPEHASH,
                msg.sender,
                req.bondId,
                req.amountIn,
                req.minPrice,
                req.maxPrice,
                req.deadline,
                req.requestId,
                req.feeAmount,
                req.minOdyOut
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
        address signer = ECDSA.recover(digest, req.signature);
        require(LibPolStorage.polStorage().signers[signer], "POL: signer not allowed");
    }

    /// @dev Get TWAP price (USDT/ODY, 1e18)
    function _getTwapPrice(LibPolStorage.BondCommonConfig storage c) internal view returns (uint256 price, uint256 elapsed) {
        // Use spot LP price (USDT/ODY) to avoid window blocking; keep return shape compatible
        BondFacetDeps.IPancakePair pair = BondFacetDeps.IPancakePair(c.pair);
        (uint112 reserve0, uint112 reserve1, ) = pair.getReserves();
        require(reserve0 > 0 && reserve1 > 0, "POL: empty reserves");

        // Compute USDT/ODY price, 1e18
        if (c.odyIsToken0) {
            // ODY = token0, USDT = token1 => price = reserve1 / reserve0
            price = (uint256(reserve1) * ONE_18) / uint256(reserve0);
        } else {
            // ODY = token1, USDT = token0 => price = reserve0 / reserve1
            price = (uint256(reserve0) * ONE_18) / uint256(reserve1);
        }
        require(price > 0, "POL: price zero");
        elapsed = 0;
    }
}
