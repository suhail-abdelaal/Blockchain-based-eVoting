// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IAccessControlManager.sol";

/**
 * @title AccessControlManager
 * @dev Manages role-based access control for the voting system
 * Implements IAccessControlManager interface and extends OpenZeppelin's
 * AccessControl
 */
contract AccessControlManager is AccessControl, IAccessControlManager {

    // Role definitions
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant VERIFIED_VOTER = keccak256("VERIFIED_VOTER");
    bytes32 public constant AUTHORIZED_CALLER = keccak256("AUTHORIZED_CALLER");
    address public admin;
    // Events

    event RoleGrantedToUser(
        bytes32 indexed role, address indexed account, address indexed sender
    );
    event RoleRevokedFromUser(
        bytes32 indexed role, address indexed account, address indexed sender
    );

    constructor() {
        // Grant the contract deployer the default admin role
        admin = msg.sender;
        _grantRole(DEFAULT_ADMIN_ROLE, admin);
        _grantRole(ADMIN_ROLE, admin);
        _grantRole(AUTHORIZED_CALLER, admin);
        _grantRole(VERIFIED_VOTER, admin);
    }

    /**
     * @dev Grant a role to an account
     * @param role The role to grant
     * @param account The account to grant the role to
     */
    function grantRole(
        bytes32 role,
        address account
    )
        public
        override(AccessControl, IAccessControlManager)
        onlyRole(AUTHORIZED_CALLER, msg.sender)
    {
        _grantRole(role, account);
        emit RoleGrantedToUser(role, account, msg.sender);
    }

    /**
     * @dev Revoke a role from an account
     * @param role The role to revoke
     * @param account The account to revoke the role from
     */
    function revokeRole(
        bytes32 role,
        address account
    )
        public
        override(AccessControl, IAccessControlManager)
        onlyRole(AUTHORIZED_CALLER, msg.sender)
    {
        _revokeRole(role, account);
        emit RoleRevokedFromUser(role, account, msg.sender);
    }

    /**
     * @dev Check if an account has a specific role
     * @param role The role to check
     * @param account The account to check
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
     * @dev Check if caller is an admin (modifier-like function)
     */
    function onlyAdmin(address account) external view override {
        if (!hasRole(ADMIN_ROLE, account)) {
            revert("AccessControl: account does not have admin role");
        }
    }

    /**
     * @dev Check if caller is a verified voter (modifier-like function)
     */
    function onlyVerifiedVoter() external view override {
        if (!hasRole(VERIFIED_VOTER, msg.sender)) {
            revert("AccessControl: caller is not a verified voter");
        }
    }

    /**
     * @dev Check if specific address is a verified voter (modifier-like
     * function)
     */
    function onlyVerifiedAddr(address voter) external view override {
        if (!hasRole(VERIFIED_VOTER, voter)) {
            revert("AccessControl: address is not a verified voter");
        }
    }

    /**
     * @dev Check if caller is authorized (modifier-like function)
     */
    function onlyAuthorizedCaller(address caller) external view override {
        if (!hasRole(AUTHORIZED_CALLER, caller)) {
            revert("AccessControl: caller is not authorized");
        }
    }

    /**
     * @dev Verify a voter (admin only) - alias for registerVoter
     * @param voter The address to verify as a voter
     */
    function verifyVoter(address voter)
        external
        override
        onlyRole(AUTHORIZED_CALLER, msg.sender)
    {
        grantRole(VERIFIED_VOTER, voter);
    }

    /**
     * @dev Check if a voter is verified
     * @param voter The address to check
     * @return bool True if the voter is verified
     */
    function isVoterVerified(address voter)
        external
        view
        override
        returns (bool)
    {
        return hasRole(VERIFIED_VOTER, voter);
    }

    /**
     * @dev Check if caller is an admin
     * @return bool True if caller has admin role
     */
    function isAdmin(address account) external view returns (bool) {
        return hasRole(ADMIN_ROLE, account);
    }

    /**
     * @dev Check if caller is a registered voter
     * @return bool True if caller has voter role
     */
    function isRegisteredVoter(address account) external view returns (bool) {
        return hasRole(VERIFIED_VOTER, account);
    }

    /**
     * @dev Register a new voter (admin only)
     * @param voter The address to register as a voter
     */
    function registerVoter(address voter)
        external
        onlyRole(AUTHORIZED_CALLER, msg.sender)
    {
        grantRole(VERIFIED_VOTER, voter);
    }

    /**
     * @dev Unregister a voter (admin only)
     * @param voter The address to unregister
     */
    function unregisterVoter(address voter)
        external
        onlyRole(AUTHORIZED_CALLER, msg.sender)
    {
        revokeRole(VERIFIED_VOTER, voter);
    }

}
