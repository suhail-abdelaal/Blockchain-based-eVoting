// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IAccessControlManager.sol";

/**
 * @title AccessControlManager
 * @author Suhail Abdelaal
 * @notice Manages role-based access control for the voting system
 * @dev Implements IAccessControlManager interface and extends OpenZeppelin's AccessControl
 */
contract AccessControlManager is AccessControl, IAccessControlManager {

    // Role definitions
    bytes32 private constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 private constant VERIFIED_VOTER_ROLE = keccak256("VERIFIED_VOTER_ROLE");
    bytes32 private constant AUTHORIZED_CALLER_ROLE = keccak256("AUTHORIZED_CALLER_ROLE");
    address public admin;

    // Events
    event RoleGrantedToUser(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );
    event RoleRevokedFromUser(
        bytes32 indexed role,
        address indexed account,
        address indexed sender
    );

    /**
     * @notice Initializes the contract and sets up initial roles
     * @dev Grants all roles to the contract deployer
     */
    constructor() {
        // Grant the contract deployer the default admin role
        admin = msg.sender;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(AUTHORIZED_CALLER_ROLE, admin);
        _grantRole(VERIFIED_VOTER_ROLE, admin);
    }

    /**
     * @notice Grants a role to an account
     * @dev Only authorized callers can grant roles
     * @param role Role identifier
     * @param account Address to grant the role to
     */
    function grantRole(
        bytes32 role,
        address account
    )
        public
        override(AccessControl, IAccessControlManager)
        onlyRole(AUTHORIZED_CALLER_ROLE, msg.sender)
    {
        _grantRole(role, account);
        emit RoleGrantedToUser(role, account, msg.sender);
    }

    /**
     * @notice Revokes a role from an account
     * @dev Only authorized callers can revoke roles
     * @param role Role identifier
     * @param account Address to revoke the role from
     */
    function revokeRole(
        bytes32 role,
        address account
    )
        public
        override(AccessControl, IAccessControlManager)
        onlyRole(AUTHORIZED_CALLER_ROLE, msg.sender)
    {
        _revokeRole(role, account);
        emit RoleRevokedFromUser(role, account, msg.sender);
    }

    /**
     * @notice Checks if an account has a specific role
     * @param role Role identifier
     * @param account Address to check
     * @return bool True if the account has the role
     */
    function hasRole(
        bytes32 role,
        address account
    )
        public
        view
        override(AccessControl, IAccessControlManager)
        returns (bool)
    {
        return super.hasRole(role, account);
    }

    /**
     * @notice Checks if an account has admin privileges
     * @dev Reverts if the account is not an admin
     * @param account Address to check
     */
    function onlyAdmin(address account) external view override {
        if (!hasRole(ADMIN_ROLE, account)) {
            revert("Account does not have admin role");
        }
    }

    /**
     * @notice Checks if the caller is a verified voter
     * @dev Reverts if the caller is not a verified voter
     */
    function onlyVerifiedVoter() external view override {
        if (!hasRole(VERIFIED_VOTER_ROLE, msg.sender)) {
            revert("Caller is not a verified voter");
        }
    }

    /**
     * @notice Checks if a specific address is a verified voter
     * @dev Reverts if the address is not a verified voter
     * @param voter Address to check
     */
    function onlyVerifiedAddr(address voter) external view override {
        if (!hasRole(VERIFIED_VOTER_ROLE, voter)) {
            revert("Address is not a verified voter");
        }
    }

    /**
     * @notice Checks if a caller is authorized
     * @dev Reverts if the caller is not authorized
     * @param caller Address to check
     */
    function onlyAuthorizedCaller(address caller) external view override {
        if (!hasRole(AUTHORIZED_CALLER_ROLE, caller)) {
            revert("Caller is not authorized");
        }
    }

    /**
     * @notice Verifies a voter by granting them the verified voter role
     * @dev Only authorized callers can verify voters
     * @param voter Address to verify
     */
    function verifyVoter(address voter)
        external
        override
        onlyRole(AUTHORIZED_CALLER_ROLE, msg.sender)
    {
        grantRole(VERIFIED_VOTER_ROLE, voter);
    }

    /**
     * @notice Revokes a voter's verification
     * @dev Only authorized callers can revoke verification
     * @param voter Address to revoke verification from
     */
    function revokeVoterVerification(address voter)
        external
        override
        onlyRole(AUTHORIZED_CALLER_ROLE, msg.sender)
    {
        revokeRole(VERIFIED_VOTER_ROLE, voter);
    }

    /**
     * @notice Checks if a voter is verified
     * @param voter Address to check
     * @return bool True if the voter is verified
     */
    function isVoterVerified(address voter)
        external
        view
        override
        returns (bool)
    {
        return hasRole(VERIFIED_VOTER_ROLE, voter);
    }

    /**
     * @notice Checks if an account is an admin
     * @param account Address to check
     * @return bool True if the account has admin role
     */
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    /**
     * @notice Checks if an account is a registered voter
     * @param account Address to check
     * @return bool True if the account has voter role
     */
    function isRegisteredVoter(address account) external view returns (bool) {
        return hasRole(VERIFIED_VOTER_ROLE, account);
    }

    /**
     * @notice Registers a new voter
     * @dev Only authorized callers can register voters
     * @param voter Address to register
     */
    function registerVoter(address voter)
        external
        onlyRole(AUTHORIZED_CALLER_ROLE, msg.sender)
    {
        grantRole(VERIFIED_VOTER_ROLE, voter);
    }

    /**
     * @notice Gets the admin role identifier
     * @return bytes32 Admin role identifier
     */
    function getADMIN_ROLE() external pure override returns (bytes32) {
        return ADMIN_ROLE;
    }

    /**
     * @notice Gets the verified voter role identifier
     * @return bytes32 Verified voter role identifier
     */
    function getVERIFIED_VOTER_ROLE()
        external
        pure
        override
        returns (bytes32)
    {
        return VERIFIED_VOTER_ROLE;
    }

    /**
     * @notice Gets the authorized caller role identifier
     * @return bytes32 Authorized caller role identifier
     */
    function getAUTHORIZED_CALLER_ROLE()
        external
        pure
        override
        returns (bytes32)
    {
        return AUTHORIZED_CALLER_ROLE;
    }
}
