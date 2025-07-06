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
 * @title ProposalManagerTest
 * @notice Integration tests for proposal management functionality
 * @dev Tests proposal creation, voting, and finalization scenarios
 */
contract ProposalManagerTest is Test {

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

    // Track proposals for counting
    uint256 public proposalCount = 0;

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

        // Grant admin role to VotingFacade so it can call admin functions on
        // behalf of users
        accessControl.grantRole(
            accessControl.getADMIN_ROLE(), address(votingFacade)
        );
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
     * @notice Tests proposal creation functionality
     * @dev Verifies proposal creation and initial state
     */
    function test_CreateProposal() public {
        string[] memory options = new string[](3);
        options[0] = "Option A";
        options[1] = "Option B";
        options[2] = "Option C";

        vm.prank(user1);
        uint256 proposalId = votingFacade.createProposal(
            "Proposal 1",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        assertEq(proposalId, 1, "First proposal should have ID 1");

        // Check that proposal was created correctly
        string[] memory retrievedOptions = proposalState.getProposalOptions(1);
        assertEq(retrievedOptions.length, 3, "Should have 3 options");
        assertEq(retrievedOptions[0], "Option A", "First option should match");
    }

    /**
     * @notice Tests proposal finalization with a clear winner
     * @dev Verifies vote counting and winner determination without a draw
     */
    function test_ProposalFinalizationNoDraw() public {
        string[] memory options = new string[](3);
        options[0] = "Option A";
        options[1] = "Option B";
        options[2] = "Option C";

        vm.prank(user1);
        uint256 proposalId = votingFacade.createProposal(
            "Proposal 1",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        vm.warp(block.timestamp + 1 days);
        proposalState.updateProposalStatus(proposalId);

        vm.prank(user2);
        votingFacade.castVote(proposalId, "Option A");

        vm.prank(user3);
        votingFacade.castVote(proposalId, "Option A");

        // Check vote counts
        uint256 voteCount =
            proposalOrchestrator.getVoteCount(proposalId, "Option A");
        assertEq(voteCount, 2, "Option A should have 2 votes");

        vm.warp(block.timestamp + 11 days);
        proposalState.updateProposalStatus(proposalId);
        (string[] memory winners, bool isDraw) =
            votingFacade.getProposalWinners(proposalId);

        assertEq(winners.length, 1, "Should have 1 winner");
        assertEq(winners[0], "Option A", "Winner should be Option A");
        assertFalse(isDraw, "Should not be a draw");
    }

    /**
     * @notice Tests proposal finalization with a draw
     * @dev Verifies vote counting and winner determination in a tie scenario
     */
    function test_ProposalFinalizationDraw() public {
        string[] memory options = new string[](3);
        options[0] = "Option A";
        options[1] = "Option B";
        options[2] = "Option C";

        vm.prank(user1);
        uint256 proposalId = votingFacade.createProposal(
            "Proposal 1",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        vm.warp(block.timestamp + 1 days);
        proposalState.updateProposalStatus(proposalId);

        vm.prank(user2);
        votingFacade.castVote(proposalId, "Option A");

        vm.prank(user3);
        votingFacade.castVote(proposalId, "Option B");

        // Check vote counts
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Option A"),
            1,
            "Option A should have 1 vote"
        );
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Option B"),
            1,
            "Option B should have 1 vote"
        );

        vm.warp(block.timestamp + 11 days);
        proposalState.updateProposalStatus(proposalId);
        (string[] memory winners, bool isDraw) =
            votingFacade.getProposalWinners(proposalId);

        assertEq(winners.length, 2, "Should have 2 winners in a draw");
        assertTrue(isDraw, "Should be a draw");
    }

    function test_VoteRetraction() public {
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        vm.prank(user1);
        uint256 proposalId = votingFacade.createProposal(
            "Test Proposal",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        vm.warp(block.timestamp + 1 days);
        proposalState.updateProposalStatus(proposalId);

        // Cast vote
        vm.prank(user2);
        votingFacade.castVote(proposalId, "Yes");

        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Yes"),
            1,
            "Should have 1 vote for Yes"
        );

        // Retract vote
        vm.prank(user2);
        votingFacade.retractVote(proposalId);

        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Yes"),
            0,
            "Should have 0 votes for Yes after retraction"
        );
    }

    function test_VoteChange() public {
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        vm.prank(user1);
        uint256 proposalId = votingFacade.createProposal(
            "Test Proposal",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        vm.warp(block.timestamp + 1 days);
        proposalState.updateProposalStatus(proposalId);

        // Cast initial vote
        vm.prank(user2);
        votingFacade.castVote(proposalId, "Yes");

        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Yes"),
            1,
            "Should have 1 vote for Yes"
        );
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "No"),
            0,
            "Should have 0 votes for No"
        );

        // Change vote
        vm.prank(user2);
        votingFacade.changeVote(proposalId, "No");

        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "Yes"),
            0,
            "Should have 0 votes for Yes after change"
        );
        assertEq(
            proposalOrchestrator.getVoteCount(proposalId, "No"),
            1,
            "Should have 1 vote for No after change"
        );
    }

}
