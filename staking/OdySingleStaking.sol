// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";

import {ITokenVault} from "./ITokenVault.sol";
import {OdySingleStakingTypes} from "./OdySingleStakingTypes.sol";
import {OdySingleStakingEvents} from "./OdySingleStakingEvents.sol";

/**
 * @title OdySingleStaking
 * @notice ODY single-token staking (upgradeable, transparent proxy)
 *         - Users deposit ODY; funds go directly to StakingVault (Vault must grant this contract MANAGER_ROLE)
 *         - Linear release by day; only principal claimable; 12h slots aligned to UTC+1 (fixed offset, no DST)
 *         - Each stake authorized by off-chain signature; cycles configurable
 */
contract OdySingleStaking is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    OdySingleStakingEvents
{
    using SafeERC20 for IERC20Metadata;

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // EIP-712
    string private constant EIP712_NAME = "OdySingleStaking";
    string private constant EIP712_VERSION = "1";
    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant STAKE_TYPEHASH =
        keccak256("Stake(address staker,uint256 cycleId,uint256 amount,uint256 feeAmount,uint256 deadline,bytes32 requestId)");

    // Vesting cadence
    uint256 private constant HALF_DAY = 12 hours;
    uint256 private constant UTC1_OFFSET = 1 hours;

    IERC20Metadata public odyToken;
    IERC20Metadata public usdtToken;
    address public stakingVault;
    address public feeRecipient;
    uint8 public usdtDecimals;

    uint256 public nextPositionId;
    mapping(uint256 => OdySingleStakingTypes.Cycle) public cycles; // cycleId => config
    mapping(uint256 => OdySingleStakingTypes.Position) public positions; // positionId => position

    bool public requireSignature;
    mapping(address => bool) public signers;
    mapping(bytes32 => bool) public usedRequestIds;

    constructor() {
        _disableInitializers();
    }

    function initialize(address _odyToken, address _stakingVault, address _usdtToken, address _feeRecipient) external initializer {
        require(_odyToken != address(0), "ODS: ody zero");
        require(_stakingVault != address(0), "ODS: vault zero");
        require(_usdtToken != address(0), "ODS: usdt zero");
        require(_feeRecipient != address(0), "ODS: fee zero");

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        odyToken = IERC20Metadata(_odyToken);
        stakingVault = _stakingVault;
        usdtToken = IERC20Metadata(_usdtToken);
        feeRecipient = _feeRecipient;
        usdtDecimals = IERC20Metadata(_usdtToken).decimals();
        requireSignature = true;
        nextPositionId = 0;

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
    }

    // -----------------------------
    // User actions
    // -----------------------------

    /**
     * @notice Stake ODY; funds go directly to StakingVault
     * @dev Requires server signature; cannot stake while paused
     */
    function stake(OdySingleStakingTypes.StakeRequest calldata req, bytes calldata signature)
        external
        whenNotPaused
        nonReentrant
    {
        _requireCoreSet();
        OdySingleStakingTypes.Cycle memory c = cycles[req.cycleId];
        require(c.active, "ODS: cycle inactive");
        require(req.amount > 0, "ODS: amount zero");
        require(req.feeAmount >= 0, "ODS: fee bad");
        require(req.requestId != bytes32(0), "ODS: requestId zero");

        if (requireSignature) {
            _verifySignature(req, signature);
        }

        require(!usedRequestIds[req.requestId], "ODS: request used");
        usedRequestIds[req.requestId] = true;
        emit RequestUsed(req.requestId);

        // Move funds into vault
        odyToken.safeTransferFrom(msg.sender, stakingVault, req.amount);
        if (req.feeAmount > 0) {
            require(feeRecipient != address(0), "ODS: fee recipient not set");
            usdtToken.safeTransferFrom(msg.sender, feeRecipient, req.feeAmount);
        }

        // Create position
        nextPositionId += 1;
        uint256 pid = nextPositionId;
        positions[pid] = OdySingleStakingTypes.Position({
            id: pid,
            owner: msg.sender,
            cycleId: req.cycleId,
            principal: req.amount,
            claimed: 0,
            startTs: uint64(block.timestamp),
            vestingDays: c.vestingDays
        });

        emit Staked(req.requestId, msg.sender, pid, req.cycleId, req.amount, req.feeAmount, feeRecipient, c.vestingDays, block.timestamp);
    }

    /**
     * @notice Admin batch creates positions for specified owners; admin funds the vault
     * @dev Skips signature and USDT fee; all positions share one cycleId and startTs
     * @param owners Position owners
     * @param amounts Position amounts (aligned with owners)
     * @param cycleId Cycle ID, must be active
     * @param startTs Custom start timestamp (seconds) for vesting; must be nonzero
     */
    function adminBatchStake(
        address[] calldata owners,
        uint256[] calldata amounts,
        uint256 cycleId,
        uint64 startTs
    ) external onlyRole(ADMIN_ROLE) whenNotPaused nonReentrant {
        _requireCoreSet();
        require(owners.length > 0, "ODS: empty owners");
        require(owners.length == amounts.length, "ODS: length mismatch");
        require(cycleId != 0, "ODS: cycleId zero");
        require(startTs != 0, "ODS: startTs zero");

        OdySingleStakingTypes.Cycle memory c = cycles[cycleId];
        require(c.active, "ODS: cycle inactive");

        uint256 totalAmount;
        uint256 len = owners.length;
        for (uint256 i; i < len; i++) {
            address owner = owners[i];
            uint256 amount = amounts[i];
            require(owner != address(0), "ODS: owner zero");
            require(amount > 0, "ODS: amount zero");

            nextPositionId += 1;
            uint256 pid = nextPositionId;
            positions[pid] = OdySingleStakingTypes.Position({
                id: pid,
                owner: owner,
                cycleId: cycleId,
                principal: amount,
                claimed: 0,
                startTs: startTs,
                vestingDays: c.vestingDays
            });

            emit AdminBatchStaked(msg.sender, owner, pid, cycleId, amount, c.vestingDays, startTs);
            totalAmount += amount;
        }

        odyToken.safeTransferFrom(msg.sender, stakingVault, totalAmount);
    }

    /**
     * @notice Claim vested principal (batch)
     * @dev Still nonReentrant; claims allowed while paused
     */
    function claim(uint256[] calldata positionIds) external nonReentrant {
        _requireCoreSet();
        uint256 len = positionIds.length;
        for (uint256 i; i < len; i++) {
            uint256 pid = positionIds[i];
            OdySingleStakingTypes.Position storage p = positions[pid];
            _claimPosition(p, pid, msg.sender, 0, false);
        }
    }

    /**
     * @notice Claim part of vested principal for a single position.
     * @dev Claims allowed while paused; amount must be >0 and <= current claimable.
     */
    function claim(uint256 positionId, uint256 amount) external nonReentrant {
        _requireCoreSet();
        require(amount > 0, "ODS: amount zero");
        OdySingleStakingTypes.Position storage p = positions[positionId];
        _claimPosition(p, positionId, msg.sender, amount, true);
    }

    // -----------------------------
    // Views
    // -----------------------------

    function claimable(uint256 positionId) external view returns (uint256) {
        OdySingleStakingTypes.Position storage p = positions[positionId];
        return _claimable(p);
    }

    // -----------------------------
    // Admin configuration
    // -----------------------------

    function setCycle(uint256 cycleId, uint32 vestingDays, bool active) external onlyRole(ADMIN_ROLE) {
        require(cycleId != 0, "ODS: cycleId zero");
        cycles[cycleId] = OdySingleStakingTypes.Cycle({active: active, vestingDays: vestingDays});
        emit CycleUpdated(cycleId, vestingDays, active);
    }

    function setSigner(address signer, bool allowed) external onlyRole(ADMIN_ROLE) {
        require(signer != address(0), "ODS: signer zero");
        signers[signer] = allowed;
        emit SignerUpdated(signer, allowed);
    }

    function setRequireSignature(bool required) external onlyRole(ADMIN_ROLE) {
        requireSignature = required;
        emit SignatureRequiredSet(required);
    }

    function setOdyToken(address _ody) external onlyRole(ADMIN_ROLE) {
        require(_ody != address(0), "ODS: ody zero");
        odyToken = IERC20Metadata(_ody);
        emit OdyTokenUpdated(_ody);
    }

    function setStakingVault(address _vault) external onlyRole(ADMIN_ROLE) {
        require(_vault != address(0), "ODS: vault zero");
        stakingVault = _vault;
        emit StakingVaultUpdated(_vault);
    }

    function setUsdtToken(address _usdt) external onlyRole(ADMIN_ROLE) {
        require(_usdt != address(0), "ODS: usdt zero");
        usdtToken = IERC20Metadata(_usdt);
        usdtDecimals = IERC20Metadata(_usdt).decimals();
        emit UsdtTokenUpdated(_usdt);
    }

    function setFeeRecipient(address _feeRecipient) external onlyRole(ADMIN_ROLE) {
        require(_feeRecipient != address(0), "ODS: fee zero");
        feeRecipient = _feeRecipient;
        emit FeeRecipientUpdated(_feeRecipient);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // -----------------------------
    // Internal helpers
    // -----------------------------

    /// @dev Execute claim for a position; can skip when claimable=0 or revert if requested
    function _claimPosition(
        OdySingleStakingTypes.Position storage p,
        uint256 positionId,
        address owner,
        uint256 requestedAmount,
        bool revertIfZero
    ) internal {
        require(p.owner == owner, "ODS: not owner");

        uint256 claimableAmount = _claimable(p);
        if (claimableAmount == 0) {
            if (revertIfZero) {
                revert("ODS: nothing to claim");
            }
            return;
        }

        uint256 actualAmount = claimableAmount;
        if (requestedAmount > 0) {
            require(requestedAmount <= claimableAmount, "ODS: exceed claimable");
            actualAmount = requestedAmount;
        }

        p.claimed += actualAmount;

        ITokenVault(stakingVault).withdraw(owner, actualAmount);
        emit Claimed(positionId, owner, actualAmount, p.claimed);
    }

    function _requireCoreSet() internal view {
        require(address(odyToken) != address(0), "ODS: ody not set");
        require(stakingVault != address(0), "ODS: vault not set");
        require(address(usdtToken) != address(0), "ODS: usdt not set");
        require(feeRecipient != address(0), "ODS: fee recipient not set");
    }

    /// @dev Compute claimable principal; align to UTC+1 0/12 o'clock slots
    function _claimable(OdySingleStakingTypes.Position storage p) internal view returns (uint256) {
        if (p.owner == address(0)) {
            return 0;
        }
        if (p.vestingDays == 0) {
            uint256 remaining = p.principal - p.claimed;
            return remaining;
        }
        uint256 firstSlot = _firstRebaseSlot(uint256(p.startTs));
        if (block.timestamp < firstSlot) {
            return 0;
        }
        uint256 totalSlots = uint256(p.vestingDays) * 2;
        uint256 elapsedSlots = ((block.timestamp - firstSlot) / HALF_DAY) + 1;
        if (elapsedSlots > totalSlots) {
            elapsedSlots = totalSlots;
        }
        uint256 vested = (p.principal * elapsedSlots) / totalSlots;
        if (elapsedSlots == totalSlots && vested < p.principal) {
            vested = p.principal;
        }
        if (vested <= p.claimed) {
            return 0;
        }
        return vested - p.claimed;
    }

    /// @dev First release slot is the next UTC+1 0/12 o'clock after purchase
    function _firstRebaseSlot(uint256 startTs) internal pure returns (uint256) {
        uint256 localTs = startTs + UTC1_OFFSET;
        uint256 remainder = localTs % HALF_DAY;
        uint256 alignedLocal = remainder == 0 ? localTs : localTs + (HALF_DAY - remainder);
        return alignedLocal - UTC1_OFFSET;
    }

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

    function _verifySignature(OdySingleStakingTypes.StakeRequest calldata req, bytes calldata signature) internal view {
        require(signature.length == 65, "ODS: bad sig length");
        require(req.deadline >= block.timestamp, "ODS: expired");

        bytes32 structHash = keccak256(
            abi.encode(
                STAKE_TYPEHASH,
                msg.sender,
                req.cycleId,
                req.amount,
                req.feeAmount,
                req.deadline,
                req.requestId
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
        address signer = ECDSA.recover(digest, signature);
        require(signers[signer], "ODS: signer not allowed");
    }
}
