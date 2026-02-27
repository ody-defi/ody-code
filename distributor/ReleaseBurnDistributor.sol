// 废弃，不再做释放分配

//// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
//
//import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
//import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
//import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
//import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
//import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
//import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
//
///// @dev Minimal Pancake/UniV2 router interface (supports fee-on-transfer tokens)
//interface IPancakeRouterV2 {
//    function factory() external view returns (address);
//
//    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
//        uint256 amountIn,
//        uint256 amountOutMin,
//        address[] calldata path,
//        address to,
//        uint256 deadline
//    ) external;
//
//    function addLiquidity(
//        address tokenA,
//        address tokenB,
//        uint256 amountADesired,
//        uint256 amountBDesired,
//        uint256 amountAMin,
//        uint256 amountBMin,
//        address to,
//        uint256 deadline
//    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);
//}
//
//interface IPancakeFactory {
//    function getPair(address tokenA, address tokenB) external view returns (address);
//}
//
//interface IPancakePair {
//    function token0() external view returns (address);
//
//    function token1() external view returns (address);
//
//    function getReserves()
//        external
//        view
//        returns (
//            uint112 reserve0,
//            uint112 reserve1,
//            uint32 blockTimestampLast
//        );
//}
//
///**
// * @title ReleaseBurnDistributor
// * @notice Distributor used when "burning USDT" during release:
// *         - 20% USDT buys ODY
// *         - 20% USDT + bought ODY added to LP (LP receiver configurable)
// *         - 30% USDT -> foundation; 15% -> genesis node; 15% -> leaderboard pool
// */
//contract ReleaseBurnDistributor is
//    Initializable,
//    AccessControlUpgradeable,
//    PausableUpgradeable,
//    ReentrancyGuardUpgradeable
//{
//    using SafeERC20 for IERC20Metadata;
//
//    // Roles
//    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
//    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");
//
//    // Split ratios (bps, 10000=100%)
//    uint256 private constant BPS_100 = 10_000;
//    uint256 private constant BUY_PORTION = 2_000; // 20%
//    uint256 private constant LP_USDT_PORTION = 2_000; // 20%
//    uint256 private constant FOUNDATION_PORTION = 3_000; // 30%
//    uint256 private constant GENESIS_PORTION = 1_500; // 15%
//    uint256 private constant LEADERBOARD_PORTION = 1_500; // 15%
//    uint256 private constant TOLERANCE_BPS = 2_000; // 20% lower bound
//
//    // Core addresses
//    IERC20Metadata public usdt;
//    IERC20Metadata public ody;
//    IPancakeRouterV2 public router;
//    address public lpReceiver;
//    address public foundation;
//    address public genesisNode;
//    address public leaderboard;
//
//    // Path (USDT -> ODY)
//    address[] public buyPath;
//
//    // Stats
//    uint256 public totalUsdtDistributed;
//    uint256 public totalOdyBought;
//    uint256 public totalLpOdy;
//    uint256 public totalLpUsdt;
//
//    // Events
//    event Distributed(
//        address indexed caller,
//        uint256 usdtTotal,
//        uint256 usdtForBuy,
//        uint256 odyBought,
//        uint256 usdtForLp,
//        uint256 lpOdyUsed,
//        uint256 lpUsdtUsed,
//        uint256 foundationUsdt,
//        uint256 genesisUsdt,
//        uint256 leaderboardUsdt
//    );
//    event RouterUpdated(address indexed router);
//    event TokensUpdated(address indexed ody, address indexed usdt);
//    event LpReceiverUpdated(address indexed lpReceiver);
//    event FoundationUpdated(address indexed foundation);
//    event GenesisUpdated(address indexed genesis);
//    event LeaderboardUpdated(address indexed leaderboard);
//    event BuyPathUpdated(address[] buyPath);
//
//    struct DistVars {
//        uint256 balance;
//        uint256 usdtForBuy;
//        uint256 usdtForLp;
//        uint256 foundationUsdt;
//        uint256 genesisUsdt;
//        uint256 leaderboardUsdt;
//        uint256 odyBought;
//        uint256 useOdy;
//        uint256 useUsdt;
//        uint256 minOdy;
//        uint256 minUsdt;
//        uint256 lpOdyUsed;
//        uint256 lpUsdtUsed;
//    }
//
//    constructor() {
//        _disableInitializers();
//    }
//
//    function initialize(
//        address _router,
//        address _ody,
//        address _usdt,
//        address _lpReceiver,
//        address _foundation,
//        address _genesis,
//        address _leaderboard
//    ) external initializer {
//        require(_router != address(0), "RBD: router zero");
//        require(_ody != address(0), "RBD: ody zero");
//        require(_usdt != address(0), "RBD: usdt zero");
//        require(_lpReceiver != address(0), "RBD: lp zero");
//        require(_foundation != address(0), "RBD: foundation zero");
//        require(_genesis != address(0), "RBD: genesis zero");
//        require(_leaderboard != address(0), "RBD: leaderboard zero");
//
//        __AccessControl_init();
//        __Pausable_init();
//        __ReentrancyGuard_init();
//
//        router = IPancakeRouterV2(_router);
//        ody = IERC20Metadata(_ody);
//        usdt = IERC20Metadata(_usdt);
//        lpReceiver = _lpReceiver;
//        foundation = _foundation;
//        genesisNode = _genesis;
//        leaderboard = _leaderboard;
//
//        buyPath.push(_usdt);
//        buyPath.push(_ody);
//
//        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
//        _grantRole(ADMIN_ROLE, msg.sender);
//        _grantRole(OPERATOR_ROLE, msg.sender);
//    }
//
//    /**
//     * @notice Distribute: buy ODY + add LP + transfer to foundation/genesis/leaderboard
//     * @param minBuyOdyOut Minimum ODY from buy (slippage)
//     * @param minLpOdy Minimum ODY accepted for LP
//     * @param minLpUsdt Minimum USDT accepted for LP
//     * @param deadline Router deadline
//     */
//    function distribute(
//        uint256 minBuyOdyOut,
//        uint256 minLpOdy,
//        uint256 minLpUsdt,
//        uint256 deadline
//    ) external onlyRole(OPERATOR_ROLE) whenNotPaused nonReentrant {
//        _requireCoreSet();
//        require(deadline >= block.timestamp, "RBD: deadline past");
//
//        DistVars memory v;
//        v.balance = usdt.balanceOf(address(this));
//        require(v.balance > 0, "RBD: empty");
//
//        v.usdtForBuy = (v.balance * BUY_PORTION) / BPS_100;
//        v.usdtForLp = (v.balance * LP_USDT_PORTION) / BPS_100;
//        v.foundationUsdt = (v.balance * FOUNDATION_PORTION) / BPS_100;
//        v.genesisUsdt = (v.balance * GENESIS_PORTION) / BPS_100;
//        v.leaderboardUsdt = v.balance - v.usdtForBuy - v.usdtForLp - v.foundationUsdt - v.genesisUsdt; // Remainder to leaderboard
//
//        // 1) Buy ODY
//        uint256 odyBefore = ody.balanceOf(address(this));
//        _forceApprove(usdt, address(router), v.usdtForBuy);
//        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
//            v.usdtForBuy,
//            minBuyOdyOut,
//            buyPath,
//            address(this),
//            deadline
//        );
//        v.odyBought = ody.balanceOf(address(this)) - odyBefore;
//        require(v.odyBought >= minBuyOdyOut, "RBD: buy slippage");
//
//        // 2) Add LP
//        (uint256 reserveOdy, uint256 reserveUsdt) = _getReserves();
//        require(reserveOdy > 0 && reserveUsdt > 0, "RBD: empty pair");
//        (v.useOdy, v.useUsdt, v.minOdy, v.minUsdt) = _calcLiquidityParams(
//            v.odyBought,
//            v.usdtForLp,
//            reserveOdy,
//            reserveUsdt
//        );
//
//        if (v.useOdy > 0 && v.useUsdt > 0) {
//            _forceApprove(ody, address(router), v.odyBought);
//            _forceApprove(usdt, address(router), v.usdtForLp);
//            (v.lpOdyUsed, v.lpUsdtUsed, ) = router.addLiquidity(
//                address(ody),
//                address(usdt),
//                v.odyBought,
//                v.usdtForLp,
//                minLpOdy > 0 ? minLpOdy : v.minOdy,
//                minLpUsdt > 0 ? minLpUsdt : v.minUsdt,
//                lpReceiver,
//                deadline
//            );
//        }
//
//        // 3) Distribute to parties
//        if (v.foundationUsdt > 0) {
//            usdt.safeTransfer(foundation, v.foundationUsdt);
//        }
//        if (v.genesisUsdt > 0) {
//            usdt.safeTransfer(genesisNode, v.genesisUsdt);
//        }
//        if (v.leaderboardUsdt > 0) {
//            usdt.safeTransfer(leaderboard, v.leaderboardUsdt);
//        }
//
//        totalUsdtDistributed += v.balance;
//        totalOdyBought += v.odyBought;
//        totalLpOdy += v.lpOdyUsed;
//        totalLpUsdt += v.lpUsdtUsed;
//
//        emit Distributed(
//            msg.sender,
//            v.balance,
//            v.usdtForBuy,
//            v.odyBought,
//            v.usdtForLp,
//            v.lpOdyUsed,
//            v.lpUsdtUsed,
//            v.foundationUsdt,
//            v.genesisUsdt,
//            v.leaderboardUsdt
//        );
//    }
//
//    // -------------------
//    // Views
//    // -------------------
//    struct Preview {
//        uint256 usdtBalance;
//        uint256 usdtForBuy;
//        uint256 usdtForLp;
//        uint256 foundationUsdt;
//        uint256 genesisUsdt;
//        uint256 leaderboardUsdt;
//        uint256 estOdyBought;
//        uint256 estLpOdy;
//        uint256 estLpUsdt;
//    }
//
//    function preview() external view returns (Preview memory p) {
//        p.usdtBalance = usdt.balanceOf(address(this));
//        if (p.usdtBalance == 0) return p;
//
//        p.usdtForBuy = (p.usdtBalance * BUY_PORTION) / BPS_100;
//        p.usdtForLp = (p.usdtBalance * LP_USDT_PORTION) / BPS_100;
//        p.foundationUsdt = (p.usdtBalance * FOUNDATION_PORTION) / BPS_100;
//        p.genesisUsdt = (p.usdtBalance * GENESIS_PORTION) / BPS_100;
//        p.leaderboardUsdt = p.usdtBalance - p.usdtForBuy - p.usdtForLp - p.foundationUsdt - p.genesisUsdt;
//
//        (uint256 reserveOdy, uint256 reserveUsdt) = _getReservesView();
//        if (reserveOdy > 0 && reserveUsdt > 0) {
//            p.estOdyBought = (p.usdtForBuy * reserveOdy) / reserveUsdt; // Ignore fee in estimate
//            (p.estLpOdy, p.estLpUsdt, , ) = _calcLiquidityParams(
//                p.estOdyBought,
//                p.usdtForLp,
//                reserveOdy,
//                reserveUsdt
//            );
//        }
//    }
//
//    // -------------------
//    // Admin
//    // -------------------
//    function setRouter(address _router) external onlyRole(ADMIN_ROLE) {
//        require(_router != address(0), "RBD: router zero");
//        router = IPancakeRouterV2(_router);
//        emit RouterUpdated(_router);
//    }
//
//    function setTokens(address _ody, address _usdt) external onlyRole(ADMIN_ROLE) {
//        require(_ody != address(0), "RBD: ody zero");
//        require(_usdt != address(0), "RBD: usdt zero");
//        ody = IERC20Metadata(_ody);
//        usdt = IERC20Metadata(_usdt);
//        emit TokensUpdated(_ody, _usdt);
//    }
//
//    function setLpReceiver(address _lpReceiver) external onlyRole(ADMIN_ROLE) {
//        require(_lpReceiver != address(0), "RBD: lp zero");
//        lpReceiver = _lpReceiver;
//        emit LpReceiverUpdated(_lpReceiver);
//    }
//
//    function setFoundation(address _foundation) external onlyRole(ADMIN_ROLE) {
//        require(_foundation != address(0), "RBD: foundation zero");
//        foundation = _foundation;
//        emit FoundationUpdated(_foundation);
//    }
//
//    function setGenesis(address _genesis) external onlyRole(ADMIN_ROLE) {
//        require(_genesis != address(0), "RBD: genesis zero");
//        genesisNode = _genesis;
//        emit GenesisUpdated(_genesis);
//    }
//
//    function setLeaderboard(address _leaderboard) external onlyRole(ADMIN_ROLE) {
//        require(_leaderboard != address(0), "RBD: leaderboard zero");
//        leaderboard = _leaderboard;
//        emit LeaderboardUpdated(_leaderboard);
//    }
//
//    function setBuyPath(address[] calldata path) external onlyRole(ADMIN_ROLE) {
//        require(path.length >= 2, "RBD: path short");
//        require(path[0] == address(usdt), "RBD: path must start USDT");
//        require(path[path.length - 1] == address(ody), "RBD: path must end ODY");
//        buyPath = path;
//        emit BuyPathUpdated(path);
//    }
//
//    function pause() external onlyRole(ADMIN_ROLE) {
//        _pause();
//    }
//
//    function unpause() external onlyRole(ADMIN_ROLE) {
//        _unpause();
//    }
//
//    // -------------------
//    // Internal
//    // -------------------
//    function _requireCoreSet() internal view {
//        require(address(router) != address(0), "RBD: router not set");
//        require(address(ody) != address(0), "RBD: ody not set");
//        require(address(usdt) != address(0), "RBD: usdt not set");
//        require(lpReceiver != address(0), "RBD: lp not set");
//        require(foundation != address(0), "RBD: foundation not set");
//        require(genesisNode != address(0), "RBD: genesis not set");
//        require(leaderboard != address(0), "RBD: leaderboard not set");
//        require(buyPath.length >= 2, "RBD: path not set");
//        require(buyPath[0] == address(usdt), "RBD: path must start USDT");
//        require(buyPath[buyPath.length - 1] == address(ody), "RBD: path must end ODY");
//    }
//
//    function _forceApprove(IERC20Metadata token, address spender, uint256 amount) internal {
//        token.forceApprove(spender, 0);
//        token.forceApprove(spender, amount);
//    }
//
//    function _getReserves() internal view returns (uint256 reserveOdy, uint256 reserveUsdt) {
//        address factory = router.factory();
//        address pair = IPancakeFactory(factory).getPair(address(ody), address(usdt));
//        require(pair != address(0), "RBD: pair missing");
//        (reserveOdy, reserveUsdt) = _orderedReserves(pair);
//    }
//
//    function _getReservesView() internal view returns (uint256 reserveOdy, uint256 reserveUsdt) {
//        address factory = router.factory();
//        address pair = IPancakeFactory(factory).getPair(address(ody), address(usdt));
//        if (pair == address(0)) {
//            return (0, 0);
//        }
//        (reserveOdy, reserveUsdt) = _orderedReserves(pair);
//    }
//
//    function _orderedReserves(address pair) internal view returns (uint256 reserveOdy, uint256 reserveUsdt) {
//        IPancakePair p = IPancakePair(pair);
//        (uint112 r0, uint112 r1, ) = p.getReserves();
//        if (p.token0() == address(ody)) {
//            reserveOdy = r0;
//            reserveUsdt = r1;
//        } else {
//            reserveOdy = r1;
//            reserveUsdt = r0;
//        }
//    }
//
//    /// @dev Calculate LP usage and minimums (20% lower bound)
//    function _calcLiquidityParams(
//        uint256 odyAmount,
//        uint256 usdtAmount,
//        uint256 reserveOdy,
//        uint256 reserveUsdt
//    ) internal pure returns (uint256 useOdy, uint256 useUsdt, uint256 minOdy, uint256 minUsdt) {
//        if (odyAmount == 0 || usdtAmount == 0 || reserveOdy == 0 || reserveUsdt == 0) {
//            return (0, 0, 0, 0);
//        }
//        uint256 optimalUsdt = (odyAmount * reserveUsdt) / reserveOdy;
//        if (optimalUsdt <= usdtAmount) {
//            useOdy = odyAmount;
//            useUsdt = optimalUsdt;
//        } else {
//            uint256 optimalOdy = (usdtAmount * reserveOdy) / reserveUsdt;
//            useOdy = optimalOdy;
//            useUsdt = usdtAmount;
//        }
//        minOdy = (useOdy * (BPS_100 - TOLERANCE_BPS)) / BPS_100;
//        minUsdt = (useUsdt * (BPS_100 - TOLERANCE_BPS)) / BPS_100;
//    }
//}
