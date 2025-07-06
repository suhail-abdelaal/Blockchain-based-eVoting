// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

/**
 * @title IAccessControlManager
 * @author Suhail Abdelaal
 * @notice Interface for managing role-based access control
 * @dev Defines core functionality for managing roles and permissions
 */
interface IAccessControlManager {

    /**
     * @notice Checks if the account has admin privileges
     * @dev Reverts if the account is not an admin
     * @param account Address to check
     */
    function onlyAdmin(address account) external view;

    /**
     * @notice Checks if the caller is a verified voter
     * @dev Reverts if the caller is not a verified voter
     */
    function onlyVerifiedVoter() external view;

    /**
     * @notice Checks if a specific address is a verified voter
     * @dev Reverts if the address is not a verified voter
     * @param voter Address to check
     */
    function onlyVerifiedAddr(address voter) external view;

    /**
     * @notice Checks if a caller is authorized to perform operations
     * @dev Reverts if the caller is not authorized
     * @param caller Address to check
     */
    function onlyAuthorizedCaller(address caller) external view;

    /**
     * @notice Checks if an account has a specific role
     * @param role Role identifier
     * @param account Address to check
     * @return True if the account has the role
     */
    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);

    /**
     * @notice Grants a role to an account
     * @dev Only authorized callers can grant roles
     * @param role Role identifier
     * @param account Address to grant the role to
     */
    function grantRole(bytes32 role, address account) external;

    /**
     * @notice Revokes a role from an account
     * @dev Only authorized callers can revoke roles
     * @param role Role identifier
     * @param account Address to revoke the role from
     */
    function revokeRole(bytes32 role, address account) external;

    /**
     * @notice Verifies a voter by granting them the verified voter role
     * @dev Only authorized callers can verify voters
     * @param voter Address to verify
     */
    function verifyVoter(address voter) external;

    /**
     * @notice Checks if a voter is verified
     * @param voter Address to check
     * @return True if the voter is verified
     */
    function isVoterVerified(address voter) external view returns (bool);

    /**
     * @notice Revokes voter verification
     * @dev Only authorized callers can revoke verification
     * @param voter Address to revoke verification from
     */
    function revokeVoterVerification(address voter) external;

    /**
     * @notice Gets the admin role identifier
     * @return bytes32 Admin role identifier
     */
    function getADMIN_ROLE() external view returns (bytes32);

    /**
     * @notice Gets the verified voter role identifier
     * @return bytes32 Verified voter role identifier
     */
    function getVERIFIED_VOTER_ROLE() external view returns (bytes32);

    /**
     * @notice Gets the authorized caller role identifier
     * @return bytes32 Authorized caller role identifier
     */
    function getAUTHORIZED_CALLER_ROLE() external view returns (bytes32);
}
