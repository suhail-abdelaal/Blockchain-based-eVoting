// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {AccessControlManager} from "../../src/access/AccessControlManager.sol";

contract AccessControlTest is Test {

    AccessControlManager public accessControl;
    address public admin = 0x45586259E1816AC7784Ae83e704eD354689081b1;
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    function setUp() public {
        vm.prank(admin);
        accessControl = new AccessControlManager();
        vm.deal(admin, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
    }

    function test_InitialRoles() public {
        assertTrue(
            accessControl.hasRole(accessControl.getADMIN_ROLE(), admin),
            "Admin should have ADMIN role"
        );
        assertTrue(
            accessControl.hasRole(accessControl.getVERIFIED_VOTER_ROLE(), admin),
            "Admin should have VERIFIED_VOTER role"
        );
        assertFalse(
            accessControl.hasRole(accessControl.getVERIFIED_VOTER_ROLE(), user1),
            "User1 should not have VERIFIED_VOTER role initially"
        );
    }

    function test_GrantRole() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.getVERIFIED_VOTER_ROLE(), user1);
        vm.stopPrank();

        assertTrue(
            accessControl.hasRole(accessControl.getVERIFIED_VOTER_ROLE(), user1),
            "User1 should have VERIFIED_VOTER role after granting"
        );
    }

    function test_RevokeRole() public {
        vm.startPrank(admin);
        accessControl.grantRole(accessControl.getVERIFIED_VOTER_ROLE(), user1);

        accessControl.revokeRole(accessControl.getVERIFIED_VOTER_ROLE(), user1);
        vm.stopPrank();

        assertFalse(
            accessControl.hasRole(accessControl.getVERIFIED_VOTER_ROLE(), user1),
            "User1 should not have VERIFIED_VOTER role after revoking"
        );
    }

    function test_VerifyVoter() public {
        vm.startPrank(admin);
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(), address(this)
        );
        vm.stopPrank();

        accessControl.verifyVoter(user1);

        assertTrue(
            accessControl.hasRole(accessControl.getVERIFIED_VOTER_ROLE(), user1),
            "User1 should be verified after calling verifyVoter"
        );
    }

    function test_IsVoterVerified() public {
        assertTrue(
            accessControl.isVoterVerified(admin), "Admin should be verified"
        );
        assertFalse(
            accessControl.isVoterVerified(user1),
            "User1 should not be verified initially"
        );

        vm.startPrank(admin);
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(), address(this)
        );
        vm.stopPrank();

        accessControl.verifyVoter(user1);

        assertTrue(
            accessControl.isVoterVerified(user1),
            "User1 should be verified after verification"
        );
    }

    function test_OnlyAuthorizedCallerCanGrantRole() public {
        vm.startPrank(user1);
        console.log("user1", user1);
        bytes32 role = accessControl.getVERIFIED_VOTER_ROLE();
        vm.expectRevert();
        accessControl.grantRole(role, user2);
        vm.stopPrank();
    }

    function test_OnlyAuthorizedCallerCanRevokeRole() public {
        vm.startPrank(admin);
        bytes32 role = accessControl.getVERIFIED_VOTER_ROLE();
        accessControl.grantRole(role, user1);
        vm.stopPrank();

        vm.startPrank(user1);
        vm.expectRevert();
        accessControl.revokeRole(role, user2);
        vm.stopPrank();
    }

    function test_OnlyAuthorizedCallerCanVerifyVoter() public {
        vm.expectRevert();
        accessControl.verifyVoter(user1);
    }

}
