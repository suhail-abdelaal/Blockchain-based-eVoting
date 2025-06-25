// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {VotingFacade} from "../../src/VotingFacade.sol";
import {AccessControlManager} from "../../src/access/AccessControlManager.sol";
import {VoterRegistry} from "../../src/voter/VoterRegistry.sol";
import {ProposalOrchestrator} from "../../src/proposal/ProposalOrchestrator.sol";
import {ProposalState} from "../../src/proposal/ProposalState.sol";
import {VoteTallying} from "../../src/voting/VoteTallying.sol";
import {ProposalValidator} from "../../src/validation/ProposalValidator.sol";
import {IProposalState} from "../../src/interfaces/IProposalState.sol";

contract VotingSystemTest is Test {

    VotingFacade public votingSystem;
    AccessControlManager public accessControl;
    VoterRegistry public voterRegistry;
    ProposalOrchestrator public proposalOrchestrator;
    ProposalState public proposalState;
    VoteTallying public voteTallying;
    ProposalValidator public proposalValidator;

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public admin = 0x45586259E1816AC7784Ae83e704eD354689081b1;

    function setUp() public {
        // Deploy the refactored system
        vm.prank(admin);

        accessControl = new AccessControlManager();
        proposalState = new ProposalState(address(accessControl));
        voteTallying =
            new VoteTallying(address(accessControl), address(proposalState));
        voterRegistry = new VoterRegistry(address(accessControl));
        proposalValidator = new ProposalValidator(
            address(accessControl), address(proposalState)
        );

        proposalOrchestrator = new ProposalOrchestrator(
            address(accessControl),
            address(proposalValidator),
            address(proposalState),
            address(voteTallying),
            address(voterRegistry)
        );

        votingSystem = new VotingFacade(
            address(accessControl),
            address(voterRegistry),
            address(proposalOrchestrator)
        );

        vm.deal(admin, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);

        // Grant necessary roles using proper access control
        vm.startPrank(admin);
        accessControl.grantRole(
            accessControl.AUTHORIZED_CALLER(), address(this)
        );
        accessControl.grantRole(
            accessControl.AUTHORIZED_CALLER(), address(proposalOrchestrator)
        );
        accessControl.grantRole(
            accessControl.AUTHORIZED_CALLER(), address(voterRegistry)
        );
        accessControl.grantRole(
            accessControl.AUTHORIZED_CALLER(), address(votingSystem)
        );
        accessControl.grantRole(
            accessControl.AUTHORIZED_CALLER(), address(proposalState)
        );
        accessControl.grantRole(
            accessControl.AUTHORIZED_CALLER(), address(voteTallying)
        );
        // Grant admin role to VotingFacade so it can call admin functions on
        // behalf of users
        accessControl.grantRole(
            accessControl.ADMIN_ROLE(), address(votingSystem)
        );
        // Grant admin role to test contract so it can call admin functions
        accessControl.grantRole(accessControl.ADMIN_ROLE(), address(this));
        vm.stopPrank();

        // Register voters using the admin
        vm.startPrank(admin);
        votingSystem.registerVoter(address(this), 1, new int256[](0));
        votingSystem.registerVoter(user1, 2, new int256[](0));
        votingSystem.registerVoter(user2, 3, new int256[](0));
        votingSystem.registerVoter(user3, 4, new int256[](0));
        // Also grant verified voter roles directly to ensure they can create
        // proposals
        accessControl.grantRole(accessControl.VERIFIED_VOTER(), address(this));
        accessControl.grantRole(accessControl.VERIFIED_VOTER(), user1);
        accessControl.grantRole(accessControl.VERIFIED_VOTER(), user2);
        accessControl.grantRole(accessControl.VERIFIED_VOTER(), user3);
        vm.stopPrank();
    }

    function test_CompleteVotingWorkflow() public {
        // Test creating a proposal
        string[] memory options = new string[](3);
        options[0] = "Option A";
        options[1] = "Option B";
        options[2] = "Option C";

        vm.prank(user1);
        uint256 proposalId = votingSystem.createProposal(
            "Integration Test Proposal",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        assertEq(proposalId, 1, "First proposal should have ID 1");

        // Test proposal status before start
        assertEq(
            uint256(proposalState.getProposalStatus(proposalId)),
            uint256(IProposalState.ProposalStatus.PENDING),
            "Should be PENDING before start"
        );
        assertFalse(
            proposalState.isProposalActive(proposalId),
            "Should not be active before start"
        );

        // Test voting before proposal is active (should fail)
        vm.prank(user2);
        vm.expectRevert();
        votingSystem.castVote(proposalId, "Option A");

        // Move to proposal start time
        vm.warp(block.timestamp + 1 days);

        vm.prank(user2);
        votingSystem.castVote(proposalId, "Option A");

        // Test proposal status after start (should now be ACTIVE due to the
        // vote above)
        assertEq(
            uint256(proposalState.getCurrentProposalStatus(proposalId)),
            uint256(IProposalState.ProposalStatus.ACTIVE),
            "Should be ACTIVE after start"
        );
        assertTrue(
            proposalState.isProposalActive(proposalId),
            "Should be active after start"
        );

        vm.prank(user3);
        votingSystem.castVote(proposalId, "Option B");

        vm.prank(address(this));
        votingSystem.castVote(proposalId, "Option A");

        // Check vote counts
        assertEq(
            voteTallying.getVoteCount(proposalId, "Option A"),
            2,
            "Option A should have 2 votes"
        );
        assertEq(
            voteTallying.getVoteCount(proposalId, "Option B"),
            1,
            "Option B should have 1 vote"
        );
        assertEq(
            voteTallying.getVoteCount(proposalId, "Option C"),
            0,
            "Option C should have 0 votes"
        );

        // Test that voters can't vote twice
        vm.prank(user2);
        vm.expectRevert();
        votingSystem.castVote(proposalId, "Option B");

        // Test vote retraction
        vm.prank(user3);
        votingSystem.retractVote(proposalId);
        assertEq(
            voteTallying.getVoteCount(proposalId, "Option B"),
            0,
            "Option B should have 0 votes after retraction"
        );

        // Test vote change
        vm.prank(address(this));
        votingSystem.changeVote(proposalId, "Option C");
        assertEq(
            voteTallying.getVoteCount(proposalId, "Option A"),
            1,
            "Option A should have 1 vote after change"
        );
        assertEq(
            voteTallying.getVoteCount(proposalId, "Option C"),
            1,
            "Option C should have 1 vote after change"
        );

        // Move to proposal end time
        vm.warp(block.timestamp + 11 days);

        // Test proposal status after end (should be CLOSED)
        assertEq(
            uint256(proposalState.getCurrentProposalStatus(proposalId)),
            uint256(IProposalState.ProposalStatus.CLOSED),
            "Should be CLOSED after end"
        );
        assertTrue(
            proposalState.isProposalClosed(proposalId),
            "Should be closed after end"
        );

        // Test voting after proposal is closed (should fail)
        vm.prank(user3);
        vm.expectRevert();
        votingSystem.castVote(proposalId, "Option A");

        // Test getting winners
        (string[] memory winners, bool isDraw) =
            votingSystem.getProposalWinner(proposalId);
        // Both Option A and Option C have 1 vote each, so it should be a draw
        assertEq(winners.length, 2, "Should have 2 winners in a draw");
        assertTrue(isDraw, "Should be a draw");
    }

    function test_AccessControl() public {
        // Test that only admin can register voters
        address newUser = makeAddr("newUser");

        vm.prank(user1);
        vm.expectRevert();
        votingSystem.registerVoter(newUser, 5, new int256[](0));

        // Test that admin can register voters
        vm.startPrank(admin);
        votingSystem.registerVoter(newUser, 5, new int256[](0));
        vm.stopPrank();

        assertTrue(
            votingSystem.isVoterVerified(newUser), "New user should be verified"
        );
    }

    function test_ProposalLifecycle() public {
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        vm.prank(user1);
        uint256 proposalId = votingSystem.createProposal(
            "Lifecycle Test",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 2 days,
            block.timestamp + 5 days
        );

        // Check initial state
        assertEq(
            uint256(proposalState.getProposalStatus(proposalId)),
            uint256(IProposalState.ProposalStatus.PENDING),
            "Should start as PENDING"
        );

        // Move partway to start (still pending)
        vm.warp(block.timestamp + 1 days);
        // Check status while still pending
        assertEq(
            uint256(proposalState.getCurrentProposalStatus(proposalId)),
            uint256(IProposalState.ProposalStatus.PENDING),
            "Should still be PENDING"
        );

        // Move to start time
        vm.warp(block.timestamp + 2 days);
        // Check status should now be ACTIVE
        assertEq(
            uint256(proposalState.getCurrentProposalStatus(proposalId)),
            uint256(IProposalState.ProposalStatus.ACTIVE),
            "Should be ACTIVE"
        );

        // Vote to verify it's active
        vm.prank(user2);
        votingSystem.castVote(proposalId, "Yes");

        // Move partway through voting period (1 day before end)
        vm.warp(block.timestamp + 1 days);
        // Status should still be ACTIVE
        assertEq(
            uint256(proposalState.getCurrentProposalStatus(proposalId)),
            uint256(IProposalState.ProposalStatus.ACTIVE),
            "Should still be ACTIVE"
        );

        // Cast another vote
        vm.prank(user3);
        votingSystem.castVote(proposalId, "No");

        // Move to end time (should now be closed)
        vm.warp(block.timestamp + 2 days);
        // Status should now be CLOSED
        assertEq(
            uint256(proposalState.getCurrentProposalStatus(proposalId)),
            uint256(IProposalState.ProposalStatus.CLOSED),
            "Should be CLOSED"
        );
    }

    function test_VoterParticipationTracking() public {
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        vm.prank(user1);
        uint256 proposalId = votingSystem.createProposal(
            "Participation Test",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        vm.warp(block.timestamp + 1 days);
        proposalState.updateProposalStatus(proposalId);

        // Check initial participation
        assertEq(
            voterRegistry.getParticipatedProposalsCount(user2),
            0,
            "User2 should have 0 participated proposals initially"
        );

        // Vote
        vm.prank(user2);
        votingSystem.castVote(proposalId, "Yes");

        // Check participation after voting
        assertEq(
            voterRegistry.getParticipatedProposalsCount(user2),
            1,
            "User2 should have 1 participated proposal"
        );

        vm.prank(user2);
        uint256[] memory participatedProposals =
            votingSystem.getVoterParticipatedProposals();
        assertEq(
            participatedProposals.length,
            1,
            "Should have 1 participated proposal"
        );
        assertEq(
            participatedProposals[0],
            proposalId,
            "Should have participated in the correct proposal"
        );

        vm.prank(user2);
        string memory selectedOption =
            votingSystem.getVoterSelectedOption(proposalId);
        assertEq(selectedOption, "Yes", "Should have selected Yes");

        // Retract vote
        vm.prank(user2);
        votingSystem.retractVote(proposalId);

        // Check participation after retraction
        assertEq(
            voterRegistry.getParticipatedProposalsCount(user2),
            0,
            "User2 should have 0 participated proposals after retraction"
        );
    }

}
