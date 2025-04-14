// SPDX-License-Identifier: MIT

pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract RBAC is AccessControl {
    bytes32 public constant VERIFIED_VOTER = keccak256("VERIFIED_VOTER_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, 0x45586259E1816AC7784Ae83e704eD354689081b1);
    }

    modifier onlyVerifiedVoter() {
        _checkRole(VERIFIED_VOTER);
        _;
    }

    modifier onlyVerifiedVoterAddr(address _voter) {
        _checkRole(VERIFIED_VOTER, _voter);
        _;
    }

    modifier onlyAdmin() {
        _checkRole(DEFAULT_ADMIN_ROLE);
        _;
    }

    function grantRole(bytes32 role, address account) public override onlyAdmin {
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public override onlyAdmin {
        _revokeRole(role, account);
    }

    function _verifyVoter(address _voter) internal {
        grantRole(VERIFIED_VOTER, _voter);
    }

    function isVoterVerified(address _voter) public view returns(bool) {
        return hasRole(VERIFIED_VOTER, _voter);
    }


}
