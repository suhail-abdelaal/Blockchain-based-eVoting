// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {VotingFacade} from "../../src/VotingFacade.sol";
import {AccessControlManager} from "../../src/access/AccessControlManager.sol";
import {VoterRegistry} from "../../src/voter/VoterRegistry.sol";
import {ProposalOrchestrator} from "../../src/proposal/ProposalOrchestrator.sol";
import {ProposalState} from "../../src/proposal/ProposalState.sol";

import {ProposalValidator} from "../../src/validation/ProposalValidator.sol";
import {IProposalState} from "../../src/interfaces/IProposalState.sol";

/**
 * @title VotingSystemTest
 * @notice Integration tests for the complete voting system
 * @dev Tests end-to-end workflows and component interactions
 */
contract VotingSystemTest is Test {

    VotingFacade public votingFacade;
    AccessControlManager public accessControl;
    VoterRegistry public voterRegistry;
    ProposalOrchestrator public proposalOrchestrator;
    ProposalState public proposalState;

    ProposalValidator public proposalValidator;

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public admin = 0x45586259E1816AC7784Ae83e704eD354689081b1;

    /**
     * @notice Sets up the test environment with all system components
     * @dev Deploys contracts, sets up roles, and registers test voters
     */
    function setUp() public {
        // Deploy the refactored system
        vm.prank(admin);

        accessControl = new AccessControlManager();
        proposalState = new ProposalState(address(accessControl));

        voterRegistry = new VoterRegistry(address(accessControl));
        proposalValidator = new ProposalValidator(
            address(accessControl), address(proposalState)
        );

        proposalOrchestrator = new ProposalOrchestrator(
            address(accessControl),
            address(proposalValidator),
            address(proposalState),
            address(voterRegistry)
        );

        votingFacade = new VotingFacade(
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
            accessControl.getAUTHORIZED_CALLER_ROLE(), address(this)
        );
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(),
            address(proposalOrchestrator)
        );
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(), address(voterRegistry)
        );
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(), address(votingFacade)
        );
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(), address(proposalState)
        );
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(),
            address(proposalValidator)
        );
        // Grant admin role to VotingFacade so it can call admin functions on
        // behalf of users
        accessControl.grantRole(
            accessControl.getADMIN_ROLE(), address(votingFacade)
        );
        // Grant admin role to test contract so it can call admin functions
        accessControl.grantRole(accessControl.getADMIN_ROLE(), address(this));
        vm.stopPrank();

        // Register voters using the admin
        vm.startPrank(admin);
        votingFacade.registerVoter(address(this), bytes32(uint256(1)), new int256[](0));
        votingFacade.registerVoter(user1, bytes32(uint256(2)), new int256[](0));
        votingFacade.registerVoter(user2, bytes32(uint256(3)), new int256[](0));
        votingFacade.registerVoter(user3, bytes32(uint256(4)), new int256[](0));
        // Also grant verified voter roles directly to ensure they can create
        // proposals
        accessControl.grantRole(
            accessControl.getVERIFIED_VOTER_ROLE(), address(this)
        );
        accessControl.grantRole(accessControl.getVERIFIED_VOTER_ROLE(), user1);
        accessControl.grantRole(accessControl.getVERIFIED_VOTER_ROLE(), user2);
        accessControl.grantRole(accessControl.getVERIFIED_VOTER_ROLE(), user3);
        vm.stopPrank();
    }

    /**
     * @notice Tests a complete voting workflow
     * @dev Covers proposal creation, voting, status changes, and result tallying
     */
    function test_CompleteVotingWorkflow() public {
        // Test creating a proposal
        string[] memory options = new string[](3);
        options[0] = "Option A";
        options[1] = "Option B";
        options[2] = "Option C";

        vm.prank(user1);
        uint256 proposalId = votingFacade.createProposal(
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
        votingFacade.castVote(proposalId, "Option A");

        // Move to proposal start time
        vm.warp(block.timestamp + 1 days);

        vm.prank(user2);
        votingFacade.castVote(proposalId, "Option A");

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
        votingFacade.castVote(proposalId, "Option B");

        vm.prank(address(this));
        votingFacade.castVote(proposalId, "Option A");

        // Check vote counts
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Option A"),
            2,
            "Option A should have 2 votes"
        );
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Option B"),
            1,
            "Option B should have 1 vote"
        );
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Option C"),
            0,
            "Option C should have 0 votes"
        );

        // Test that voters can't vote twice
        vm.prank(user2);
        vm.expectRevert();
        votingFacade.castVote(proposalId, "Option B");

        // Test vote retraction
        vm.prank(user3);
        votingFacade.retractVote(proposalId);
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Option B"),
            0,
            "Option B should have 0 votes after retraction"
        );

        // Test vote change
        vm.prank(address(this));
        votingFacade.changeVote(proposalId, "Option C");
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Option A"),
            1,
            "Option A should have 1 vote after change"
        );
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Option C"),
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
        votingFacade.castVote(proposalId, "Option A");

        // Test getting winners
        (string[] memory winners, bool isDraw) =
            votingFacade.getProposalWinners(proposalId);
        // Both Option A and Option C have 1 vote each, so it should be a draw
        assertEq(winners.length, 2, "Should have 2 winners in a draw");
        assertTrue(isDraw, "Should be a draw");
    }

    function test_AccessControl() public {
        // Test that only admin can register voters
        address newUser = makeAddr("newUser");

        vm.prank(user1);
        vm.expectRevert();
        votingFacade.registerVoter(newUser, bytes32(uint256(5)), new int256[](0));

        // Test that admin can register voters
        vm.startPrank(admin);
        votingFacade.registerVoter(newUser, bytes32(uint256(5)), new int256[](0));
        vm.stopPrank();

        assertTrue(
            votingFacade.isVoterVerified(newUser), "New user should be verified"
        );
    }

    function test_ProposalLifecycle() public {
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        vm.prank(user1);
        uint256 proposalId = votingFacade.createProposal(
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
        votingFacade.castVote(proposalId, "Yes");

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
        votingFacade.castVote(proposalId, "No");

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
        uint256 proposalId = votingFacade.createProposal(
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
        votingFacade.castVote(proposalId, "Yes");

        // Check participation after voting
        assertEq(
            voterRegistry.getParticipatedProposalsCount(user2),
            1,
            "User2 should have 1 participated proposal"
        );

        vm.prank(user2);
        uint256[] memory participatedProposals =
            votingFacade.getVoterParticipatedProposals();
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
            votingFacade.getVoterSelectedOption(proposalId);
        assertEq(selectedOption, "Yes", "Should have selected Yes");

        // Retract vote
        vm.prank(user2);
        votingFacade.retractVote(proposalId);

        // Check participation after retraction
        assertEq(
            voterRegistry.getParticipatedProposalsCount(user2),
            0,
            "User2 should have 0 participated proposals after retraction"
        );
    }

    function testVoteCounting() public {
        string[] memory options = new string[](3);
        options[0] = "Option A";
        options[1] = "Option B";
        options[2] = "Option C";

        vm.prank(user1);
        uint256 proposalId = votingFacade.createProposal(
            "Vote Counting Test",
            options,
            IProposalState.VoteMutability.IMMUTABLE,
            block.timestamp,
            block.timestamp + 1 days
        );

        vm.prank(user1);
        votingFacade.castVote(proposalId, "Option A");
        vm.prank(user2);
        votingFacade.castVote(proposalId, "Option B");
        vm.prank(user3);
        votingFacade.castVote(proposalId, "Option B");

        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Option A"),
            1,
            "Option A should have 1 vote"
        );
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Option B"),
            2,
            "Option B should have 2 votes"
        );
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Option C"),
            0,
            "Option C should have 0 votes"
        );
    }

    function testVoteChangeScenario() public {
        string[] memory options = new string[](3);
        options[0] = "Option A";
        options[1] = "Option B";
        options[2] = "Option C";

        vm.prank(user1);
        uint256 proposalId = votingFacade.createProposal(
            "Vote Change Test",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp,
            block.timestamp + 1 days
        );

        // Initial votes
        vm.prank(user1);
        votingFacade.castVote(proposalId, "Option A");
        vm.prank(user2);
        votingFacade.castVote(proposalId, "Option B");

        // Check initial counts
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Option B"),
            1,
            "Option B should initially have 1 vote"
        );

        // Change vote
        vm.prank(user2);
        votingFacade.changeVote(proposalId, "Option C");

        // Check final counts
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Option A"),
            1,
            "Option A should still have 1 vote"
        );
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Option C"),
            1,
            "Option C should now have 1 vote"
        );
    }

}
