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
import {TestHelper} from "../helpers/TestHelper.sol";

/**
 * @title ComprehensiveTest
 * @notice End-to-end integration tests for the complete voting system
 * @dev Tests complex voting scenarios and system interactions
 */
contract ComprehensiveTest is Test {

    VotingFacade public votingFacade;
    AccessControlManager public accessControl;
    VoterRegistry public voterRegistry;
    ProposalOrchestrator public proposalOrchestrator;
    ProposalState public proposalState;

    ProposalValidator public proposalValidator;

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public user4 = makeAddr("user4");
    address public user5 = makeAddr("user5");
    address public admin = 0x45586259E1816AC7784Ae83e704eD354689081b1;

    /**
     * @notice Sets up the test environment with all system components
     * @dev Deploys contracts, sets up roles, and registers test voters
     */
    function setUp() public {
        // Deploy the complete refactored system
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

        // Grant admin role to VotingFacade and test contract
        accessControl.grantRole(
            accessControl.getADMIN_ROLE(), address(votingFacade)
        );
        accessControl.grantRole(accessControl.getADMIN_ROLE(), address(this));
        vm.stopPrank();

        // Register and verify all voters
        vm.startPrank(admin);
        votingFacade.registerVoter(address(this), bytes32(uint256(0)), new int256[](0));
        votingFacade.registerVoter(user1, bytes32(uint256(1)), new int256[](0));
        votingFacade.registerVoter(user2, bytes32(uint256(2)), new int256[](0));
        votingFacade.registerVoter(user3, bytes32(uint256(3)), new int256[](0));
        votingFacade.registerVoter(user4, bytes32(uint256(4)), new int256[](0));
        votingFacade.registerVoter(user5, bytes32(uint256(5)), new int256[](0));

        accessControl.grantRole(accessControl.getVERIFIED_VOTER_ROLE(), user1);
        accessControl.grantRole(accessControl.getVERIFIED_VOTER_ROLE(), user2);
        accessControl.grantRole(accessControl.getVERIFIED_VOTER_ROLE(), user3);
        accessControl.grantRole(accessControl.getVERIFIED_VOTER_ROLE(), user4);
        accessControl.grantRole(accessControl.getVERIFIED_VOTER_ROLE(), user5);
        vm.stopPrank();
    }

    /**
     * @notice Tests a complete voting scenario with multiple participants
     * @dev Simulates proposal creation, voting, vote changes, and result tallying
     */
    function test_CompleteVotingScenario() public {
        // Create a proposal for a community decision
        string[] memory options = new string[](4);
        options[0] = "Build a Park";
        options[1] = "Build a Library";
        options[2] = "Build a Gym";
        options[3] = "Save the Money";

        vm.prank(user1);
        uint256 proposalId = votingFacade.createProposal(
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

        // Test early voting prevention
        vm.prank(user2);
        vm.expectRevert();
        votingFacade.castVote(proposalId, "Build a Park");

        // Start voting period
        vm.warp(block.timestamp + 1 days);
        proposalState.updateProposalStatus(proposalId);
        assertTrue(
            proposalState.isProposalActive(proposalId),
            "Proposal should be active"
        );

        // First round of voting
        vm.prank(user1);
        votingFacade.castVote(proposalId, "Build a Park");

        vm.prank(user2);
        votingFacade.castVote(proposalId, "Build a Library");

        vm.prank(user3);
        votingFacade.castVote(proposalId, "Build a Park");

        // Verify intermediate results
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Build a Park"),
            2,
            "Park should have 2 votes"
        );
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Build a Library"),
            1,
            "Library should have 1 vote"
        );

        // Test vote changes
        vm.prank(user4);
        votingFacade.castVote(proposalId, "Build a Gym");

        vm.prank(user4);
        votingFacade.changeVote(proposalId, "Build a Park");

        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Build a Park"),
            3,
            "Park should have 3 votes after change"
        );
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Build a Gym"),
            0,
            "Gym should have 0 votes after change"
        );

        // Test vote retraction
        vm.prank(user5);
        votingFacade.castVote(proposalId, "Save the Money");

        vm.prank(user5);
        votingFacade.retractVote(proposalId);

        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Save the Money"),
            0,
            "Save the Money should have 0 votes after retraction"
        );

        // End voting period and check final results
        vm.warp(block.timestamp + 7 days);
        proposalState.updateProposalStatus(proposalId);

        (string[] memory winners, bool isDraw) =
            votingFacade.getProposalWinners(proposalId);
        assertEq(winners.length, 1, "Should have one winner");
        assertEq(winners[0], "Build a Park", "Park should be the winner");
        assertFalse(isDraw, "Should not be a draw");
    }

    function test_MultipleProposalsWorkflow() public {
        // Create multiple proposals to test the system under load

        // Proposal 1: Short-term decision
        string[] memory options1 = new string[](2);
        options1[0] = "Yes";
        options1[1] = "No";

        vm.prank(user1);
        uint256 proposal1 = votingFacade.createProposal(
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
        uint256 proposal2 = votingFacade.createProposal(
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
        votingFacade.castVote(proposal1, "Yes");

        vm.prank(user3);
        votingFacade.castVote(proposal1, "No");

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
        votingFacade.castVote(proposal2, "Option A");

        vm.prank(user4);
        votingFacade.castVote(proposal2, "Option A");

        vm.prank(user5);
        votingFacade.castVote(proposal2, "Option B");

        // End second proposal
        vm.warp(block.timestamp + 4 hours);
        proposalState.updateProposalStatus(proposal2);
        assertTrue(
            proposalState.isProposalClosed(proposal2),
            "Proposal 2 should be closed"
        );

        // Check results for both proposals
        (string[] memory winners1,) = votingFacade.getProposalWinners(proposal1);
        (string[] memory winners2,) = votingFacade.getProposalWinners(proposal2);

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
        uint256 proposalId = votingFacade.createProposal(
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
        votingFacade.castVote(proposalId, "Approve");

        assertEq(
            voterRegistry.getParticipatedProposalsCount(user2),
            1,
            "User2 should have 1 participated proposal"
        );

        vm.prank(user2);

        uint256[] memory participatedProposals =
            votingFacade.getVoterParticipatedProposals();
        assertEq(
            participatedProposals[0],
            proposalId,
            "User2 should have participated in correct proposal"
        );

        vm.prank(user2);
        string memory selectedOption =
            votingFacade.getVoterSelectedOption(proposalId);
        assertEq(
            selectedOption, "Approve", "User2 should have selected Approve"
        );

        // User2 changes vote
        vm.prank(user2);
        votingFacade.changeVote(proposalId, "Reject");

        vm.prank(user2);
        selectedOption = votingFacade.getVoterSelectedOption(proposalId);
        assertEq(
            selectedOption,
            "Reject",
            "User2 should have selected Reject after change"
        );

        // User2 retracts vote
        vm.prank(user2);
        votingFacade.retractVote(proposalId);

        assertEq(
            voterRegistry.getParticipatedProposalsCount(user2),
            0,
            "User2 should have 0 participated proposals after retraction"
        );
    }

}
