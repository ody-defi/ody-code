// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {TaxDistributorDeps} from "./TaxDistributorDeps.sol";
import {TaxDistributorEvents} from "./TaxDistributorEvents.sol";

/**
 * @title TaxDistributor - sell-tax splitter
 * @notice Receives ODYToken tax (about 3%) and distributes automatically:
 *         - Sell 2.5% ODY -> USDT
 *         - Add 0.5% ODY + 0.5% USDT to LP (receiver configurable, can be burn later)
 *         - USDT split: 1% foundation, 0.5% genesis, 0.5% leaderboard, 0.5% LP
 *         Relative to the 3% tax: 5/6 sold, 1/6 kept as ODY for LP; sold USDT is split 1:2:1:1 (LP:foundation:genesis:leaderboard).
 */
contract TaxDistributor is
    Initializable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    TaxDistributorEvents
{
    using SafeERC20 for IERC20;

    // Roles
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Key addresses
    IERC20Metadata public ody;
    IERC20 public usdt;
    TaxDistributorDeps.IPancakeRouterV2 public router;

    address public lpReceiver;
    address public foundation;
    address public genesisNode;
    address public leaderboardPool;

    // Sell path (ODY -> USDT)
    address[] public sellPath;

    // Stats
    uint256 public totalDistributedTokens;
    uint256 public totalDistributedUsdt;

    constructor() {
        _disableInitializers();
    }

    /**
     * @param _router PancakeV2 router
     * @param _ody    ODY token
     * @param _usdt   USDT token
     * @param _lpReceiver LP receiver
     * @param _foundation Foundation address
     * @param _genesis    Genesis node address
     * @param _leaderboard Leaderboard reward pool address
     */
    function initialize(
        address _router,
        address _ody,
        address _usdt,
        address _lpReceiver,
        address _foundation,
        address _genesis,
        address _leaderboard
    ) external initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();

        router = TaxDistributorDeps.IPancakeRouterV2(_router);
        ody = IERC20Metadata(_ody);
        usdt = IERC20(_usdt);
        lpReceiver = _lpReceiver;
        foundation = _foundation;
        genesisNode = _genesis;
        leaderboardPool = _leaderboard;

        // Default sell path [ODY, USDT] when both provided
        if (_ody != address(0) && _usdt != address(0)) {
            sellPath.push(_ody);
            sellPath.push(_usdt);
        }

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);
        _grantRole(OPERATOR_ROLE, msg.sender);
    }

    // Split ratios (based on total 3% tax: sell 5/6, keep 1/6)
    uint256 private constant TOTAL_PORTION = 6;
    uint256 private constant SELL_PORTION = 5; // Sell 5/6
    uint256 private constant LP_TOKEN_PORTION = 1; // Keep 1/6 as ODY for LP

    // USDT allocation (relative to sold USDT), totals 5 parts
    uint256 private constant USDT_PORTION_TOTAL = 5;
    uint256 private constant USDT_PORTION_LP = 1;
    uint256 private constant USDT_PORTION_FOUNDATION = 2;
    uint256 private constant USDT_PORTION_GENESIS = 1;
    uint256 private constant USDT_PORTION_LEADERBOARD = 1;

    /**
     * @notice Run one distribution (sell + add liquidity + split USDT)
     * @param minUsdtOut Minimum USDT from selling ODY (slippage check)
     * @param minLpOdy   Minimum ODY accepted for addLiquidity
     * @param minLpUsdt  Minimum USDT accepted for addLiquidity
     * @param deadline   Router trade deadline
     */
    function distribute(
        uint256 minUsdtOut,
        uint256 minLpOdy,
        uint256 minLpUsdt,
        uint256 deadline
    ) external onlyRole(OPERATOR_ROLE) whenNotPaused nonReentrant {
        _requireCoreSet();

        uint256 bal = ody.balanceOf(address(this));
        require(bal > 0, "no tokens");

        // Split amount between selling and LP (5:1)
        uint256 sellAmount = (bal * SELL_PORTION) / TOTAL_PORTION;
        uint256 lpTokenAmount = bal - sellAmount; // preserve precision

        // Sell ODY -> USDT
        uint256 usdtBefore = usdt.balanceOf(address(this));
        SafeERC20.forceApprove(IERC20(address(ody)), address(router), sellAmount);
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            sellAmount,
            minUsdtOut,
            sellPath,
            address(this),
            deadline
        );
        uint256 usdtOut = usdt.balanceOf(address(this)) - usdtBefore;
        require(usdtOut >= minUsdtOut, "slippage sell");

        // USDT allocation (1:2:1:1)
        uint256 lpUsdt = (usdtOut * USDT_PORTION_LP) / USDT_PORTION_TOTAL;
        uint256 foundationUsdt = (usdtOut * USDT_PORTION_FOUNDATION) / USDT_PORTION_TOTAL;
        uint256 genesisUsdt = (usdtOut * USDT_PORTION_GENESIS) / USDT_PORTION_TOTAL;
        uint256 leaderboardUsdt = usdtOut - lpUsdt - foundationUsdt - genesisUsdt; // remainder to leaderboard

        // Add liquidity: lpTokenAmount + lpUsdt
        SafeERC20.forceApprove(IERC20(address(ody)), address(router), lpTokenAmount);
        SafeERC20.forceApprove(IERC20(address(usdt)), address(router), lpUsdt);
        router.addLiquidity(
            address(ody),
            address(usdt),
            lpTokenAmount,
            lpUsdt,
            minLpOdy,
            minLpUsdt,
            lpReceiver,
            deadline
        );

        // Distribute USDT
        usdt.safeTransfer(foundation, foundationUsdt);
        usdt.safeTransfer(genesisNode, genesisUsdt);
        usdt.safeTransfer(leaderboardPool, leaderboardUsdt);

        totalDistributedTokens += bal;
        totalDistributedUsdt += usdtOut;

        emit Distributed(
            msg.sender,
            sellAmount,
            lpTokenAmount,
            usdtOut,
            lpUsdt,
            foundationUsdt,
            genesisUsdt,
            leaderboardUsdt
        );
    }

    // -----------------------
    // Admin configuration
    // -----------------------
    function setRouter(address _router) external onlyRole(ADMIN_ROLE) {
        router = TaxDistributorDeps.IPancakeRouterV2(_router);
        emit RouterUpdated(_router);
    }

    function setSellPath(address[] calldata _path) external onlyRole(ADMIN_ROLE) {
        require(_path.length >= 2, "path too short");
        sellPath = _path;
        emit SellPathUpdated(_path);
    }

    /// @notice Set ODY address (can be zero at init, configured later)
    function setOdy(address _ody) external onlyRole(ADMIN_ROLE) {
        require(_ody != address(0), "zero ody");
        ody = IERC20Metadata(_ody);
        emit OdyUpdated(_ody);

        // If path not set, default to [ODY, USDT] once USDT is set
        if (sellPath.length < 2 && address(usdt) != address(0)) {
            sellPath = new address[](2);
            sellPath[0] = _ody;
            sellPath[1] = address(usdt);
            emit SellPathUpdated(sellPath);
        }
    }

    /// @notice Set USDT address (can be zero at init, configured later)
    function setUsdt(address _usdt) external onlyRole(ADMIN_ROLE) {
        require(_usdt != address(0), "zero usdt");
        usdt = IERC20(_usdt);
        emit UsdtUpdated(_usdt);

        if (sellPath.length < 2 && address(ody) != address(0)) {
            sellPath = new address[](2);
            sellPath[0] = address(ody);
            sellPath[1] = _usdt;
            emit SellPathUpdated(sellPath);
        }
    }

    function setLpReceiver(address _lpReceiver) external onlyRole(ADMIN_ROLE) {
        lpReceiver = _lpReceiver;
        emit LpReceiverUpdated(_lpReceiver);
    }

    function setFoundation(address _foundation) external onlyRole(ADMIN_ROLE) {
        foundation = _foundation;
        emit FoundationUpdated(_foundation);
    }

    function setGenesis(address _genesis) external onlyRole(ADMIN_ROLE) {
        genesisNode = _genesis;
        emit GenesisUpdated(_genesis);
    }

    function setLeaderboard(address _leaderboard) external onlyRole(ADMIN_ROLE) {
        leaderboardPool = _leaderboard;
        emit LeaderboardUpdated(_leaderboard);
    }

    /**
     * @notice Withdraw any ERC20 token held by this contract to a target address.
     * @dev Intended for admin rescue/ops; can withdraw ODY/USDT or any other token accidentally sent here.
     */
    function withdrawToken(address token, address to, uint256 amount)
        external
        onlyRole(ADMIN_ROLE)
        nonReentrant
    {
        require(token != address(0), "token zero");
        require(to != address(0), "to zero");
        require(amount > 0, "amount zero");
        IERC20(token).safeTransfer(to, amount);
        emit TokenWithdrawn(token, to, amount);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    // -----------------------
    // View: distribution preview
    // -----------------------
    struct Preview {
        uint256 tokenBalance;
        uint256 sellAmount;
        uint256 lpTokenAmount;
        uint256 estUsdtOut;
        uint256 lpUsdt;
        uint256 foundationUsdt;
        uint256 genesisUsdt;
        uint256 leaderboardUsdt;
    }

    /// @notice Estimate one distribute call based on current reserves (ignoring fees/slippage)
    function preview() external view returns (Preview memory p) {
        p.tokenBalance = ody.balanceOf(address(this));
        if (p.tokenBalance == 0) {
            return p;
        }
        p.sellAmount = (p.tokenBalance * SELL_PORTION) / TOTAL_PORTION;
        p.lpTokenAmount = p.tokenBalance - p.sellAmount;

        (uint256 reserveOdy, uint256 reserveUsdt) = _getReserves();
        if (reserveOdy > 0 && reserveUsdt > 0) {
            // Simplified pricing: price = reserveUsdt / reserveOdy
            p.estUsdtOut = (p.sellAmount * reserveUsdt) / reserveOdy;
            p.lpUsdt = (p.estUsdtOut * USDT_PORTION_LP) / USDT_PORTION_TOTAL;
            p.foundationUsdt = (p.estUsdtOut * USDT_PORTION_FOUNDATION) / USDT_PORTION_TOTAL;
            p.genesisUsdt = (p.estUsdtOut * USDT_PORTION_GENESIS) / USDT_PORTION_TOTAL;
            p.leaderboardUsdt = p.estUsdtOut - p.lpUsdt - p.foundationUsdt - p.genesisUsdt;
        }
    }

    // -----------------------
    // Internal helpers
    // -----------------------
    function _requireCoreSet() internal view {
        require(address(ody) != address(0), "ody not set");
        require(address(usdt) != address(0), "usdt not set");
        require(address(router) != address(0), "router not set");
        require(lpReceiver != address(0), "lpReceiver not set");
        require(foundation != address(0), "foundation not set");
        require(genesisNode != address(0), "genesis not set");
        require(leaderboardPool != address(0), "leaderboard not set");
        require(sellPath.length >= 2, "path not set");
    }

    function _getPair() internal view returns (TaxDistributorDeps.IPancakePair) {
        address factory = router.factory();
        address pair = TaxDistributorDeps.IPancakeFactory(factory).getPair(address(ody), address(usdt));
        require(pair != address(0), "pair not found");
        return TaxDistributorDeps.IPancakePair(pair);
    }

    function _getReserves() internal view returns (uint256 reserveOdy, uint256 reserveUsdt) {
        TaxDistributorDeps.IPancakePair pair = _getPair();
        (uint112 r0, uint112 r1, ) = pair.getReserves();
        if (pair.token0() == address(ody)) {
            reserveOdy = r0;
            reserveUsdt = r1;
        } else {
            reserveOdy = r1;
            reserveUsdt = r0;
        }
    }
}
