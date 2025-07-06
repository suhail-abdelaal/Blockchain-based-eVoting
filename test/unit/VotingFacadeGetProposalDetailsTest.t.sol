// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {TestHelper} from "../helpers/TestHelper.sol";
import {IProposalState} from "../../src/interfaces/IProposalState.sol";

contract VotingFacadeGetProposalDetailsTest is TestHelper {

    function setUp() public override {
        super.setUp();
    }

    function test_GetProposalDetails_ValidProposal() public {
        // Create a test proposal
        string[] memory options = new string[](3);
        options[0] = "Option A";
        options[1] = "Option B";
        options[2] = "Option C";

        uint256 startTime = block.timestamp + 1 days;
        uint256 endTime = block.timestamp + 10 days;

        uint256 proposalId =
            createTestProposal(user1, "Test Proposal", options, 1 days, 9 days);

        vm.prank(user1);
        // Get proposal details
        (
            address owner,
            string memory title,
            string[] memory returnedOptions,
            uint256 startDate,
            uint256 endDate,
            IProposalState.ProposalStatus status,
            IProposalState.VoteMutability voteMutability,
            string[] memory winners,
            bool isDraw
        ) = votingFacade.getProposalDetails(proposalId);

        // Assert all returned values
        assertEq(owner, user1, "Owner should be user1");
        assertEq(title, "Test Proposal", "Title should match");
        assertEq(returnedOptions.length, 3, "Should have 3 options");
        assertEq(returnedOptions[0], "Option A", "First option should match");
        assertEq(returnedOptions[1], "Option B", "Second option should match");
        assertEq(returnedOptions[2], "Option C", "Third option should match");
        assertEq(startDate, startTime, "Start date should match");
        assertEq(endDate, endTime, "End date should match");
        assertEq(
            uint256(status),
            uint256(IProposalState.ProposalStatus.PENDING),
            "Status should be PENDING initially"
        );
        assertEq(
            uint256(voteMutability),
            uint256(IProposalState.VoteMutability.MUTABLE),
            "Vote mutability should be MUTABLE"
        );
        assertEq(winners.length, 0, "Should have no winners initially");
        assertFalse(isDraw, "Should not be a draw initially");
    }

    function test_GetProposalDetails_ActiveProposal() public {
        // Create and activate a proposal
        uint256 proposalId = createStandardProposal(user1);

        // Get proposal start time and warp to it to make it active
        (,,, uint256 proposalStartTime,,,) =
            proposalState.getProposal(proposalId);
        warpToProposalStart(proposalStartTime);

        votingFacade.updateProposalStatus(proposalId);

        (
            address owner,
            string memory title,
            string[] memory returnedOptions,
            uint256 startDate,
            uint256 endDate,
            IProposalState.ProposalStatus status,
            IProposalState.VoteMutability voteMutability,
            string[] memory winners,
            bool isDraw
        ) = votingFacade.getProposalDetails(proposalId);

        assertEq(owner, user1, "Owner should be user1");
        assertEq(title, "Test Proposal", "Title should match");
        assertEq(
            uint256(status),
            uint256(IProposalState.ProposalStatus.ACTIVE),
            "Status should be ACTIVE"
        );
    }

    function test_GetProposalDetails_ClosedProposalWithWinner() public {
        // Create a proposal
        uint256 proposalId = createStandardProposal(user1);

        // Get proposal timestamps
        (,,, uint256 proposalStartTime, uint256 proposalEndTime,,) =
            proposalState.getProposal(proposalId);

        // Warp to proposal start time
        warpToProposalStart(proposalStartTime);

        // Cast votes to create a winner
        castVote(user1, proposalId, "Option A");
        castVote(user2, proposalId, "Option A");
        castVote(user3, proposalId, "Option B");

        // Warp to proposal end time
        warpToProposalEnd(proposalEndTime);

        votingFacade.updateProposalStatus(proposalId);

        (
            address owner,
            string memory title,
            string[] memory returnedOptions,
            uint256 startDate,
            uint256 endDate,
            IProposalState.ProposalStatus status,
            IProposalState.VoteMutability voteMutability,
            string[] memory winners,
            bool isDraw
        ) = votingFacade.getProposalDetails(proposalId);

        assertEq(
            uint256(status),
            uint256(IProposalState.ProposalStatus.CLOSED),
            "Status should be CLOSED"
        );
        assertTrue(winners.length > 0, "Should have winners");
        assertEq(winners[0], "Option A", "Option A should be the winner");
        assertFalse(isDraw, "Should not be a draw");
    }

    function test_GetProposalDetails_ClosedProposalWithDraw() public {
        // Create a proposal
        uint256 proposalId = createStandardProposal(user1);

        // Get proposal timestamps
        (,,, uint256 proposalStartTime, uint256 proposalEndTime,,) =
            proposalState.getProposal(proposalId);

        // Warp to proposal start time
        warpToProposalStart(proposalStartTime);

        // Cast votes to create a draw
        castVote(user1, proposalId, "Option A");
        castVote(user2, proposalId, "Option B");

        // Warp to proposal end time
        warpToProposalEnd(proposalEndTime);

        votingFacade.updateProposalStatus(proposalId);

        (
            address owner,
            string memory title,
            string[] memory returnedOptions,
            uint256 startDate,
            uint256 endDate,
            IProposalState.ProposalStatus status,
            IProposalState.VoteMutability voteMutability,
            string[] memory winners,
            bool isDraw
        ) = votingFacade.getProposalDetails(proposalId);

        assertEq(
            uint256(status),
            uint256(IProposalState.ProposalStatus.CLOSED),
            "Status should be CLOSED"
        );
        assertTrue(isDraw, "Should be a draw");
        assertEq(winners.length, 2, "Should have 2 winners in a draw");
    }

    function test_GetProposalDetails_ImmutableProposal() public {
        // Create an immutable proposal
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        uint256 expectedStartTime = block.timestamp + 1 days;
        uint256 expectedEndTime = block.timestamp + 10 days;

        vm.prank(user1);
        uint256 proposalId = votingFacade.createProposal(
            "Immutable Proposal",
            options,
            IProposalState.VoteMutability.IMMUTABLE,
            expectedStartTime,
            expectedEndTime
        );

        votingFacade.updateProposalStatus(proposalId);

        (
            address owner,
            string memory title,
            string[] memory returnedOptions,
            uint256 startDate,
            uint256 endDate,
            IProposalState.ProposalStatus status,
            IProposalState.VoteMutability voteMutability,
            string[] memory winners,
            bool isDraw
        ) = votingFacade.getProposalDetails(proposalId);

        assertEq(
            uint256(voteMutability),
            uint256(IProposalState.VoteMutability.IMMUTABLE),
            "Vote mutability should be IMMUTABLE"
        );
        assertEq(title, "Immutable Proposal", "Title should match");
        assertEq(owner, user1, "Owner should be user1");
        assertEq(startDate, expectedStartTime, "Start date should match");
        assertEq(endDate, expectedEndTime, "End date should match");
        assertEq(
            uint256(status),
            uint256(IProposalState.ProposalStatus.PENDING),
            "Status should be PENDING initially"
        );
        assertEq(returnedOptions.length, 2, "Should have 2 options");
        assertEq(returnedOptions[0], "Yes", "First option should be Yes");
        assertEq(returnedOptions[1], "No", "Second option should be No");
        assertEq(winners.length, 0, "Should have no winners initially");
        assertFalse(isDraw, "Should not be a draw initially");
    }

    function test_GetProposalDetails_MultipleProposals() public {
        // Create multiple proposals
        uint256 proposalId1 = createStandardProposal(user1);
        uint256 proposalId2 = createStandardProposal(user2);

        // Get details for first proposal and verify owner
        (address owner1,,,,,,,,) = votingFacade.getProposalDetails(proposalId1);
        assertEq(owner1, user1, "First proposal owner should be user1");

        // Get details for second proposal and verify owner
        (address owner2,,,,,,,,) = votingFacade.getProposalDetails(proposalId2);
        assertEq(owner2, user2, "Second proposal owner should be user2");

        // Verify proposal IDs
        assertEq(proposalId1, 1, "First proposal should have ID 1");
        assertEq(proposalId2, 2, "Second proposal should have ID 2");
    }

    function test_GetProposalDetails_RevertOnUnverifiedCaller() public {
        // Create a proposal first
        uint256 proposalId = createStandardProposal(user1);

        // Try to call with an unregistered address
        address unregisteredUser = makeAddr("unregistered");
        vm.prank(unregisteredUser);

        // This should revert because the caller is not verified
        vm.expectRevert();
        votingFacade.getProposalDetails(proposalId);
    }

    function test_GetProposalDetails_RevertOnNonexistentProposal() public {
        // Try to get details for a proposal that doesn't exist
        vm.expectRevert();
        votingFacade.getProposalDetails(999);
    }

    function test_GetProposalDetails_LongTitle() public {
        // Create a proposal with a very long title
        string memory longTitle =
            "This is a very long proposal title that exceeds normal length to test how the system handles longer strings and ensures data integrity";

        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        vm.prank(user1);
        uint256 proposalId = votingFacade.createProposal(
            longTitle,
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        (, string memory title,,,,,,,) =
            votingFacade.getProposalDetails(proposalId);

        assertEq(title, longTitle, "Long title should be preserved correctly");
    }

    function test_GetProposalDetails_TimeConstraints() public {
        // Test proposals with specific time constraints
        uint256 startTime = block.timestamp + 2 hours;
        uint256 endTime = block.timestamp + 7 days;

        string[] memory options = new string[](2);
        options[0] = "Accept";
        options[1] = "Reject";

        vm.prank(user1);
        uint256 proposalId = votingFacade.createProposal(
            "Time Constrained Proposal",
            options,
            IProposalState.VoteMutability.MUTABLE,
            startTime,
            endTime
        );

        (
            address owner,
            string memory title,
            string[] memory returnedOptions,
            uint256 startDate,
            uint256 endDate,
            IProposalState.ProposalStatus status,
            IProposalState.VoteMutability voteMutability,
            string[] memory winners,
            bool isDraw
        ) = votingFacade.getProposalDetails(proposalId);

        assertEq(startDate, startTime, "Start time should match exactly");
        assertEq(endDate, endTime, "End time should match exactly");
        assertEq(
            uint256(status),
            uint256(IProposalState.ProposalStatus.PENDING),
            "Status should be PENDING before start time"
        );
        assertEq(owner, user1, "Owner should be correct");
        assertEq(title, "Time Constrained Proposal", "Title should match");
        assertEq(returnedOptions.length, 2, "Should have 2 options");
        assertEq(
            uint256(voteMutability),
            uint256(IProposalState.VoteMutability.MUTABLE),
            "Should be mutable"
        );
        assertEq(winners.length, 0, "Should have no winners initially");
        assertFalse(isDraw, "Should not be a draw initially");
    }

    function test_GetProposalDetails_ManyOptions() public {
        // Test proposal with many options (edge case)
        string[] memory options = new string[](10);
        for (uint256 i = 0; i < 10; i++) {
            options[i] = string.concat("Option ", vm.toString(i + 1));
        }

        vm.prank(user1);
        uint256 proposalId = votingFacade.createProposal(
            "Multi-Option Proposal",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        (,, string[] memory returnedOptions,,,,,,) =
            votingFacade.getProposalDetails(proposalId);

        assertEq(returnedOptions.length, 10, "Should have 10 options");
        for (uint256 i = 0; i < 10; i++) {
            assertEq(
                returnedOptions[i],
                string.concat("Option ", vm.toString(i + 1)),
                string.concat("Option ", vm.toString(i + 1), " should match")
            );
        }
    }

}
