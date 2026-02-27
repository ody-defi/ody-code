// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/Pausable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import {LeaderboardPoolDeps} from "./LeaderboardPoolDeps.sol";
import {LeaderboardPoolTypes} from "./LeaderboardPoolTypes.sol";
import {LeaderboardPoolEvents} from "./LeaderboardPoolEvents.sol";

/**
 * @title LeaderboardPool
 * @notice Custodies USDT and lets users claim rewards via off-chain signatures (maxClaimable + nonce + deadline).
 *         Deploy the same bytecode twice for:
 *         - Community leaderboard pool
 *         - Co-founder leaderboard pool
 */
contract LeaderboardPool is AccessControl, Pausable, ReentrancyGuard, LeaderboardPoolEvents {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IERC20;
    using ECDSA for bytes32;

    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant SIGNER_ROLE = keccak256("SIGNER_ROLE");

    // EIP-712
    string private constant EIP712_NAME = "LeaderboardPool";
    string private constant EIP712_VERSION = "1";
    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant CLAIM_TYPEHASH =
        keccak256(
            "Claim(address to,uint256 amount,uint256 maxClaimable,uint256 nonce,uint256 deadline,bytes32 requestId)"
        );

    IERC20Metadata public immutable usdt;

    mapping(address => uint256) public claimedByUser;
    mapping(address => uint256) public noncesByUser;

    constructor(address usdt_, address admin_, address initSigner_) {
        require(usdt_ != address(0), "LB: usdt zero");
        require(admin_ != address(0), "LB: admin zero");

        usdt = IERC20Metadata(usdt_);

        _grantRole(DEFAULT_ADMIN_ROLE, admin_);
        _grantRole(ADMIN_ROLE, admin_);

        if (initSigner_ != address(0)) {
            _grantRole(SIGNER_ROLE, initSigner_);
            emit SignerUpdated(initSigner_, true);
        }
    }

    function poolBalance() external view returns (uint256) {
        return usdt.balanceOf(address(this));
    }

    function claim(LeaderboardPoolTypes.ClaimRequest calldata req, bytes calldata signature)
        external
        whenNotPaused
        nonReentrant
    {
        _claim(req, signature);
    }

    function claimBatch(LeaderboardPoolTypes.ClaimRequest[] calldata reqs, bytes[] calldata signatures)
        external
        whenNotPaused
        nonReentrant
    {
        require(reqs.length == signatures.length, "LB: length mismatch");
        uint256 len = reqs.length;
        for (uint256 i; i < len; i++) {
            _claim(reqs[i], signatures[i]);
        }
    }

    // -----------------------
    // Admin
    // -----------------------

    function setSigner(address signer, bool allowed) external onlyRole(ADMIN_ROLE) {
        require(signer != address(0), "LB: signer zero");
        if (allowed) {
            _grantRole(SIGNER_ROLE, signer);
        } else {
            _revokeRole(SIGNER_ROLE, signer);
        }
        emit SignerUpdated(signer, allowed);
    }

    function pause() external onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    /// @notice Rescue tokens accidentally sent to this contract (USDT cannot be rescued).
    function rescueToken(address token, address to, uint256 amount) external onlyRole(ADMIN_ROLE) nonReentrant {
        require(token != address(usdt), "LB: cannot rescue USDT");
        require(token != address(0), "LB: token zero");
        require(to != address(0), "LB: to zero");
        require(amount > 0, "LB: amount zero");
        IERC20Metadata(token).safeTransfer(to, amount);
        emit TokenRescued(token, to, amount);
    }

    /**
     * @notice Use this contract's USDT balance to buy a token via a router swap.
     * @dev
     * - Only ADMIN_ROLE
     * - Tokens are bought directly to the admin caller (msg.sender).
     * - `path` must start with USDT.
     */
    function buyTokenWithUsdt(
        address router,
        uint256 usdtIn,
        uint256 minTokenOut,
        address[] calldata path,
        uint256 deadline
    ) external onlyRole(ADMIN_ROLE) whenNotPaused nonReentrant {
        require(router != address(0), "LB: router zero");
        require(usdtIn > 0, "LB: usdtIn zero");
        require(deadline >= block.timestamp, "LB: deadline past");
        require(path.length >= 2, "LB: path too short");
        require(path[0] == address(usdt), "LB: path must start with USDT");
        require(path[path.length - 1] != address(0), "LB: tokenOut zero");

        uint256 bal = usdt.balanceOf(address(this));
        require(usdtIn <= bal, "LB: insufficient USDT");

        IERC20(address(usdt)).forceApprove(router, usdtIn);
        LeaderboardPoolDeps.IRouterSwap(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            usdtIn,
            minTokenOut,
            path,
            msg.sender,
            deadline
        );

        emit TokenPurchased(msg.sender, msg.sender, router, path[path.length - 1], usdtIn, minTokenOut, path);
    }

    receive() external payable {
        revert("LB: no native");
    }

    fallback() external payable {
        revert("LB: no native");
    }

    // -----------------------
    // EIP-712 helpers
    // -----------------------

    function _claim(LeaderboardPoolTypes.ClaimRequest calldata req, bytes calldata signature) internal {
        require(req.to == msg.sender, "LB: only self claim");
        require(req.amount > 0, "LB: amount zero");
        require(req.requestId != bytes32(0), "LB: requestId zero");
        require(block.timestamp <= req.deadline, "LB: expired");

        uint256 nonce = noncesByUser[msg.sender];
        require(req.nonce == nonce, "LB: bad nonce");

        uint256 claimed = claimedByUser[msg.sender];
        require(claimed + req.amount <= req.maxClaimable, "LB: exceed maxClaimable");

        address signer = _recoverClaimSigner(req, signature);
        require(hasRole(SIGNER_ROLE, signer), "LB: signer not allowed");

        claimedByUser[msg.sender] = claimed + req.amount;
        noncesByUser[msg.sender] = nonce + 1;

        usdt.safeTransfer(req.to, req.amount);

        emit Claimed(req.to, req.requestId, req.amount, req.maxClaimable, req.nonce, signer);
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

    function _recoverClaimSigner(LeaderboardPoolTypes.ClaimRequest calldata req, bytes calldata signature)
        internal
        view
        returns (address)
    {
        require(signature.length == 65, "LB: bad sig");
        bytes32 structHash = keccak256(
            abi.encode(
                CLAIM_TYPEHASH,
                req.to,
                req.amount,
                req.maxClaimable,
                req.nonce,
                req.deadline,
                req.requestId
            )
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", _domainSeparator(), structHash));
        return digest.recover(signature);
    }
}
