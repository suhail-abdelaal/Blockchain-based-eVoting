// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/AccessControl.sol";

contract RoleBasedAccessControl is AccessControl {
    bytes32 public constant VERIFIED_VOTER = keccak256("VERIFIED_VOTER_ROLE");

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, 0x45586259E1816AC7784Ae83e704eD354689081b1);
    }


}
