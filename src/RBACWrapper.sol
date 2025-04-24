// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {IRBAC} from "./interfaces/IRBAC.sol";

abstract contract RBACWrapper {

    IRBAC internal rbac;

    constructor(address _rbac) {
        rbac = IRBAC(_rbac);
    }

    modifier onlyAdmin() {
        rbac.onlyAdmin();
        _;
    }

    modifier onlyVerifiedVoter() {
        rbac.onlyVerifiedVoter();
        _;
    }

    modifier onlyVerifiedAddr(address voter) {
        rbac.onlyVerifiedAddr(voter);
        _;
    }

    modifier onlyAuthorizedCaller(address caller) {
        rbac.onlyAuthorizedCaller(caller);
        _;
    }

    function isVoterVerified(address voter) public view returns (bool) {
        return rbac.isVoterVerified(voter);
    }

}
