// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {MaintenanceFeeVaultDeps} from "./MaintenanceFeeVaultDeps.sol";
import {MaintenanceFeeVaultEvents} from "./MaintenanceFeeVaultEvents.sol";

/**
 * @title MaintenanceFeeVault - Bond/Staking maintenance fee payment and split
 * @notice Maintenance-fee escrow and distributor (upgradeable via TransparentUpgradeableProxy).
 * Features:
 *  1) Users pay USDT maintenance fee (requires off-chain signature); emits event for backend renewal.
 *  2) Admin/bot splitting: fixed ratios to buy ODY, add LP, transfer to foundation/node/leaderboard, remainder stays.
 */
contract MaintenanceFeeVault is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    MaintenanceFeeVaultEvents
{
    using SafeERC20 for IERC20Metadata;

    // -----------------------------
    // Roles
    // -----------------------------
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // -----------------------------
    // Core addresses
    // -----------------------------
    IERC20Metadata public usdt;
    IERC20Metadata public ody;
    MaintenanceFeeVaultDeps.IPancakeRouterV2 public router;
    address public lpReceiver;
    address public foundation;
    address public nodeAddr;
    address public leaderboard;

    // Buy path (default [USDT, ODY])
    address[] public buyPath;

    // -----------------------------
    // Signatures & anti-replay
    // -----------------------------
    mapping(address => bool) public signers; // Allowed off-chain signers
    mapping(bytes32 => bool) public usedRequestIds; // Used request IDs

    // -----------------------------
    // Split ratios (BPS_100 = 10000)
    // -----------------------------
    uint256 public lpBuyPortion; // USDT portion to buy ODY (default 25%)
    uint256 public lpUsdtPortion; // USDT portion to add LP directly (default 25%)
    uint256 public foundationPortion; // Foundation portion (default 30%)
    uint256 public nodePortion; // Node portion (default 10%)
    uint256 public leaderboardPortion; // Leaderboard pool portion (default 10%)

    uint256 public constant BPS_100 = 10_000;

    // -----------------------------
    // EIP-712 constants
    // -----------------------------
    string private constant EIP712_NAME = "MaintenanceFeeVault";
    string private constant EIP712_VERSION = "1";
    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant FEEPAY_TYPEHASH =
        keccak256("FeePay(address payer,uint256 amount,uint256 deadline,bytes32 requestId,uint8 feeType)");

    // -----------------------------
    // Structs
    // -----------------------------
    struct FeePay {
        address payer; // Payer (must equal msg.sender)
        uint256 amount; // USDT paid
        uint256 deadline; // Payment deadline
        bytes32 requestId; // Unique request ID (anti-replay)
        uint8 feeType; // Fee type: 1=bond, 2=staking (reserved)
    }

    struct Preview {
        uint8 feeType; // Requested fee type: 1=bond, 2=staking (UI only)
        uint256 usdtBalance; // Current USDT balance
        uint256 usdtForBuy; // Planned USDT to buy ODY
        uint256 usdtForLp; // Planned USDT for LP
        uint256 foundationUsdt; // Planned foundation share
        uint256 nodeUsdt; // Planned node share
        uint256 leaderboardUsdt; // Planned leaderboard share
        uint256 estOdyBought; // Estimated ODY bought (ignoring fees)
        uint256 estLpOdy; // Estimated ODY added to LP
        uint256 estLpUsdt; // Estimated USDT added to LP
    }

    // -----------------------------
    // Initialization
    // -----------------------------
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize contract
     * @param _router PancakeV2 Router
     * @param _usdt   USDT address
     * @param _ody    ODY token address
     * @param _lpReceiver LP receiver
     * @param _foundation Foundation address
     * @param _node Node address
     * @param _leaderboard Leaderboard pool address
     * @param _initSigner Initial signer (optional, 0 to skip)
     */
    function initialize(
        address _router,
        address _usdt,
        address _ody,
        address _lpReceiver,
        address _foundation,
        address _node,
        address _leaderboard,
        address _initSigner
    ) external initializer {
        require(_router != address(0), "MFV: router zero");
        require(_usdt != address(0), "MFV: usdt zero");
        require(_ody != address(0), "MFV: ody zero");
        require(_lpReceiver != address(0), "MFV: lp zero");
        require(_foundation != address(0), "MFV: foundation zero");
        require(_node != address(0), "MFV: node zero");
        require(_leaderboard != address(0), "MFV: leaderboard zero");

        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        router = MaintenanceFeeVaultDeps.IPancakeRouterV2(_router);
        usdt = IERC20Metadata(_usdt);
        ody = IERC20Metadata(_ody);
        lpReceiver = _lpReceiver;
        foundation = _foundation;
        nodeAddr = _node;
        leaderboard = _leaderboard;

        buyPath.push(_usdt);
        buyPath.push(_ody);

        // Default: 25% buy, 25% add LP, 30% foundation, 10% node, 10% leaderboard
        lpBuyPortion = 2_500;
        lpUsdtPortion = 2_500;
        foundationPortion = 3_000;
        nodePortion = 1_000;
        leaderboardPortion = 1_000;

        // Roles: deployer is default admin/business admin/operator
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);

        if (_initSigner != address(0)) {
            signers[_initSigner] = true;
            emit SignerUpdated(_initSigner, true);
        }
    }

    // -----------------------------
    // Core functions
    // -----------------------------

    /**
     * @notice Pay maintenance fee (requires off-chain signature)
     * @param req FeePay params (payer/amount/deadline/requestId)
     * @param signature Off-chain signature
     */
    function payFee(FeePay calldata req, bytes calldata signature) external whenNotPaused {
        _requireCoreSet();
        require(req.payer != address(0), "MFV: payer zero");
        require(msg.sender == req.payer, "MFV: sender mismatch");
        require(req.amount > 0, "MFV: amount zero");
        require(req.deadline >= block.timestamp, "MFV: expired");
        require(!usedRequestIds[req.requestId], "MFV: request used");
        require(req.feeType == 1 || req.feeType == 2, "MFV: bad feeType");

        address signer = _recoverSigner(req, signature);
        require(signers[signer], "MFV: signer not allowed");

        usedRequestIds[req.requestId] = true;
        usdt.safeTransferFrom(req.payer, address(this), req.amount);

        emit FeePaid(req.requestId, req.payer, req.amount, req.deadline, req.feeType);
    }

    /**
     * @notice Distribute: buy ODY + add LP + split to recipients
     * @param minOdyOut  最小可接受 ODY 买入数量（用于 swapExactTokensForTokensSupportingFeeOnTransferTokens 的 amountOutMin）
     * @param minLpOdy   addLiquidity 最小可接受 ODY 用量（amountAMin）
     * @param minLpUsdt  addLiquidity 最小可接受 USDT 用量（amountBMin）
     * @param deadline   Pancake router deadline
     */
    function distribute(
        uint256 minOdyOut,
        uint256 minLpOdy,
        uint256 minLpUsdt,
        uint256 deadline
    )
        external
        onlyRole(OPERATOR_ROLE)
        whenNotPaused
        nonReentrant
    {
        _requireCoreSet();
        require(deadline >= block.timestamp, "MFV: deadline past");

        uint256 balance = usdt.balanceOf(address(this));
        require(balance > 0, "MFV: empty");

        // Calculate portions
        uint256 usdtForBuy = (balance * lpBuyPortion) / BPS_100;
        uint256 usdtForLp = (balance * lpUsdtPortion) / BPS_100;
        uint256 foundationUsdt = (balance * foundationPortion) / BPS_100;
        uint256 nodeUsdt = (balance * nodePortion) / BPS_100;
        uint256 leaderboardUsdt = (balance * leaderboardPortion) / BPS_100;
        // Unused dust stays in contract

        // 1) Sell USDT to buy ODY（滑点由调用方 minOdyOut 控制）
        uint256 odyBefore = ody.balanceOf(address(this));
        if (usdtForBuy > 0) {
            SafeERC20.forceApprove(usdt, address(router), usdtForBuy);
            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                usdtForBuy,
                minOdyOut,
                buyPath,
                address(this),
                deadline
            );
        }
        uint256 odyBought = ody.balanceOf(address(this)) - odyBefore;

        // 2) Add liquidity（滑点/最小值由调用方 minLpOdy/minLpUsdt 控制）
        uint256 lpOdyUsed;
        uint256 lpUsdtUsed;
        if (odyBought > 0 && usdtForLp > 0) {
            SafeERC20.forceApprove(ody, address(router), odyBought);
            SafeERC20.forceApprove(usdt, address(router), usdtForLp);
            (lpOdyUsed, lpUsdtUsed, ) = router.addLiquidity(
                address(ody),
                address(usdt),
                odyBought,
                usdtForLp,
                minLpOdy,
                minLpUsdt,
                lpReceiver,
                deadline
            );
        }

        // 3) Direct transfers to foundation / node / leaderboard
        if (foundationUsdt > 0) {
            usdt.safeTransfer(foundation, foundationUsdt);
        }
        if (nodeUsdt > 0) {
            usdt.safeTransfer(nodeAddr, nodeUsdt);
        }
        if (leaderboardUsdt > 0) {
            usdt.safeTransfer(leaderboard, leaderboardUsdt);
        }

        emit Distributed(
            msg.sender,
            usdtForBuy,
            odyBought,
            usdtForLp,
            lpOdyUsed,
            lpUsdtUsed,
            foundationUsdt,
            nodeUsdt,
            leaderboardUsdt
        );
    }

    // -----------------------------
    // Views
    // -----------------------------
    function preview(uint8 feeType) external view returns (Preview memory p) {
        require(feeType == 1 || feeType == 2, "MFV: bad feeType");
        p.feeType = feeType;
        p.usdtBalance = usdt.balanceOf(address(this));
        if (p.usdtBalance == 0) {
            return p;
        }
        p.usdtForBuy = (p.usdtBalance * lpBuyPortion) / BPS_100;
        p.usdtForLp = (p.usdtBalance * lpUsdtPortion) / BPS_100;
        p.foundationUsdt = (p.usdtBalance * foundationPortion) / BPS_100;
        p.nodeUsdt = (p.usdtBalance * nodePortion) / BPS_100;
        p.leaderboardUsdt = (p.usdtBalance * leaderboardPortion) / BPS_100;

        p.estOdyBought = _estimateOut(p.usdtForBuy, buyPath);

        (uint256 reserveOdy, uint256 reserveUsdt) = _getOdyUsdtReservesView();
        if (reserveOdy > 0 && reserveUsdt > 0) {
            (uint256 useOdy, uint256 useUsdt) = _calcLiquidityUse(p.estOdyBought, p.usdtForLp, reserveOdy, reserveUsdt);
            p.estLpOdy = useOdy;
            p.estLpUsdt = useUsdt;
        }
    }

    // -----------------------------
    // Admin configuration
    // -----------------------------
    function setRouter(address _router) external onlyRole(ADMIN_ROLE) {
        require(_router != address(0), "MFV: router zero");
        router = MaintenanceFeeVaultDeps.IPancakeRouterV2(_router);
    }

    function setUsdt(address _usdt) external onlyRole(ADMIN_ROLE) {
        require(_usdt != address(0), "MFV: usdt zero");
        usdt = IERC20Metadata(_usdt);
    }

    function setOdy(address _ody) external onlyRole(ADMIN_ROLE) {
        require(_ody != address(0), "MFV: ody zero");
        ody = IERC20Metadata(_ody);
    }

    function setAddresses(
        address _lpReceiver,
        address _foundation,
        address _node,
        address _leaderboard
    ) external onlyRole(ADMIN_ROLE) {
        require(_lpReceiver != address(0), "MFV: lp zero");
        require(_foundation != address(0), "MFV: foundation zero");
        require(_node != address(0), "MFV: node zero");
        require(_leaderboard != address(0), "MFV: leaderboard zero");
        lpReceiver = _lpReceiver;
        foundation = _foundation;
        nodeAddr = _node;
        leaderboard = _leaderboard;
        emit AddressesUpdated(_lpReceiver, _foundation, _node, _leaderboard);
    }

    function setSigner(address signer, bool allowed) external onlyRole(ADMIN_ROLE) {
        require(signer != address(0), "MFV: signer zero");
        signers[signer] = allowed;
        emit SignerUpdated(signer, allowed);
    }

    function setBuyPath(address[] calldata path) external onlyRole(ADMIN_ROLE) {
        require(path.length >= 2, "MFV: path short");
        require(path[0] == address(usdt), "MFV: path must start with USDT");
        require(path[path.length - 1] == address(ody), "MFV: path must end with ODY");
        buyPath = path;
        emit PathUpdated(path);
    }

    function setPortions(
        uint256 _lpBuy,
        uint256 _lpUsdt,
        uint256 _foundation,
        uint256 _node,
        uint256 _leaderboard
    ) external onlyRole(ADMIN_ROLE) {
        require(
            _lpBuy + _lpUsdt + _foundation + _node + _leaderboard == BPS_100,
            "MFV: portions sum != 100%"
        );
        lpBuyPortion = _lpBuy;
        lpUsdtPortion = _lpUsdt;
        foundationPortion = _foundation;
        nodePortion = _node;
        leaderboardPortion = _leaderboard;
        emit PortionsUpdated(_lpBuy, _lpUsdt, _foundation, _node, _leaderboard);
    }

    /// @notice Withdraw USDT held by this contract to a target address (admin only).
    function withdrawUsdt(address to, uint256 amount)
        external
        onlyRole(ADMIN_ROLE)
        nonReentrant
    {
        require(to != address(0), "MFV: to zero");
        require(amount > 0, "MFV: amount zero");
        usdt.safeTransfer(to, amount);
        emit UsdtWithdrawn(to, amount, msg.sender);
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
    function _requireCoreSet() internal view {
        require(address(router) != address(0), "MFV: router not set");
        require(address(usdt) != address(0), "MFV: usdt not set");
        require(address(ody) != address(0), "MFV: ody not set");
        require(lpReceiver != address(0), "MFV: lp not set");
        require(foundation != address(0), "MFV: foundation not set");
        require(nodeAddr != address(0), "MFV: node not set");
        require(leaderboard != address(0), "MFV: leaderboard not set");
        require(buyPath.length >= 2, "MFV: path not set");
        require(buyPath[0] == address(usdt), "MFV: path must start with USDT");
        require(buyPath[buyPath.length - 1] == address(ody), "MFV: path must end with ODY");
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

    function _recoverSigner(FeePay calldata req, bytes calldata signature) internal view returns (address) {
        require(signature.length == 65, "MFV: bad signature");
        bytes32 structHash = keccak256(
            abi.encode(
                FEEPAY_TYPEHASH,
                req.payer,
                req.amount,
                req.deadline,
                req.requestId,
                req.feeType
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
        return ECDSA.recover(digest, signature);
    }

    /// @dev Estimate output along path (ignores fees); returns 0 if reserves missing
    function _estimateOut(uint256 amountIn, address[] memory path) internal view returns (uint256 out) {
        if (amountIn == 0 || path.length < 2) {
            return 0;
        }
        out = amountIn;
        address factory = router.factory();
        for (uint256 i; i + 1 < path.length; i++) {
            address tokenIn = path[i];
            address tokenOut = path[i + 1];
            address pair = MaintenanceFeeVaultDeps.IPancakeFactory(factory).getPair(tokenIn, tokenOut);
            if (pair == address(0)) {
                return 0;
            }
            (uint256 reserveIn, uint256 reserveOut) = _getOrderedReserves(pair, tokenIn, tokenOut);
            if (reserveIn == 0 || reserveOut == 0) {
                return 0;
            }
            out = (out * reserveOut) / reserveIn;
        }
    }

    /// @dev Get ODY/USDT reserves (runtime)
    function _getOdyUsdtReserves() internal view returns (uint256 reserveOdy, uint256 reserveUsdt) {
        address factory = router.factory();
        address pair = MaintenanceFeeVaultDeps.IPancakeFactory(factory).getPair(address(ody), address(usdt));
        require(pair != address(0), "MFV: pair missing");
        (reserveOdy, reserveUsdt) = _orderedReserves(pair);
    }

    /// @dev Get ODY/USDT reserves (view; returns 0 if pair missing)
    function _getOdyUsdtReservesView() internal view returns (uint256 reserveOdy, uint256 reserveUsdt) {
        address factory = router.factory();
        address pair = MaintenanceFeeVaultDeps.IPancakeFactory(factory).getPair(address(ody), address(usdt));
        if (pair == address(0)) {
            return (0, 0);
        }
        (reserveOdy, reserveUsdt) = _orderedReserves(pair);
    }

    /// @dev Return reserves ordered by token input/output
    function _getOrderedReserves(address pair, address tokenIn, address /*tokenOut*/)
        internal
        view
        returns (uint256 reserveIn, uint256 reserveOut)
    {
        (uint112 r0, uint112 r1, ) = MaintenanceFeeVaultDeps.IPancakePair(pair).getReserves();
        if (MaintenanceFeeVaultDeps.IPancakePair(pair).token0() == tokenIn) {
            reserveIn = r0;
            reserveOut = r1;
        } else {
            reserveIn = r1;
            reserveOut = r0;
        }
    }

    /// @dev Return reserves ordered as (ody, usdt)
    function _orderedReserves(address pair) internal view returns (uint256 reserveOdy, uint256 reserveUsdt) {
        MaintenanceFeeVaultDeps.IPancakePair p = MaintenanceFeeVaultDeps.IPancakePair(pair);
        (uint112 r0, uint112 r1, ) = p.getReserves();
        if (p.token0() == address(ody)) {
            reserveOdy = r0;
            reserveUsdt = r1;
        } else {
            reserveOdy = r1;
            reserveUsdt = r0;
        }
    }

    /// @dev Calculate LP usage (optimal ratio)
    function _calcLiquidityUse(
        uint256 odyAmount,
        uint256 usdtAmount,
        uint256 reserveOdy,
        uint256 reserveUsdt
    ) internal pure returns (uint256 useOdy, uint256 useUsdt) {
        if (odyAmount == 0 || usdtAmount == 0 || reserveOdy == 0 || reserveUsdt == 0) {
            return (0, 0);
        }
        uint256 optimalUsdt = (odyAmount * reserveUsdt) / reserveOdy;
        if (optimalUsdt <= usdtAmount) {
            useOdy = odyAmount;
            useUsdt = optimalUsdt;
        } else {
            uint256 optimalOdy = (usdtAmount * reserveOdy) / reserveUsdt;
            useOdy = optimalOdy;
            useUsdt = usdtAmount;
        }
    }
}
