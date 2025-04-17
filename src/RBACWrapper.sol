// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "./RBAC.sol";

abstract contract RBACWrapper {
    RBAC public rbac;

    constructor(
        address _rbac
    ) {
        rbac = RBAC(_rbac);
    }

    function getRBACaddr() public view returns (address) {
        return address(rbac);
    }

    modifier onlyAdmin() {
        rbac.onlyAdmin();
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

    // function grantRole(bytes32 role, address account) public onlyAdmin {
    //     rbac.grantRole(role, account);
    // }

    // function revokeRole(bytes32 role, address account) public onlyAdmin {
    //     rbac.revokeRole(role, account);
    // }

    // function _verifyVoter(address voter) internal {
    //     rbac.grantRole(rbac.VERIFIED_VOTER(), voter);
    // }

    function isVoterVerified(
        address voter
    ) public view returns (bool) {
        return rbac.hasRole(rbac.VERIFIED_VOTER(), voter);
    }
}
