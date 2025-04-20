// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract RBAC is AccessControl {
    bytes32 public constant VERIFIED_VOTER = keccak256("VERIFIED_VOTER_ROLE");
    bytes32 public constant ADMIN = keccak256("ADMIN_ROLE");

    constructor() {
        _grantRole(ADMIN, 0x45586259E1816AC7784Ae83e704eD354689081b1);
        _setRoleAdmin(VERIFIED_VOTER, ADMIN);
        _grantRole(VERIFIED_VOTER, 0x45586259E1816AC7784Ae83e704eD354689081b1);
    }

    function onlyVerifiedVoter() public view {
        _checkRole(VERIFIED_VOTER);
    }

    function onlyVerifiedAddr(
        address _voter
    ) public view {
        _checkRole(VERIFIED_VOTER, _voter);
    }

    function onlyAdmin(
        address admin
    ) public view {
        _checkRole(ADMIN, admin);
    }

    function grantRole(bytes32 role, address account, address admin) external {
        onlyAdmin(admin);
        _grantRole(role, account);
    }

    function revokeRole(
        bytes32 role,
        address account,
        address admin
    ) external {
        onlyAdmin(admin);
        _revokeRole(role, account);
    }

    function verifyVoter(address voter, address admin) external {
        onlyAdmin(admin);
        _grantRole(VERIFIED_VOTER, voter);
    }

    function isVoterVerified(
        address voter
    ) public view returns (bool) {
        return hasRole(VERIFIED_VOTER, voter);
    }
}
