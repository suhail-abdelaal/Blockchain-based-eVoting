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
import {TestHelper} from "../helpers/TestHelper.sol";

contract ComprehensiveTest is Test {

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
    address public user4 = makeAddr("user4");
    address public user5 = makeAddr("user5");
    address public admin = 0x45586259E1816AC7784Ae83e704eD354689081b1;

    function setUp() public {
        // Deploy the complete refactored system
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

        // Deal ether to all participants
        vm.deal(admin, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(user4, 10 ether);
        vm.deal(user5, 10 ether);

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

        // Register all voters using the admin
        vm.startPrank(admin);
        votingSystem.registerVoter(address(this), 0, new int256[](0));
        votingSystem.registerVoter(user1, 1, new int256[](0));
        votingSystem.registerVoter(user2, 2, new int256[](0));
        votingSystem.registerVoter(user3, 3, new int256[](0));
        votingSystem.registerVoter(user4, 4, new int256[](0));
        votingSystem.registerVoter(user5, 5, new int256[](0));
        // Also grant verified voter roles directly to ensure they can create
        // proposals
        // accessControl.grantRole(accessControl.VERIFIED_VOTER(),
        // address(this));
        accessControl.grantRole(accessControl.VERIFIED_VOTER(), user1);
        accessControl.grantRole(accessControl.VERIFIED_VOTER(), user2);
        accessControl.grantRole(accessControl.VERIFIED_VOTER(), user3);
        accessControl.grantRole(accessControl.VERIFIED_VOTER(), user4);
        accessControl.grantRole(accessControl.VERIFIED_VOTER(), user5);
        vm.stopPrank();
    }

    function test_CompleteVotingScenario() public {
        // Create a proposal for a community decision
        string[] memory options = new string[](4);
        options[0] = "Build a Park";
        options[1] = "Build a Library";
        options[2] = "Build a Gym";
        options[3] = "Save the Money";

        vm.prank(user1);
        uint256 proposalId = votingSystem.createProposal(
            "Community Infrastructure Decision",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 7 days
        );

        console.log("Created proposal with ID:", proposalId);

        // Verify proposal creation
        assertEq(proposalId, 1, "First proposal should have ID 1");
        string[] memory retrievedOptions =
            proposalState.getProposalOptions(proposalId);
        assertEq(retrievedOptions.length, 4, "Should have 4 options");
        assertEq(
            retrievedOptions[0], "Build a Park", "First option should match"
        );

        // Try voting before proposal starts (should fail)
        vm.prank(user2);
        vm.expectRevert();
        votingSystem.castVote(proposalId, "Build a Park");

        // Move to voting period
        vm.warp(block.timestamp + 1 days);
        proposalState.updateProposalStatus(proposalId);
        assertTrue(
            proposalState.isProposalActive(proposalId),
            "Proposal should be active"
        );

        // First round of voting
        vm.prank(user1);
        votingSystem.castVote(proposalId, "Build a Park");

        vm.prank(user2);
        votingSystem.castVote(proposalId, "Build a Library");

        vm.prank(user3);
        votingSystem.castVote(proposalId, "Build a Park");

        // Check intermediate vote counts
        assertEq(
            voteTallying.getVoteCount(proposalId, "Build a Park"),
            2,
            "Park should have 2 votes"
        );
        assertEq(
            voteTallying.getVoteCount(proposalId, "Build a Library"),
            1,
            "Library should have 1 vote"
        );

        // User4 votes then changes their mind
        vm.prank(user4);
        votingSystem.castVote(proposalId, "Build a Gym");

        vm.prank(user4);
        votingSystem.changeVote(proposalId, "Build a Park");

        assertEq(
            voteTallying.getVoteCount(proposalId, "Build a Park"),
            3,
            "Park should have 3 votes after change"
        );
        assertEq(
            voteTallying.getVoteCount(proposalId, "Build a Gym"),
            0,
            "Gym should have 0 votes after change"
        );

        // User5 votes then retracts
        vm.prank(user5);
        votingSystem.castVote(proposalId, "Save the Money");

        vm.prank(user5);
        votingSystem.retractVote(proposalId);

        assertEq(
            voteTallying.getVoteCount(proposalId, "Save the Money"),
            0,
            "Save Money should have 0 votes after retraction"
        );

        // Final vote from test contract
        vm.prank(address(this));
        votingSystem.castVote(proposalId, "Build a Library");

        // Final vote counts before closing
        assertEq(
            voteTallying.getVoteCount(proposalId, "Build a Park"),
            3,
            "Final: Park should have 3 votes"
        );
        assertEq(
            voteTallying.getVoteCount(proposalId, "Build a Library"),
            2,
            "Final: Library should have 2 votes"
        );
        assertEq(
            voteTallying.getVoteCount(proposalId, "Build a Gym"),
            0,
            "Final: Gym should have 0 votes"
        );
        assertEq(
            voteTallying.getVoteCount(proposalId, "Save the Money"),
            0,
            "Final: Save Money should have 0 votes"
        );

        // Move to end of voting period
        vm.warp(block.timestamp + 7 days);
        proposalState.updateProposalStatus(proposalId);
        assertTrue(
            proposalState.isProposalClosed(proposalId),
            "Proposal should be closed"
        );

        // Try voting after closure (should fail)
        vm.prank(user5);
        vm.expectRevert();
        votingSystem.castVote(proposalId, "Build a Park");

        // Check final results
        (string[] memory winners, bool isDraw) =
            votingSystem.getProposalWinner(proposalId);
        assertEq(winners.length, 1, "Should have 1 winner");
        assertEq(winners[0], "Build a Park", "Park should win");
        assertFalse(isDraw, "Should not be a draw");

        console.log("Winner:", winners[0]);
        console.log("Is draw:", isDraw);
    }

    function test_MultipleProposalsWorkflow() public {
        // Create multiple proposals to test the system under load

        // Proposal 1: Short-term decision
        string[] memory options1 = new string[](2);
        options1[0] = "Yes";
        options1[1] = "No";

        vm.prank(user1);
        uint256 proposal1 = votingSystem.createProposal(
            "Should we upgrade the website?",
            options1,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 hours,
            block.timestamp + 2 hours
        );

        // Proposal 2: Medium-term decision
        string[] memory options2 = new string[](3);
        options2[0] = "Option A";
        options2[1] = "Option B";
        options2[2] = "Option C";

        vm.prank(user2);
        uint256 proposal2 = votingSystem.createProposal(
            "Choose the next feature to implement",
            options2,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 2 hours,
            block.timestamp + 4 hours
        );

        // Verify both proposals were created
        assertEq(proposal1, 1, "First proposal should have ID 1");
        assertEq(proposal2, 2, "Second proposal should have ID 2");

        // Move to first proposal's voting period
        vm.warp(block.timestamp + 1 hours);
        proposalState.updateProposalStatus(proposal1);
        assertTrue(
            proposalState.isProposalActive(proposal1),
            "Proposal 1 should be active"
        );
        assertFalse(
            proposalState.isProposalActive(proposal2),
            "Proposal 2 should not be active yet"
        );

        // Vote on first proposal
        vm.prank(user1);
        votingSystem.castVote(proposal1, "Yes");

        vm.prank(user3);
        votingSystem.castVote(proposal1, "No");

        // Move to second proposal's voting period (first proposal ends)
        vm.warp(block.timestamp + 2 hours);
        proposalState.updateProposalStatus(proposal1);
        proposalState.updateProposalStatus(proposal2);

        assertFalse(
            proposalState.isProposalActive(proposal1),
            "Proposal 1 should be closed"
        );
        assertTrue(
            proposalState.isProposalActive(proposal2),
            "Proposal 2 should be active"
        );

        // Vote on second proposal
        vm.prank(user2);
        votingSystem.castVote(proposal2, "Option A");

        vm.prank(user4);
        votingSystem.castVote(proposal2, "Option A");

        vm.prank(user5);
        votingSystem.castVote(proposal2, "Option B");

        // End second proposal
        vm.warp(block.timestamp + 4 hours);
        proposalState.updateProposalStatus(proposal2);
        assertTrue(
            proposalState.isProposalClosed(proposal2),
            "Proposal 2 should be closed"
        );

        // Check results for both proposals
        (string[] memory winners1,) = votingSystem.getProposalWinner(proposal1);
        (string[] memory winners2,) = votingSystem.getProposalWinner(proposal2);

        // First proposal should be a draw (1 Yes, 1 No)
        assertEq(winners1.length, 2, "Proposal 1 should have 2 winners (draw)");

        // Second proposal should have Option A as winner (2 votes vs 1)
        assertEq(winners2.length, 1, "Proposal 2 should have 1 winner");
        assertEq(winners2[0], "Option A", "Option A should win proposal 2");
    }

    function test_ParticipationTracking() public {
        string[] memory options = new string[](2);
        options[0] = "Approve";
        options[1] = "Reject";

        // Create proposal
        vm.prank(user1);
        uint256 proposalId = votingSystem.createProposal(
            "Final Test Proposal",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        vm.warp(block.timestamp + 1 days);
        proposalState.updateProposalStatus(proposalId);

        // Track participation for user2
        assertEq(
            voterRegistry.getParticipatedProposalsCount(user2),
            0,
            "User2 should have 0 participated proposals initially"
        );
        assertEq(
            voterRegistry.getCreatedProposalsCount(user1),
            1,
            "User1 should have 1 created proposal"
        );

        // User2 votes
        vm.prank(user2);
        votingSystem.castVote(proposalId, "Approve");

        assertEq(
            voterRegistry.getParticipatedProposalsCount(user2),
            1,
            "User2 should have 1 participated proposal"
        );

        vm.prank(user2);

        uint256[] memory participatedProposals =
            votingSystem.getVoterParticipatedProposals();
        assertEq(
            participatedProposals[0],
            proposalId,
            "User2 should have participated in correct proposal"
        );

        vm.prank(user2);
        string memory selectedOption =
            votingSystem.getVoterSelectedOption(proposalId);
        assertEq(
            selectedOption, "Approve", "User2 should have selected Approve"
        );

        // User2 changes vote
        vm.prank(user2);
        votingSystem.changeVote(proposalId, "Reject");

        vm.prank(user2);
        selectedOption = votingSystem.getVoterSelectedOption(proposalId);
        assertEq(
            selectedOption,
            "Reject",
            "User2 should have selected Reject after change"
        );

        // User2 retracts vote
        vm.prank(user2);
        votingSystem.retractVote(proposalId);

        assertEq(
            voterRegistry.getParticipatedProposalsCount(user2),
            0,
            "User2 should have 0 participated proposals after retraction"
        );
    }

}
