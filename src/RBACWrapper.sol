// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./RBAC.sol";

abstract contract RBACWrapper {
    RBAC internal rbac;

    constructor(
        address _rbac
    ) {
        rbac = RBAC(_rbac);
    }

    function getRBACaddr() public view returns (address) {
        return address(rbac);
    }

    modifier onlyAdmin(
        address admin
    ) {
        rbac.onlyAdmin(admin);
        _;
    }

    modifier onlyVerifiedVoter() {
        rbac.onlyVerifiedVoter();
        _;
    }

    modifier onlyVerifiedVoterAddr(
        address voter
    ) {
        rbac.onlyVerifiedVoterAddr(voter);
        _;
    }

    function isVoterVerified(
        address voter
    ) public view returns (bool) {
        return rbac.hasRole(rbac.VERIFIED_VOTER(), voter);
    }
}
