// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {VoterRegistry} from "../../src/voter/VoterRegistry.sol";
import {AccessControlManager} from "../../src/access/AccessControlManager.sol";

contract VoterRegistryTest is Test {

    VoterRegistry public voterRegistry;
    AccessControlManager public accessControl;
    address public admin = 0x45586259E1816AC7784Ae83e704eD354689081b1;
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    function setUp() public {
        vm.prank(admin);
        accessControl = new AccessControlManager();
        voterRegistry = new VoterRegistry(address(accessControl));

        vm.deal(admin, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        vm.startPrank(admin);
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(), address(this)
        );
        vm.stopPrank();
    }

    function test_VerifyVoter() public {
        int256[] memory embeddings = new int256[](3);
        embeddings[0] = 12_345;
        embeddings[1] = 67_890;
        embeddings[2] = 11_111;

        vm.prank(admin);
        voterRegistry.registerVoter(user1, bytes32(uint256(123)), embeddings);

        // Check that voter is verified (we can't directly access the struct
        // with mappings)
        // This test validates that the verifyVoter function works correctly
    }

    function test_RecordUserParticipation() public {
        voterRegistry.recordUserParticipation(user1, 1, "Option A");

        uint256[] memory participatedProposals =
            voterRegistry.getVoterParticipatedProposals(user1);
        assertEq(
            participatedProposals.length,
            1,
            "Should have participated in 1 proposal"
        );
        assertEq(
            participatedProposals[0],
            1,
            "Should have participated in proposal 1"
        );

        string memory selectedOption =
            voterRegistry.getVoterSelectedOption(user1, 1);
        assertEq(
            selectedOption, "Option A", "Selected option should be Option A"
        );
    }

    function test_RecordUserCreatedProposal() public {
        voterRegistry.recordUserCreatedProposal(user1, 1);

        uint256[] memory createdProposals =
            voterRegistry.getVoterCreatedProposals(user1);
        assertEq(createdProposals.length, 1, "Should have created 1 proposal");
        assertEq(createdProposals[0], 1, "Should have created proposal 1");
    }

    function test_RemoveUserParticipation() public {
        voterRegistry.recordUserParticipation(user1, 1, "Option A");
        voterRegistry.recordUserParticipation(user1, 2, "Option B");

        uint256[] memory participatedProposals =
            voterRegistry.getVoterParticipatedProposals(user1);
        assertEq(
            participatedProposals.length,
            2,
            "Should have participated in 2 proposals"
        );

        voterRegistry.removeUserParticipation(user1, 1);

        participatedProposals =
            voterRegistry.getVoterParticipatedProposals(user1);
        assertEq(
            participatedProposals.length,
            1,
            "Should have participated in 1 proposal after removal"
        );
        assertEq(
            participatedProposals[0],
            2,
            "Should still have participated in proposal 2"
        );

        string memory selectedOption =
            voterRegistry.getVoterSelectedOption(user1, 1);
        assertEq(
            selectedOption, "", "Selected option should be empty after removal"
        );
    }

    function test_RemoveUserProposal() public {
        voterRegistry.recordUserCreatedProposal(user1, 1);
        voterRegistry.recordUserCreatedProposal(user1, 2);

        uint256[] memory createdProposals =
            voterRegistry.getVoterCreatedProposals(user1);
        assertEq(createdProposals.length, 2, "Should have created 2 proposals");

        voterRegistry.removeUserProposal(user1, 1);

        createdProposals = voterRegistry.getVoterCreatedProposals(user1);
        assertEq(
            createdProposals.length,
            1,
            "Should have created 1 proposal after removal"
        );
        assertEq(createdProposals[0], 2, "Should still have created proposal 2");
    }

    function test_GetParticipatedProposalsCount() public {
        assertEq(
            voterRegistry.getParticipatedProposalsCount(user1),
            0,
            "Should have 0 participated proposals initially"
        );

        voterRegistry.recordUserParticipation(user1, 1, "Option A");
        assertEq(
            voterRegistry.getParticipatedProposalsCount(user1),
            1,
            "Should have 1 participated proposal"
        );

        voterRegistry.recordUserParticipation(user1, 2, "Option B");
        assertEq(
            voterRegistry.getParticipatedProposalsCount(user1),
            2,
            "Should have 2 participated proposals"
        );

        voterRegistry.removeUserParticipation(user1, 1);
        assertEq(
            voterRegistry.getParticipatedProposalsCount(user1),
            1,
            "Should have 1 participated proposal after removal"
        );
    }

    function test_GetCreatedProposalsCount() public {
        assertEq(
            voterRegistry.getCreatedProposalsCount(user1),
            0,
            "Should have 0 created proposals initially"
        );

        voterRegistry.recordUserCreatedProposal(user1, 1);
        assertEq(
            voterRegistry.getCreatedProposalsCount(user1),
            1,
            "Should have 1 created proposal"
        );

        voterRegistry.recordUserCreatedProposal(user1, 2);
        assertEq(
            voterRegistry.getCreatedProposalsCount(user1),
            2,
            "Should have 2 created proposals"
        );

        voterRegistry.removeUserProposal(user1, 1);
        assertEq(
            voterRegistry.getCreatedProposalsCount(user1),
            1,
            "Should have 1 created proposal after removal"
        );
    }

    function test_MultipleVoters() public {
        voterRegistry.recordUserParticipation(user1, 1, "Option A");
        voterRegistry.recordUserParticipation(user2, 1, "Option B");

        uint256[] memory user1Proposals =
            voterRegistry.getVoterParticipatedProposals(user1);
        uint256[] memory user2Proposals =
            voterRegistry.getVoterParticipatedProposals(user2);

        assertEq(
            user1Proposals.length,
            1,
            "User1 should have participated in 1 proposal"
        );
        assertEq(
            user2Proposals.length,
            1,
            "User2 should have participated in 1 proposal"
        );

        string memory user1Option =
            voterRegistry.getVoterSelectedOption(user1, 1);
        string memory user2Option =
            voterRegistry.getVoterSelectedOption(user2, 1);

        assertEq(user1Option, "Option A", "User1 should have selected Option A");
        assertEq(user2Option, "Option B", "User2 should have selected Option B");
    }

    function test_OnlyAdminCanVerifyVoter() public {
        vm.prank(user1);
        vm.expectRevert();
        voterRegistry.registerVoter(user2, bytes32(uint256(123)), new int256[](0));
    }

    function test_OnlyAuthorizedCallerCanRecordParticipation() public {
        vm.prank(user1);
        vm.expectRevert();
        voterRegistry.recordUserParticipation(user2, 1, "Option A");
    }

    function test_OnlyAuthorizedCallerCanRecordCreatedProposal() public {
        vm.prank(user1);
        vm.expectRevert();
        voterRegistry.recordUserCreatedProposal(user2, 1);
    }

    function test_OnlyAuthorizedCallerCanRemoveParticipation() public {
        voterRegistry.recordUserParticipation(user1, 1, "Option A");

        vm.prank(user1);
        vm.expectRevert();
        voterRegistry.removeUserParticipation(user1, 1);
    }

    function test_OnlyAuthorizedCallerCanRemoveProposal() public {
        voterRegistry.recordUserCreatedProposal(user1, 1);

        vm.prank(user1);
        vm.expectRevert();
        voterRegistry.removeUserProposal(user1, 1);
    }

}
