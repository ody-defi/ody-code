// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "./ReleaseDeps.sol";
import {ReleaseEvents} from "./ReleaseEvents.sol";

/**
 * @title OdyReleaseTurbine
 * @notice Reward release + turbine exit contract (upgradeable, transparent proxy)
 *         - Hold release: user pays USDT to repurchase ODY to a repurchase sink (exact-out, leftover USDT refunded) and burns gODY
 *         - Reward release: optional USDT split (20% buy ODY + 20% LP + 30/15/15 USDT to foundation/genesis/leaderboard)
 *         - Turbine exit: user pays USDT to buy ODY to wallet and creates a 12h countdown order; later withdraws ODY from RewardVault
 *         All entrypoints except claim require off-chain signatures.
 */
contract OdyReleaseTurbine is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ReleaseEvents
{
    using SafeERC20 for IERC20Metadata;

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Constants
    uint256 public constant BPS_100 = 10_000;
    uint256 public constant DEFAULT_UNLOCK_PERIOD = 12 hours;
    uint256 private constant REWARD_BUY_PORTION = 2_000; // 20%
    uint256 private constant REWARD_LP_USDT_PORTION = 2_000; // 20%
    uint256 private constant REWARD_FOUNDATION_PORTION = 3_000; // 30%
    uint256 private constant REWARD_GENESIS_PORTION = 1_500; // 15%
    uint256 private constant REWARD_LEADERBOARD_PORTION = 1_500; // 15%

    // EIP-712 domain and types
    string private constant EIP712_NAME = "OdyReleaseTurbine";
    string private constant EIP712_VERSION = "1";
    bytes32 private constant EIP712_DOMAIN_TYPE_HASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant RELEASE_TYPE_HASH =
        keccak256(
            "Release(address user,uint256 amount,uint256 maxClaimable,uint256 usdtAmount,uint256 repurchaseOdyAmount,uint256 cycleId,uint256 nonce,uint256 deadline,bytes32 requestId)"
        );
    bytes32 private constant REWARD_RELEASE_TYPE_HASH =
        keccak256(
            "RewardRelease(address user,uint256 amount,uint256 maxClaimable,uint256 usdtAmount,uint256 cycleId,uint256 nonce,uint256 deadline,bytes32 requestId)"
        );
    bytes32 private constant EXIT_TYPE_HASH =
        keccak256(
            "Exit(address user,uint256 amount,uint256 maxClaimable,uint256 usdtAmount,uint256 minOut,uint256 nonce,uint256 deadline,bytes32 requestId)"
        );

    // Release cycle: burn ratio/days per tier and active flag
    struct ReleaseCycle {
        uint32 burnBps; // USDT cost ratio (based on profit value), in bps
        uint32 releaseDays; // Release days (for events/UI)
        bool active;
    }

    // Turbine order: after buy1, waits unlockPeriod before claim
    struct TurbineOrder {
        uint256 id;
        address user;
        uint256 amount; // ODY amount (also vault withdrawal amount)
        uint64 unlockAt;
        bool claimed;
    }

    // Input: hold release (with signature)
    struct ReleaseHoldRequest {
        uint256 amount; // gODY burn amount (for event)
        uint256 maxClaimable; // cumulative cap for user hold profit (anti-over-issue)
        uint256 usdtAmount; // Max USDT user allows (contract auto-quotes needed amount with slippage buffer)
        uint256 repurchaseOdyAmount; // ODY amount to repurchase to sink
        uint256 cycleId;
        uint256 nonce; // per-user nonce for hold profit release
        uint256 deadline;
        bytes32 requestId;
    }

    // Input: reward release (with signature)
    struct RewardReleaseRequest {
        uint256 amount; // For event/reference
        uint256 maxClaimable; // cumulative cap for user reward profit (anti-over-issue)
        uint256 usdtAmount; // USDT user pays
        uint256 cycleId;
        uint256 nonce; // per-user nonce for reward profit release
        uint256 deadline;
        bytes32 requestId;
    }

    struct RewardVars {
        uint256 usdtBuy;
        uint256 lpUsdtPortion;
        uint256 foundationUsdt;
        uint256 genesisUsdt;
        uint256 leaderboardUsdt;
        uint256 odyBought;
        uint256 lpOdyUsed;
        uint256 lpUsdtUsed;
        uint256 usdtRefund;
    }

    // Input: turbine exit (with signature)
    struct ExitRequest {
        uint256 amount; // Target ODY amount user wants to exit
        uint256 usdtAmount; // USDT user pays
        uint256 minOut; // Minimum ODY buyout, must be >= amount
        uint256 maxClaimable; // cumulative cap to avoid over-withdraw
        uint256 nonce; // per-user turbine exit nonce
        uint256 deadline;
        bytes32 requestId;
    }

    // Key addresses
    IERC20Metadata public odyToken;
    IERC20Metadata public usdtToken;
    address public router;
    address public rewardVault; // TokenVault; needs MANAGER_ROLE granted

    // Config
    address[] public releasePath; // USDT -> ODY
    address[] public exitPath; // USDT -> ODY
    uint256 public unlockPeriod; // Turbine countdown (default 12h)
    bool public requireSignature; // Whether non-claim calls need signature
    uint256 public nextOrderId;
    mapping(uint256 => ReleaseCycle) public releaseCycles; // cycleId => config
    mapping(uint256 => TurbineOrder) public orders; // orderId => order
    mapping(address => bool) public signers;
    mapping(bytes32 => bool) public usedRequestIds;

    // New fields (appended to preserve storage layout)
    address public releaseRepurchaseSink; // ODY repurchase sink for hold release
    address public lpReceiver;
    address public foundation;
    address public genesisNode;
    address public leaderboardPool;
    IGodyToken public godyToken;
    uint256 public holdRepurchaseSlippageBps; // extra bps on getAmountsIn for repurchase (e.g., 200 = 2%)
    uint256 public holdRepurchaseToleranceBps; // tolerance on user-provided usdtAmount (e.g., 1000 = +10%)

    // New fields for maxClaimable + nonce tracking (per user, per profit type)
    mapping(address => uint256) public holdProfitClaimed; // 已领取持仓收益累计（18 精度）
    mapping(address => uint256) public rewardProfitClaimed; // 已领取奖励收益累计（18 精度）
    mapping(address => uint256) public holdProfitNonces; // 按用户维度的 hold 领取 nonce
    mapping(address => uint256) public rewardProfitNonces; // 按用户维度的 reward 领取 nonce
    mapping(address => uint256) public turbineReleasedClaimed; // 已领取涡轮退出累计（18 精度）
    mapping(address => uint256) public turbineReleasedNonces; // 按用户维度的涡轮退出 nonce

    // Turbine exit quote controls (MUST be appended for upgrade safety)
    uint256 public exitSlippageBps; // add-on bps on getAmountsIn (e.g., 100 = 1%)
    uint256 public exitToleranceBps; // tolerance vs user cap (e.g., 500 = +5%)

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address _ody,
        address _usdt,
        address _router,
        address _rewardVault
    ) external initializer {
        require(_ody != address(0), "ORT: ody zero");
        require(_usdt != address(0), "ORT: usdt zero");
        require(_router != address(0), "ORT: router zero");
        require(_rewardVault != address(0), "ORT: vault zero");

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        odyToken = IERC20Metadata(_ody);
        usdtToken = IERC20Metadata(_usdt);
        router = _router;
        rewardVault = _rewardVault;
        unlockPeriod = DEFAULT_UNLOCK_PERIOD;
        requireSignature = true;
        holdRepurchaseSlippageBps = 200; // 2% buffer on exact-out repurchase
        holdRepurchaseToleranceBps = 1000; // 10% tolerance on user-provided usdtAmount
        exitSlippageBps = 100; // 1% buffer on exact-out turbine exit
        exitToleranceBps = 500; // 5% tolerance on user-provided cap
        nextOrderId = 0;

        // Default paths: USDT -> ODY
        releasePath.push(_usdt);
        releasePath.push(_ody);
        exitPath.push(_usdt);
        exitPath.push(_ody);

        // Default burn ratios (bps): 0d 20%, 10d 15%, 20d 10%, 30d 5%, 60d 0%
        _setCycleInternal(0, 2000, 0, true);
        _setCycleInternal(10, 1500, 10, true);
        _setCycleInternal(20, 1000, 20, true);
        _setCycleInternal(30, 500, 30, true);
        _setCycleInternal(60, 0, 60, true);

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    // ========================
    //        User actions
    // ========================

    /// @notice Hold release: optional repurchase ODY to sink, burn user's gODY, refund leftover USDT
    function releaseHold(ReleaseHoldRequest calldata req, bytes calldata signature)
        external
        whenNotPaused
        nonReentrant
    {
        _requireCoreSet();
        ReleaseCycle memory c = releaseCycles[req.cycleId];
        require(c.active, "ORT: cycle inactive");
        require(req.amount > 0, "ORT: amount zero");
        if (req.repurchaseOdyAmount == 0) {
            require(req.usdtAmount == 0, "ORT: usdt unused");
        } else {
            require(req.usdtAmount > 0, "ORT: usdt zero");
        }
        require(req.nonce == holdProfitNonces[msg.sender], "ORT: bad nonce");
        require(req.requestId != bytes32(0), "ORT: requestId zero");
        require(address(godyToken) != address(0), "ORT: gODY not set");

        if (requireSignature) {
            _verifyReleaseHoldSignature(req, signature);
        }

        require(!usedRequestIds[req.requestId], "ORT: request used");
        usedRequestIds[req.requestId] = true;
        emit RequestUsed(req.requestId);

        uint256 usdtIn = 0;
        uint256 usdtSpent = 0;
        uint256 refund = 0;

        // Optional repurchase ODY to repurchase sink
        if (req.repurchaseOdyAmount > 0) {
            require(releaseRepurchaseSink != address(0), "ORT: repurchase sink not set");
            uint256 maxIn = _quoteRepurchaseMaxIn(req.repurchaseOdyAmount);
            // 容忍一定比例的超出，避免行情波动导致拒单
            uint256 allowedMaxIn = (req.usdtAmount * (BPS_100 + holdRepurchaseToleranceBps)) / BPS_100;
            require(maxIn <= allowedMaxIn, "ORT: max USDT too low");

            usdtIn = maxIn;
            usdtToken.safeTransferFrom(msg.sender, address(this), usdtIn);
            _forceApprove(usdtToken, router, usdtIn);
            uint256[] memory amounts = IPancakeRouterV2(router).swapTokensForExactTokens(
                req.repurchaseOdyAmount,
                usdtIn,
                releasePath,
                releaseRepurchaseSink,
                block.timestamp
            );
            usdtSpent = amounts[0];
            refund = usdtIn > usdtSpent ? usdtIn - usdtSpent : 0;
            if (refund > 0) {
                usdtToken.safeTransfer(msg.sender, refund);
            }
        }

        // Burn gODY from user
        godyToken.burnFromOperation(msg.sender, req.amount);

        // 更新累计与 nonce，确保 maxClaimable 校验
        uint256 claimed = holdProfitClaimed[msg.sender];
        require(claimed + req.amount <= req.maxClaimable, "ORT: exceed maxClaimable");
        holdProfitClaimed[msg.sender] = claimed + req.amount;
        holdProfitNonces[msg.sender] = req.nonce + 1;

        emit ReleaseHoldExecuted(
            msg.sender,
            req.amount,
            usdtIn,
            usdtSpent,
            req.repurchaseOdyAmount,
            req.cycleId,
            c.burnBps,
            c.releaseDays,
            req.requestId,
            refund,
            req.maxClaimable,
            req.nonce
        );
    }

    /// @notice Reward release: optionally split USDT into buy+LP+foundations, or just emit event when usdtAmount=0
    function releaseReward(RewardReleaseRequest calldata req, bytes calldata signature)
        external
        whenNotPaused
        nonReentrant
    {
        _requireCoreSet();
        require(releaseCycles[req.cycleId].active, "ORT: cycle inactive");
        require(req.amount > 0, "ORT: amount zero");
        require(req.nonce == rewardProfitNonces[msg.sender], "ORT: bad nonce");
        require(req.requestId != bytes32(0), "ORT: requestId zero");

        if (requireSignature) {
            _verifyRewardReleaseSignature(req, signature);
        }

        require(!usedRequestIds[req.requestId], "ORT: request used");
        usedRequestIds[req.requestId] = true;
        emit RequestUsed(req.requestId);

        uint256 usdtAmount = req.usdtAmount;

        // If no USDT, still consume reward amount + nonce (business: some cycles don't require USDT)
        if (usdtAmount == 0) {
            uint256 claimedReward0 = rewardProfitClaimed[msg.sender];
            require(claimedReward0 + req.amount <= req.maxClaimable, "ORT: exceed maxClaimable");
            rewardProfitClaimed[msg.sender] = claimedReward0 + req.amount;
            rewardProfitNonces[msg.sender] = req.nonce + 1;

            emit ReleaseRewardExecuted(
                msg.sender,
                req.amount,
                0,
                0,
                0,
                0,
                0,
                0,
                0,
                req.requestId,
                0,
                req.maxClaimable,
                req.nonce
            );
            return;
        }

        require(lpReceiver != address(0), "ORT: lpReceiver not set");
        require(foundation != address(0), "ORT: foundation not set");
        require(genesisNode != address(0), "ORT: genesis not set");
        require(leaderboardPool != address(0), "ORT: leaderboard not set");

        // Effects: consume claim amount + nonce before external interactions
        uint256 claimedReward = rewardProfitClaimed[msg.sender];
        require(claimedReward + req.amount <= req.maxClaimable, "ORT: exceed maxClaimable");
        rewardProfitClaimed[msg.sender] = claimedReward + req.amount;
        rewardProfitNonces[msg.sender] = req.nonce + 1;

        usdtToken.safeTransferFrom(msg.sender, address(this), usdtAmount);

        RewardVars memory v;
        {
            uint256 _usdtAmount = usdtAmount;
            v.usdtBuy = (_usdtAmount * REWARD_BUY_PORTION) / BPS_100;
            v.lpUsdtPortion = (_usdtAmount * REWARD_LP_USDT_PORTION) / BPS_100;
            v.foundationUsdt = (_usdtAmount * REWARD_FOUNDATION_PORTION) / BPS_100;
            v.genesisUsdt = (_usdtAmount * REWARD_GENESIS_PORTION) / BPS_100;
            v.leaderboardUsdt = (_usdtAmount * REWARD_LEADERBOARD_PORTION) / BPS_100;
            uint256 allocated = v.usdtBuy + v.lpUsdtPortion + v.foundationUsdt + v.genesisUsdt + v.leaderboardUsdt;
            if (allocated < _usdtAmount) {
                v.foundationUsdt += _usdtAmount - allocated;
            }
        }

        if (v.usdtBuy > 0) {
            uint256 odyBefore = odyToken.balanceOf(address(this));
            _forceApprove(usdtToken, router, v.usdtBuy);
            _swapSupportingFee(v.usdtBuy, 0, releasePath, address(this));
            uint256 odyAfter = odyToken.balanceOf(address(this));
            v.odyBought = odyAfter > odyBefore ? odyAfter - odyBefore : 0;
        }

        if (v.lpUsdtPortion > 0 && v.odyBought > 0) {
            _forceApprove(odyToken, router, v.odyBought);
            _forceApprove(usdtToken, router, v.lpUsdtPortion);
            (v.lpOdyUsed, v.lpUsdtUsed, ) = IPancakeRouterV2(router).addLiquidity(
                address(odyToken),
                address(usdtToken),
                v.odyBought,
                v.lpUsdtPortion,
                0,
                0,
                lpReceiver,
                block.timestamp
            );

            // Send leftover ODY from LP addition to lpReceiver to avoid being stuck
            if (v.odyBought > v.lpOdyUsed) {
                odyToken.safeTransfer(lpReceiver, v.odyBought - v.lpOdyUsed);
            }
        }

        // USDT transfers
        if (v.foundationUsdt > 0) {
            usdtToken.safeTransfer(foundation, v.foundationUsdt);
        }
        if (v.genesisUsdt > 0) {
            usdtToken.safeTransfer(genesisNode, v.genesisUsdt);
        }
        if (v.leaderboardUsdt > 0) {
            usdtToken.safeTransfer(leaderboardPool, v.leaderboardUsdt);
        }

        // Refund any remaining USDT (e.g., LP leftover)
        uint256 usdtUsed = v.usdtBuy + v.lpUsdtUsed + v.foundationUsdt + v.genesisUsdt + v.leaderboardUsdt;
        v.usdtRefund = usdtUsed < usdtAmount ? usdtAmount - usdtUsed : 0;
        if (v.usdtRefund > 0) {
            usdtToken.safeTransfer(msg.sender, v.usdtRefund);
        }

        emit ReleaseRewardExecuted(
            msg.sender,
            req.amount,
            usdtAmount,
            v.odyBought,
            v.lpOdyUsed,
            v.lpUsdtUsed,
            v.foundationUsdt,
            v.genesisUsdt,
            v.leaderboardUsdt,
            req.requestId,
            v.usdtRefund,
            req.maxClaimable,
            req.nonce
        );
    }

    /// @notice Turbine exit: pay USDT to buy ODY to wallet and create a countdown order
    function turbineExit(ExitRequest calldata req, bytes calldata signature)
        external
        whenNotPaused
        nonReentrant
    {
        _requireCoreSet();
        require(req.amount > 0, "ORT: amount zero");
        require(req.usdtAmount > 0, "ORT: usdt zero");
        require(req.minOut == req.amount, "ORT: minOut != amount");
        require(req.nonce == turbineReleasedNonces[msg.sender], "ORT: bad nonce");
        require(req.requestId != bytes32(0), "ORT: requestId zero");

        if (requireSignature) {
            _verifyExitSignature(req, signature);
        }

        require(!usedRequestIds[req.requestId], "ORT: request used");
        usedRequestIds[req.requestId] = true;
        emit RequestUsed(req.requestId);

        // Quote required maxIn on-chain and compare to user cap (with tolerance).
        uint256 maxIn = _quoteExitMaxIn(req.amount);
        uint256 allowedMaxIn = (req.usdtAmount * (BPS_100 + exitToleranceBps)) / BPS_100;
        require(maxIn <= allowedMaxIn, "ORT: max USDT too low");

        // 1) User pays USDT (bounded by quote)
        usdtToken.safeTransferFrom(msg.sender, address(this), maxIn);
        // 2) Buy ODY (first leg)：use exact-out to buy `req.amount` precisely; refund unused USDT.
        //    Buy to this contract first, then transfer exactly `req.amount` to user to avoid over-delivery.
        uint256 odyBefore = odyToken.balanceOf(address(this));
        _forceApprove(usdtToken, router, maxIn);
        uint256[] memory amounts = IPancakeRouterV2(router).swapTokensForExactTokens(
            req.amount,
            maxIn,
            exitPath,
            address(this),
            block.timestamp
        );
        uint256 usdtSpent = amounts[0];

        uint256 odyAfter = odyToken.balanceOf(address(this));
        uint256 received = odyAfter > odyBefore ? odyAfter - odyBefore : 0;
        require(received >= req.amount, "ORT: bought < amount");
        odyToken.safeTransfer(msg.sender, req.amount);
        uint256 odyOut = req.amount;

        // Refund leftover USDT（exact-out 场景 amounts[0] 为实际消耗）
        uint256 usdtRefund = usdtSpent < maxIn ? maxIn - usdtSpent : 0;
        if (usdtRefund > 0) {
            usdtToken.safeTransfer(msg.sender, usdtRefund);
        }

        // If any ODY residue exists (should not happen for standard tokens), forward it to RewardVault to avoid trapping funds.
        uint256 residue = received > req.amount ? received - req.amount : 0;
        if (residue > 0) {
            odyToken.safeTransfer(rewardVault, residue);
        }

        uint256 claimed = turbineReleasedClaimed[msg.sender];
        require(claimed + req.amount <= req.maxClaimable, "ORT: exceed maxClaimable");
        turbineReleasedClaimed[msg.sender] = claimed + req.amount;
        turbineReleasedNonces[msg.sender] = req.nonce + 1;

        // 3) Record turbine order; after unlockPeriod user withdraws same ODY from rewardVault (second leg)
        nextOrderId += 1;
        uint256 oid = nextOrderId;
        orders[oid] = TurbineOrder({
            id: oid,
            user: msg.sender,
            amount: req.amount,
            unlockAt: uint64(block.timestamp + unlockPeriod),
            claimed: false
        });

        emit TurbineExitStarted(
            oid,
            msg.sender,
            req.amount,
            usdtSpent,
            odyOut,
            orders[oid].unlockAt,
            req.requestId,
            req.maxClaimable,
            req.nonce
        );
    }

    /// @notice Claim ODY after countdown (withdraw from RewardVault)
    /// @dev Claim allowed even when paused
    function claim(uint256[] calldata orderIds) external nonReentrant {
        _requireCoreSet();
        uint256 len = orderIds.length;
        for (uint256 i; i < len; i++) {
            uint256 oid = orderIds[i];
            TurbineOrder storage o = orders[oid];
            require(o.user == msg.sender, "ORT: not owner");
            require(!o.claimed, "ORT: claimed");
            require(block.timestamp >= o.unlockAt, "ORT: not unlocked");

            o.claimed = true;
            IRewardVault(rewardVault).withdraw(msg.sender, o.amount);
            emit TurbineClaimed(oid, msg.sender, o.amount);
        }
    }

    // ========================
    //         Views
    // ========================

    function getReleasePath() external view returns (address[] memory) {
        return releasePath;
    }

    function getExitPath() external view returns (address[] memory) {
        return exitPath;
    }

    // ========================
    //       Admin config
    // ========================

    function setCycle(uint256 cycleId, uint32 burnBps, uint32 releaseDays, bool active)
        external
        onlyRole(ADMIN_ROLE)
    {
        require(cycleId <= type(uint256).max, "ORT: bad id");
        require(burnBps <= BPS_100, "ORT: burn too high");
        releaseCycles[cycleId] = ReleaseCycle({burnBps: burnBps, releaseDays: releaseDays, active: active});
        emit CycleUpdated(cycleId, burnBps, releaseDays, active);
    }

    function setRewardVault(address vault) external onlyRole(ADMIN_ROLE) {
        require(vault != address(0), "ORT: vault zero");
        rewardVault = vault;
        emit RewardVaultUpdated(vault);
    }

    function setRouter(address _router) external onlyRole(ADMIN_ROLE) {
        require(_router != address(0), "ORT: router zero");
        router = _router;
        emit RouterUpdated(_router);
    }

    function setTokens(address _ody, address _usdt) external onlyRole(ADMIN_ROLE) {
        require(_ody != address(0), "ORT: ody zero");
        require(_usdt != address(0), "ORT: usdt zero");
        odyToken = IERC20Metadata(_ody);
        usdtToken = IERC20Metadata(_usdt);
        emit TokensUpdated(_ody, _usdt);
    }

    function setReleasePath(address[] calldata path) external onlyRole(ADMIN_ROLE) {
        require(path.length >= 2, "ORT: path short");
        require(path[0] == address(usdtToken), "ORT: path must start USDT");
        require(path[path.length - 1] == address(odyToken), "ORT: path must end ODY");
        releasePath = path;
        emit PathsUpdated(releasePath, exitPath);
    }

    function setExitPath(address[] calldata path) external onlyRole(ADMIN_ROLE) {
        require(path.length >= 2, "ORT: path short");
        require(path[0] == address(usdtToken), "ORT: path must start USDT");
        require(path[path.length - 1] == address(odyToken), "ORT: path must end ODY");
        exitPath = path;
        emit PathsUpdated(releasePath, exitPath);
    }

    function reSetDistributor(
        address _lpReceiver,
        address _foundation,
        address _genesis,
        address _leaderboard,
        address _repurchaseSink
    ) external onlyRole(ADMIN_ROLE) {
        require(_lpReceiver != address(0), "ORT: lp zero");
        require(_foundation != address(0), "ORT: foundation zero");
        require(_genesis != address(0), "ORT: genesis zero");
        require(_leaderboard != address(0), "ORT: leaderboard zero");
        require(_repurchaseSink != address(0), "ORT: repurchase sink zero");
        lpReceiver = _lpReceiver;
        foundation = _foundation;
        genesisNode = _genesis;
        leaderboardPool = _leaderboard;
        releaseRepurchaseSink = _repurchaseSink;
        emit DistributorReset(_lpReceiver, _foundation, _genesis, _leaderboard, _repurchaseSink);
    }

    function setGodyToken(address _gody) external onlyRole(ADMIN_ROLE) {
        require(_gody != address(0), "ORT: gODY zero");
        godyToken = IGodyToken(_gody);
        emit GodyTokenUpdated(_gody);
    }

    function setUnlockPeriod(uint256 period) external onlyRole(ADMIN_ROLE) {
        require(period > 0, "ORT: period zero");
        unlockPeriod = period;
        emit UnlockPeriodUpdated(period);
    }

    function setSigner(address signer, bool allowed) external onlyRole(ADMIN_ROLE) {
        require(signer != address(0), "ORT: signer zero");
        signers[signer] = allowed;
        emit SignerUpdated(signer, allowed);
    }

    function setRequireSignature(bool required) external onlyRole(ADMIN_ROLE) {
        requireSignature = required;
        emit RequireSignatureSet(required);
    }

    function setHoldRepurchaseSlippageBps(uint256 bps) external onlyRole(ADMIN_ROLE) {
        require(bps <= 2_000, "ORT: bps too high");
        holdRepurchaseSlippageBps = bps;
        emit HoldRepurchaseSlippageUpdated(bps);
    }

    function setHoldRepurchaseToleranceBps(uint256 bps) external onlyRole(ADMIN_ROLE) {
        require(bps <= 2_000, "ORT: bps too high");
        holdRepurchaseToleranceBps = bps;
        emit HoldRepurchaseToleranceUpdated(bps);
    }

    function setExitSlippageBps(uint256 bps) external onlyRole(ADMIN_ROLE) {
        require(bps <= 2_000, "ORT: bps too high");
        exitSlippageBps = bps;
        emit ExitSlippageUpdated(bps);
    }

    function setExitToleranceBps(uint256 bps) external onlyRole(ADMIN_ROLE) {
        require(bps <= 2_000, "ORT: bps too high");
        exitToleranceBps = bps;
        emit ExitToleranceUpdated(bps);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // ========================
    //       Internal helpers
    // ========================

    function _requireCoreSet() internal view {
        require(address(odyToken) != address(0), "ORT: ody not set");
        require(address(usdtToken) != address(0), "ORT: usdt not set");
        require(router != address(0), "ORT: router not set");
        require(rewardVault != address(0), "ORT: vault not set");
        require(releasePath.length >= 2, "ORT: release path unset");
        require(exitPath.length >= 2, "ORT: exit path unset");
        require(releasePath[0] == address(usdtToken), "ORT: release path head");
        require(releasePath[releasePath.length - 1] == address(odyToken), "ORT: release path tail");
        require(exitPath[0] == address(usdtToken), "ORT: exit path head");
        require(exitPath[exitPath.length - 1] == address(odyToken), "ORT: exit path tail");
    }

    function _setCycleInternal(uint256 cycleId, uint32 burnBps, uint32 releaseDays, bool active) internal {
        releaseCycles[cycleId] = ReleaseCycle({burnBps: burnBps, releaseDays: releaseDays, active: active});
        emit CycleUpdated(cycleId, burnBps, releaseDays, active);
    }

    function _forceApprove(IERC20Metadata token, address spender, uint256 amount) internal {
        // Reset then set to support USDT-like tokens
        token.forceApprove(spender, 0);
        token.forceApprove(spender, amount);
    }

    function _swapSupportingFee(
        uint256 amountIn,
        uint256 minOut,
        address[] memory path,
        address to
    ) internal {
        IPancakeRouterV2(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amountIn,
            minOut,
            path,
            to,
            block.timestamp
        );
    }

    function _domainSeparator() internal view returns (bytes32) {
        return
            keccak256(
                abi.encode(
                    EIP712_DOMAIN_TYPE_HASH,
                    keccak256(bytes(EIP712_NAME)),
                    keccak256(bytes(EIP712_VERSION)),
                    block.chainid,
                    address(this)
                )
            );
    }

    function _quoteRepurchaseMaxIn(uint256 odyOut) internal view returns (uint256) {
        require(odyOut > 0, "ORT: ody zero");
        uint256[] memory amounts = IPancakeRouterV2(router).getAmountsIn(odyOut, releasePath);
        uint256 baseIn = amounts[0];
        uint256 maxIn = (baseIn * (BPS_100 + holdRepurchaseSlippageBps)) / BPS_100;
        require(maxIn > 0, "ORT: quote zero");
        return maxIn;
    }

    function _quoteExitMaxIn(uint256 odyOut) internal view returns (uint256) {
        require(odyOut > 0, "ORT: ody zero");
        uint256[] memory amounts = IPancakeRouterV2(router).getAmountsIn(odyOut, exitPath);
        uint256 baseIn = amounts[0];
        uint256 maxIn = (baseIn * (BPS_100 + exitSlippageBps)) / BPS_100;
        require(maxIn > 0, "ORT: quote zero");
        return maxIn;
    }

    function _verifyReleaseHoldSignature(ReleaseHoldRequest calldata req, bytes calldata signature) internal view {
        require(signature.length == 65, "ORT: bad sig");
        require(req.deadline >= block.timestamp, "ORT: expired");
        bytes32 structHash = keccak256(
            abi.encode(
                RELEASE_TYPE_HASH,
                msg.sender,
                req.amount,
                req.maxClaimable,
                req.usdtAmount,
                req.repurchaseOdyAmount,
                req.cycleId,
                req.nonce,
                req.deadline,
                req.requestId
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
        address signer = ECDSA.recover(digest, signature);
        require(signers[signer], "ORT: signer not allowed");
    }

    function _verifyRewardReleaseSignature(RewardReleaseRequest calldata req, bytes calldata signature) internal view {
        require(signature.length == 65, "ORT: bad sig");
        require(req.deadline >= block.timestamp, "ORT: expired");
        bytes32 structHash = keccak256(
            abi.encode(
                REWARD_RELEASE_TYPE_HASH,
                msg.sender,
                req.amount,
                req.maxClaimable,
                req.usdtAmount,
                req.cycleId,
                req.nonce,
                req.deadline,
                req.requestId
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
        address signer = ECDSA.recover(digest, signature);
        require(signers[signer], "ORT: signer not allowed");
    }

    function _verifyExitSignature(ExitRequest calldata req, bytes calldata signature) internal view {
        require(signature.length == 65, "ORT: bad sig");
        require(req.deadline >= block.timestamp, "ORT: expired");
        require(req.minOut > 0, "ORT: minOut zero");
        bytes32 structHash = keccak256(
            abi.encode(
                EXIT_TYPE_HASH,
                msg.sender,
                req.amount,
                req.maxClaimable,
                req.usdtAmount,
                req.minOut,
                req.nonce,
                req.deadline,
                req.requestId
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
        address signer = ECDSA.recover(digest, signature);
        require(signers[signer], "ORT: signer not allowed");
    }
}
