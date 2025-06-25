// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../interfaces/IAccessControlManager.sol";

contract AccessControlWrapper {

    IAccessControlManager internal accessControl;

    constructor(address _accessControl) {
        accessControl = IAccessControlManager(_accessControl);
    }

    modifier onlyAdmin() {
        accessControl.onlyAdmin(msg.sender);
        _;
    }

    modifier onlyVerifiedVoter() {
        accessControl.onlyVerifiedAddr(msg.sender);
        _;
    }

    modifier onlyVerifiedAddr(address voter) {
        accessControl.onlyVerifiedAddr(voter);
        _;
    }

    modifier onlyAuthorizedCaller(address caller) {
        accessControl.onlyAuthorizedCaller(caller);
        _;
    }

    function updateAccessControl(address _accessControl) public onlyAuthorizedCaller(msg.sender) {
        accessControl = IAccessControlManager(_accessControl);
    }

    function isVoterVerified(address voter) public view returns (bool) {
        return accessControl.isVoterVerified(voter);
    }

}
