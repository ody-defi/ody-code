// SPDX-License-Identifier: MIT
pragma solidity ^0.8.28;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/introspection/ERC165Upgradeable.sol";
import {IODYMinter, IODYToken} from "./ODYMinterInterfaces.sol";
import {ODYMinterEvents} from "./ODYMinterEvents.sol";

/**
 * @title ODYMinter
 * @notice Minting gateway for the ODY protocol
 *
 * Design goals:
 * - Match ARKMinter behavior: MINTER_ROLE can mint per rules;
 * - Support Pausable / ReentrancyGuard / AccessControl (stack compatible);
 * - ERC165 declares support for IODYMinter for module discovery (RBS/Router);
 * - Clearer naming and events.
 */
contract ODYMinter is
    Initializable,
    ERC165Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable,
    ReentrancyGuardUpgradeable,
    ODYMinterEvents,
    IODYMinter
{
    // =========================
    //         Roles
    // =========================

    /// @dev Minting role: can call mint
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    /// @dev Admin role: can change config/pause
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    // =========================
    //        State
    // =========================

    /// @notice ODY token contract (implements IODYToken)
    IODYToken public ody;

    /// @notice Max mint per tx (0 = unlimited)
    uint256 public maxMintPerTx;

    /// @notice Enable per-minter allowance limit
    bool public allowanceEnabled;

    /// @notice Remaining mint allowance per minter (effective when allowanceEnabled = true)
    mapping(address => uint256) public mintAllowance;

    /// @notice Rolling window size for mint limit (0 = disabled)
    uint256 public mintWindowSize;

    /// @notice Max mint amount within a window (0 = disabled)
    uint256 public mintMaxPerWindow;

    /// @notice Current window start timestamp (0 = uninitialized)
    uint256 public mintWindowStart;

    /// @notice Minted amount within the current window
    uint256 public mintedInWindow;

    // =========================
    //         Custom errors
    // =========================

    error OdyTokenIsZeroAddress();

    // =========================
    //         Initialization
    // =========================

    /// @dev Disable initializer on implementation (standard OZ proxy guard)
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initialize ODYMinter
     * @param _ody ODY token address (must implement IODYToken)
     *
     * Typically called once via TransparentUpgradeableProxy.
     */
    function initialize(IODYToken _ody) public initializer {
        __AccessControl_init();
        __Pausable_init();
        __ReentrancyGuard_init();
        __ERC165_init();

        if (address(_ody) == address(0)) {
            revert OdyTokenIsZeroAddress();
        }

        ody = _ody;

        // Grant deployer admin/minter/default admin
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(ADMIN_ROLE, msg.sender);

        emit OdyTokenChanged(address(_ody));
    }

    // =========================
    //         Core logic
    // =========================

    /**
     * @notice Mint ODY to address
     * @dev MINTER_ROLE only; protected by pause & nonReentrant
     */
    function mint(
        address to,
        uint256 amount
    )
        external
        override
        whenNotPaused
        nonReentrant
        onlyRole(MINTER_ROLE)
    {
        if (maxMintPerTx > 0) {
            require(amount <= maxMintPerTx, "mint too large");
        }

        if (allowanceEnabled) {
            uint256 allowance = mintAllowance[msg.sender];
            require(allowance >= amount, "mint allowance exceeded");
            mintAllowance[msg.sender] = allowance - amount;
        }

        if (mintWindowSize > 0 && mintMaxPerWindow > 0) {
            uint256 start = mintWindowStart;
            if (start == 0 || block.timestamp >= start + mintWindowSize) {
                mintWindowStart = block.timestamp;
                mintedInWindow = 0;
            }
            uint256 newTotal = mintedInWindow + amount;
            require(newTotal <= mintMaxPerWindow, "mint window exceeded");
            mintedInWindow = newTotal;
        }

        ody.mint(to, amount);
        emit Minted(msg.sender, to, amount);
    }

    /**
     * @notice Burn caller's ODY
     * @dev Mirrors ARKMinter semantics: not blocked by pause so users can burn while paused
     *
     * Caller must approve this contract first.
     */
    function burn(uint256 amount) external override {
        ody.burnFrom(msg.sender, amount);
        emit Burned(msg.sender, amount);
    }

    /**
     * @notice Update underlying ODY token address
     * @dev
     * - ADMIN_ROLE only;
     * - Keeps ARKMinter-like flexibility to retarget;
     * - Value lives in token; this is just a minting proxy pointer.
     */
    function setOdyToken(IODYToken _ody)
        external
        onlyRole(ADMIN_ROLE)
    {
        if (address(_ody) == address(0)) {
            revert OdyTokenIsZeroAddress();
        }

        ody = _ody;
        emit OdyTokenChanged(address(_ody));
    }

    /**
     * @notice Set max mint per tx (0 = unlimited)
     * @dev ADMIN_ROLE only
     */
    function setMaxMintPerTx(uint256 newMax) external onlyRole(ADMIN_ROLE) {
        maxMintPerTx = newMax;
        emit MaxMintPerTxUpdated(newMax);
    }

    /**
     * @notice Enable/disable per-minter allowance enforcement
     * @dev ADMIN_ROLE only
     */
    function setAllowanceEnabled(bool enabled) external onlyRole(ADMIN_ROLE) {
        allowanceEnabled = enabled;
        emit AllowanceEnabledUpdated(enabled);
    }

    /**
     * @notice Set remaining mint allowance for a minter
     * @dev ADMIN_ROLE only
     */
    function setMintAllowance(address minter, uint256 allowance) external onlyRole(ADMIN_ROLE) {
        require(minter != address(0), "minter zero");
        mintAllowance[minter] = allowance;
        emit MintAllowanceUpdated(minter, allowance);
    }

    /**
     * @notice Set mint window limit (0 disables)
     * @dev ADMIN_ROLE only
     */
    function setMintWindow(uint256 windowSize, uint256 maxPerWindow) external onlyRole(ADMIN_ROLE) {
        mintWindowSize = windowSize;
        mintMaxPerWindow = maxPerWindow;
        if (windowSize == 0 || maxPerWindow == 0) {
            mintWindowStart = 0;
            mintedInWindow = 0;
        }
        emit MintWindowUpdated(windowSize, maxPerWindow);
    }

    /**
     * @notice Pause minting
     * @dev ADMIN_ROLE only
     */
    function pauseMinter() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    /**
     * @notice Unpause minting
     * @dev ADMIN_ROLE only
     */
    function unpauseMinter() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /**
     * @notice Current underlying token address (implements IODYMinter)
     */
    function underlyingToken() external view override returns (address) {
        return address(ody);
    }

    // =========================
    //        ERC165 support
    // =========================

    /**
     * @dev ERC165 interface support
     * - Declares IODYMinter
     * - Keeps AccessControl / ERC165Upgradeable parents
     */
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControlUpgradeable, ERC165Upgradeable)
        returns (bool)
    {
        return
            interfaceId == type(IODYMinter).interfaceId ||
            super.supportsInterface(interfaceId);
    }
}
