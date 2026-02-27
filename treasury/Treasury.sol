// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {TreasuryDeps} from "./TreasuryDeps.sol";
import {TreasuryEvents} from "./TreasuryEvents.sol";

/**
 * @title Treasury (DAO transition version)
 * @notice Immutable, non-upgradeable treasury that can only do one action:
 *         swap USDT -> ODY on a fixed router and immediately burn ODY.
 */
contract Treasury is TreasuryEvents {
    using SafeERC20 for IERC20;

    IERC20 public immutable USDT;
    IERC20 public immutable ODY;
    address public immutable router;
    address public immutable burnAddress;

    // Fixed swap path: [USDT, ODY]
    address[] private _path;

    // Risk controls
    uint256 public maxUsdtPerTx;
    uint256 public cooldown;
    uint256 public lastExecAt;

    // Roles
    address public owner;
    address public guardian;

    // Emergency pause
    bool public paused;

    uint256 public constant MAX_COOLDOWN = 30 days;

    modifier onlyOwner() {
        require(msg.sender == owner, "TREASURY: not owner");
        _;
    }

    modifier onlyGuardian() {
        require(msg.sender == guardian, "TREASURY: not guardian");
        _;
    }

    modifier whenNotPaused() {
        require(!paused, "TREASURY: paused");
        _;
    }

    constructor(
        address usdt,
        address ody,
        address router_,
        address burnAddress_,
        address multisigOwner,
        address guardian_,
        uint256 maxUsdtPerTx_,
        uint256 cooldown_
    ) {
        require(usdt != address(0), "TREASURY: usdt zero");
        require(ody != address(0), "TREASURY: ody zero");
        require(router_ != address(0), "TREASURY: router zero");
        require(burnAddress_ != address(0), "TREASURY: burn zero");
        require(multisigOwner != address(0), "TREASURY: owner zero");
        require(guardian_ != address(0), "TREASURY: guardian zero");

        USDT = IERC20(usdt);
        ODY = IERC20(ody);
        router = router_;
        burnAddress = burnAddress_;

        owner = multisigOwner;
        guardian = guardian_;

        _setRiskParams(maxUsdtPerTx_, cooldown_);

        _path.push(usdt);
        _path.push(ody);

        emit OwnershipTransferred(address(0), multisigOwner);
        emit GuardianChanged(address(0), guardian_);
    }

    // -----------------------
    // Core action
    // -----------------------

    function buyAndBurn(uint256 usdtAmount, uint256 minOdyOut, uint256 deadline) external onlyOwner whenNotPaused {
        require(usdtAmount > 0, "TREASURY: usdtAmount zero");
        require(usdtAmount <= maxUsdtPerTx, "TREASURY: over maxUsdtPerTx");
        require(deadline >= block.timestamp, "TREASURY: deadline past");

        uint256 prevExecAt = lastExecAt;
        if (prevExecAt != 0 && cooldown != 0) {
            require(block.timestamp >= prevExecAt + cooldown, "TREASURY: cooldown");
        }

        uint256 usdtBal = USDT.balanceOf(address(this));
        require(usdtBal >= usdtAmount, "TREASURY: insufficient USDT");

        uint256 odyBefore = ODY.balanceOf(address(this));

        // Approve router (SafeERC20.forceApprove: sets allowance to 0 then desired value as needed)
        IERC20(address(USDT)).forceApprove(router, usdtAmount);

        TreasuryDeps.IRouterSwap(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            usdtAmount,
            minOdyOut,
            _path,
            address(this),
            deadline
        );

        uint256 odyAfter = ODY.balanceOf(address(this));
        uint256 odyOut = odyAfter - odyBefore;
        require(odyOut >= minOdyOut, "TREASURY: odyOut < min");

        ODY.safeTransfer(burnAddress, odyOut);

        lastExecAt = block.timestamp;
        emit BuyAndBurn(usdtAmount, odyOut, burnAddress, msg.sender);
    }

    // -----------------------
    // Pause controls
    // -----------------------

    function pause() external onlyGuardian {
        require(!paused, "TREASURY: already paused");
        paused = true;
        emit Paused(msg.sender);
    }

    function unpause() external onlyOwner {
        require(paused, "TREASURY: not paused");
        paused = false;
        emit Unpaused(msg.sender);
    }

    // -----------------------
    // Admin (owner)
    // -----------------------

    function setGuardian(address newGuardian) external onlyOwner {
        require(newGuardian != address(0), "TREASURY: guardian zero");
        address old = guardian;
        guardian = newGuardian;
        emit GuardianChanged(old, newGuardian);
    }

    function setRiskParams(uint256 newMaxUsdtPerTx, uint256 newCooldown) external onlyOwner {
        _setRiskParams(newMaxUsdtPerTx, newCooldown);
        emit RiskParamsChanged(newMaxUsdtPerTx, newCooldown);
    }

    function transferOwnership(address nextOwner) external onlyOwner {
        require(nextOwner != address(0), "TREASURY: owner zero");
        address prev = owner;
        owner = nextOwner;
        emit OwnershipTransferred(prev, nextOwner);
    }

    /// @notice Rescue non-core tokens accidentally sent here (USDT/ODY cannot be rescued).
    function rescueToken(address token, uint256 amount, address to) external onlyOwner {
        require(token != address(0), "TREASURY: token zero");
        require(to != address(0), "TREASURY: to zero");
        require(amount > 0, "TREASURY: amount zero");
        require(token != address(USDT) && token != address(ODY), "TREASURY: token blocked");
        IERC20(token).safeTransfer(to, amount);
    }

    // -----------------------
    // Views
    // -----------------------

    function getPath() external view returns (address[] memory) {
        return _path;
    }

    // -----------------------
    // Internal
    // -----------------------

    function _setRiskParams(uint256 maxUsdtPerTx_, uint256 cooldown_) internal {
        require(maxUsdtPerTx_ > 0, "TREASURY: maxUsdtPerTx zero");
        require(cooldown_ <= MAX_COOLDOWN, "TREASURY: cooldown too long");
        maxUsdtPerTx = maxUsdtPerTx_;
        cooldown = cooldown_;
        emit RiskParamsChanged(maxUsdtPerTx_, cooldown_);
    }

    receive() external payable {
        revert("TREASURY: no native");
    }

    fallback() external payable {
        revert("TREASURY: no native");
    }
}
