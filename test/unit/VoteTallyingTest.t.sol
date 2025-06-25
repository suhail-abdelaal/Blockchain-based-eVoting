// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {VoteTallying} from "../../src/voting/VoteTallying.sol";
import {AccessControlManager} from "../../src/access/AccessControlManager.sol";
import {ProposalState} from "../../src/proposal/ProposalState.sol";

contract VoteTallyingTest is Test {

    VoteTallying public voteTallying;
    AccessControlManager public accessControl;
    ProposalState public proposalState;
    address public admin = 0x45586259E1816AC7784Ae83e704eD354689081b1;
    address public user1 = makeAddr("user1");

    function setUp() public {
        vm.prank(admin);
        accessControl = new AccessControlManager();
        proposalState = new ProposalState(address(accessControl));
        voteTallying =
            new VoteTallying(address(accessControl), address(proposalState));

        vm.deal(admin, 10 ether);
        vm.deal(user1, 10 ether);

        vm.startPrank(admin);
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(), address(this)
        );
        vm.stopPrank();
    }

    function test_GetVoteCount() public {
        assertEq(
            voteTallying.getVoteCount(1, "Option A"),
            0,
            "Initial vote count should be 0"
        );
    }

    function test_IncrementVoteCount() public {
        voteTallying.incrementVoteCount(1, "Option A");
        assertEq(
            voteTallying.getVoteCount(1, "Option A"),
            1,
            "Vote count should be 1 after increment"
        );

        voteTallying.incrementVoteCount(1, "Option A");
        assertEq(
            voteTallying.getVoteCount(1, "Option A"),
            2,
            "Vote count should be 2 after second increment"
        );
    }

    function test_DecrementVoteCount() public {
        voteTallying.incrementVoteCount(1, "Option A");
        voteTallying.incrementVoteCount(1, "Option A");
        assertEq(
            voteTallying.getVoteCount(1, "Option A"),
            2,
            "Vote count should be 2"
        );

        voteTallying.decrementVoteCount(1, "Option A");
        assertEq(
            voteTallying.getVoteCount(1, "Option A"),
            1,
            "Vote count should be 1 after decrement"
        );

        voteTallying.decrementVoteCount(1, "Option A");
        assertEq(
            voteTallying.getVoteCount(1, "Option A"),
            0,
            "Vote count should be 0 after second decrement"
        );
    }

    function test_MultipleOptions() public {
        voteTallying.incrementVoteCount(1, "Option A");
        voteTallying.incrementVoteCount(1, "Option B");
        voteTallying.incrementVoteCount(1, "Option A");

        assertEq(
            voteTallying.getVoteCount(1, "Option A"),
            2,
            "Option A should have 2 votes"
        );
        assertEq(
            voteTallying.getVoteCount(1, "Option B"),
            1,
            "Option B should have 1 vote"
        );
        assertEq(
            voteTallying.getVoteCount(1, "Option C"),
            0,
            "Option C should have 0 votes"
        );
    }

    function test_SetWinners() public {
        string[] memory winners = new string[](2);
        winners[0] = "Option A";
        winners[1] = "Option B";

        voteTallying.setWinners(1, winners, true);

        (string[] memory retrievedWinners, bool isDraw) =
            voteTallying.getWinningOptions(1);
        assertEq(retrievedWinners.length, 2, "Should have 2 winners");
        assertEq(
            retrievedWinners[0], "Option A", "First winner should be Option A"
        );
        assertEq(
            retrievedWinners[1], "Option B", "Second winner should be Option B"
        );
        assertTrue(isDraw, "Should be a draw");
    }

    function test_SetWinnersNoDraw() public {
        string[] memory winners = new string[](1);
        winners[0] = "Option A";

        voteTallying.setWinners(1, winners, false);

        (string[] memory retrievedWinners, bool isDraw) =
            voteTallying.getWinningOptions(1);
        assertEq(retrievedWinners.length, 1, "Should have 1 winner");
        assertEq(retrievedWinners[0], "Option A", "Winner should be Option A");
        assertFalse(isDraw, "Should not be a draw");
    }

    function test_TallyVotes() public {
        (string[] memory winners, bool isDraw) = voteTallying.tallyVotes(1);
        assertEq(winners.length, 0, "Should return empty winners array");
        assertFalse(isDraw, "Should not be a draw");
    }

    function test_OnlyAuthorizedCallerCanIncrement() public {
        vm.prank(user1);
        vm.expectRevert();
        voteTallying.incrementVoteCount(1, "Option A");
    }

    function test_OnlyAuthorizedCallerCanDecrement() public {
        voteTallying.incrementVoteCount(1, "Option A");

        vm.prank(user1);
        vm.expectRevert();
        voteTallying.decrementVoteCount(1, "Option A");
    }

    function test_OnlyAuthorizedCallerCanSetWinners() public {
        string[] memory winners = new string[](1);
        winners[0] = "Option A";

        vm.prank(user1);
        vm.expectRevert();
        voteTallying.setWinners(1, winners, false);
    }

    function test_OnlyAuthorizedCallerCanTallyVotes() public {
        vm.prank(user1);
        vm.expectRevert();
        voteTallying.tallyVotes(1);
    }

}
