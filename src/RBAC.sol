// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "openzeppelin-contracts/contracts/access/AccessControl.sol";

contract RBAC is AccessControl {

    bytes32 public constant VERIFIED_VOTER = keccak256("VERIFIED_VOTER_ROLE");
    bytes32 public constant ADMIN = keccak256("ADMIN_ROLE");
    bytes32 public constant AUTHORIZED_CALLER =
        keccak256("AUTHORIZED_CALLER_ROLE");

    constructor() {
        _grantRole(ADMIN, 0x45586259E1816AC7784Ae83e704eD354689081b1);
        _setRoleAdmin(VERIFIED_VOTER, ADMIN);
        _setRoleAdmin(AUTHORIZED_CALLER, ADMIN);
        _grantRole(VERIFIED_VOTER, 0x45586259E1816AC7784Ae83e704eD354689081b1);
        // _grantRole(
        //     AUTHORIZED_CALLER, 0x45586259E1816AC7784Ae83e704eD354689081b1
        // );
    }

    function onlyVerifiedVoter() public view {
        _checkRole(VERIFIED_VOTER);
    }

    function onlyVerifiedAddr(address voter) public view {
        _checkRole(VERIFIED_VOTER, voter);
    }

    function onlyAuthorizedCaller(address caller) public view {
        _checkRole(AUTHORIZED_CALLER, caller);
    }

    function onlyAdmin(address account) public view {
        _checkRole(ADMIN, account);
    }

    function grantRole(bytes32 role, address account) public override {
        _checkRole(ADMIN, msg.sender);
        _grantRole(role, account);
    }

    function revokeRole(bytes32 role, address account) public override {
        _checkRole(ADMIN, msg.sender);
        _revokeRole(role, account);
    }

    function verifyVoter(address voter) external {
        onlyAuthorizedCaller(msg.sender);
        _grantRole(VERIFIED_VOTER, voter);
    }

    function isVoterVerified(address voter) external view returns (bool) {
        return hasRole(VERIFIED_VOTER, voter);
    }

}
