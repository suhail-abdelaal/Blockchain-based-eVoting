// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {ProposalState} from "../../src/proposal/ProposalState.sol";
import {AccessControlManager} from "../../src/access/AccessControlManager.sol";
import {IProposalState} from "../../src/interfaces/IProposalState.sol";

contract ProposalStateTest is Test {

    ProposalState public proposalState;
    AccessControlManager public accessControl;
    address public admin = 0x45586259E1816AC7784Ae83e704eD354689081b1;
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    function setUp() public {
        vm.prank(admin);
        accessControl = new AccessControlManager();
        proposalState = new ProposalState(address(accessControl));

        vm.deal(admin, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);

        vm.startPrank(admin);
        accessControl.grantRole(
            accessControl.AUTHORIZED_CALLER(), address(this)
        );
        vm.stopPrank();
    }

    function test_CreateProposal() public {
        string[] memory options = new string[](3);
        options[0] = "Option A";
        options[1] = "Option B";
        options[2] = "Option C";

        uint256 proposalId = proposalState.createProposal(
            user1,
            "Test Proposal",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        assertEq(proposalId, 1, "First proposal should have ID 1");
        assertEq(
            uint256(proposalState.getProposalStatus(1)),
            uint256(IProposalState.ProposalStatus.PENDING),
            "New proposal should be PENDING"
        );
        assertEq(
            uint256(proposalState.getProposalVoteMutability(1)),
            uint256(IProposalState.VoteMutability.MUTABLE),
            "Proposal should be MUTABLE by default"
        );
    }

    function test_UpdateProposalStatus() public {
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        proposalState.createProposal(
            user1,
            "Test Proposal",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        // Should still be PENDING before start time
        proposalState.updateProposalStatus(1);
        assertEq(
            uint256(proposalState.getProposalStatus(1)),
            uint256(IProposalState.ProposalStatus.PENDING),
            "Should still be PENDING before start time"
        );

        // Should become ACTIVE after start time
        vm.warp(block.timestamp + 1 days);
        proposalState.updateProposalStatus(1);
        assertEq(
            uint256(proposalState.getProposalStatus(1)),
            uint256(IProposalState.ProposalStatus.ACTIVE),
            "Should be ACTIVE after start time"
        );

        // Should become CLOSED after end time
        vm.warp(block.timestamp + 10 days);
        proposalState.updateProposalStatus(1);
        assertEq(
            uint256(proposalState.getProposalStatus(1)),
            uint256(IProposalState.ProposalStatus.CLOSED),
            "Should be CLOSED after end time"
        );
    }

    function test_IsProposalActive() public {
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        proposalState.createProposal(
            user1,
            "Test Proposal",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        assertFalse(
            proposalState.isProposalActive(1),
            "Should not be active before start time"
        );

        vm.warp(block.timestamp + 1 days);
        proposalState.updateProposalStatus(1);
        assertTrue(
            proposalState.isProposalActive(1),
            "Should be active after start time"
        );

        vm.warp(block.timestamp + 10 days);
        proposalState.updateProposalStatus(1);
        assertFalse(
            proposalState.isProposalActive(1),
            "Should not be active after end time"
        );
    }

    function test_IsProposalClosed() public {
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        proposalState.createProposal(
            user1,
            "Test Proposal",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        assertFalse(
            proposalState.isProposalClosed(1),
            "Should not be closed before end time"
        );

        vm.warp(block.timestamp + 10 days);
        proposalState.updateProposalStatus(1);
        assertTrue(
            proposalState.isProposalClosed(1), "Should be closed after end time"
        );
    }

    function test_AddAndRemoveParticipant() public {
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        proposalState.createProposal(
            user1,
            "Test Proposal",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        assertFalse(
            proposalState.isParticipant(1, user2),
            "User2 should not be participant initially"
        );
        assertEq(
            proposalState.getParticipantCount(1),
            0,
            "Should have 0 participants initially"
        );

        proposalState.addParticipant(1, user2);
        assertTrue(
            proposalState.isParticipant(1, user2),
            "User2 should be participant after adding"
        );
        assertEq(
            proposalState.getParticipantCount(1),
            1,
            "Should have 1 participant after adding"
        );

        proposalState.removeParticipant(1, user2);
        assertFalse(
            proposalState.isParticipant(1, user2),
            "User2 should not be participant after removing"
        );
        assertEq(
            proposalState.getParticipantCount(1),
            0,
            "Should have 0 participants after removing"
        );
    }

    function test_OptionExists() public {
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        proposalState.createProposal(
            user1,
            "Test Proposal",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        assertTrue(
            proposalState.optionExists(1, "Yes"), "Yes option should exist"
        );
        assertTrue(
            proposalState.optionExists(1, "No"), "No option should exist"
        );
        assertFalse(
            proposalState.optionExists(1, "Maybe"),
            "Maybe option should not exist"
        );
    }

    function test_GetProposalOptions() public {
        string[] memory options = new string[](3);
        options[0] = "Option A";
        options[1] = "Option B";
        options[2] = "Option C";

        proposalState.createProposal(
            user1,
            "Test Proposal",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        string[] memory retrievedOptions = proposalState.getProposalOptions(1);
        assertEq(retrievedOptions.length, 3, "Should have 3 options");
        assertEq(
            retrievedOptions[0], "Option A", "First option should be Option A"
        );
        assertEq(
            retrievedOptions[1], "Option B", "Second option should be Option B"
        );
        assertEq(
            retrievedOptions[2], "Option C", "Third option should be Option C"
        );
    }

}
