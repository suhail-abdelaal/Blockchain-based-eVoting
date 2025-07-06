// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IAccessControlManager.sol";

/**
 * @title AccessControlWrapper
 * @author Suhail Abdelaal
 * @notice Wrapper contract for access control functionality
 * @dev Provides modifiers and utility functions for role-based access control
 */
contract AccessControlWrapper {

    IAccessControlManager internal accessControl;

    /**
     * @notice Initializes the wrapper with an access control contract
     * @param _accessControl Address of the access control contract
     */
    constructor(address _accessControl) {
        accessControl = IAccessControlManager(_accessControl);
    }

    /**
     * @notice Modifier to restrict access to admin users
     */
    modifier onlyAdmin() {
        accessControl.onlyAdmin(msg.sender);
        _;
    }

    /**
     * @notice Modifier to restrict access to verified voters
     */
    modifier onlyVerifiedVoter() {
        accessControl.onlyVerifiedAddr(msg.sender);
        _;
    }

    /**
     * @notice Modifier to restrict access to verified addresses
     * @param voter Address to verify
     */
    modifier onlyVerifiedAddr(address voter) {
        accessControl.onlyVerifiedAddr(voter);
        _;
    }

    /**
     * @notice Modifier to restrict access to authorized callers
     * @param caller Address to check authorization
     */
    modifier onlyAuthorizedCaller(address caller) {
        accessControl.onlyAuthorizedCaller(caller);
        _;
    }

    /**
     * @notice Updates the access control contract address
     * @dev Only authorized callers can update the address
     * @param _accessControl New access control contract address
     */
    function updateAccessControl(address _accessControl)
        public
        onlyAuthorizedCaller(msg.sender)
    {
        accessControl = IAccessControlManager(_accessControl);
    }

    /**
     * @notice Checks if a voter is verified
     * @param voter Address to check
     * @return True if the voter is verified
     */
    function isVoterVerified(address voter) public view returns (bool) {
        return accessControl.isVoterVerified(voter);
    }

}
