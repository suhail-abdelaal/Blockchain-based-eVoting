// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {Vote} from "../src/Vote.sol";
import {RBAC} from "../src/RBAC.sol";
import {Ballot} from "../src/Ballot.sol";
import {VoterRegistry} from "../src/VoterRegistry.sol";

contract VoteTest is Test {
    Vote public vote;
    Ballot public ballot;
    VoterRegistry public voterRegistry;

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public admin = 0x45586259E1816AC7784Ae83e704eD354689081b1;

    function setUp() public {
        vm.deal(admin, 100 ether);
        vm.startPrank(admin);

        vote = new Vote();
        vote.grantRole(keccak256("ADMIN_ROLE"), address(vote));
        voterRegistry = VoterRegistry(vote.getVoterRegistry());
        ballot = Ballot(vote.getBallot());

        vote.verifyVoter(user1);
        vote.verifyVoter(user2);
        vote.verifyVoter(user3);

        vm.stopPrank();

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
    }

    function test_VerifiedUser() public view {
        // console.log(user1);
        assert(vote.isVoterVerified(user1));
        assert(vote.isVoterVerified(user2));
        assert(vote.isVoterVerified(user3));
    }

    function test_CreateProposal() public {
        vm.prank(user1);
        createProposal(1);

        vm.prank(user2);
        createProposal(1);

        vm.prank(user3);
        createProposal(1);

        vm.prank(admin);
        uint256 count = vote.getProposalCount();

        assertEq(count, 3, "wrong proposal count");
    }

    function test_VoteCast() public {
        vm.startPrank(user1);
        createProposal(2);
        vm.stopPrank();

        vm.startPrank(user2);
        vote.castVote(1, "one");
        vote.castVote(2, "one");
        vm.stopPrank();

        vm.startPrank(user3);
        vote.castVote(1, "one");
        vote.castVote(2, "two");

        uint256 count11 = vote.getVoteCount(1, "one");
        uint256 count12 = vote.getVoteCount(1, "two");
        uint256 count13 = vote.getVoteCount(1, "three");
        uint256 count21 = vote.getVoteCount(2, "one");
        uint256 count22 = vote.getVoteCount(2, "two");
        uint256 count23 = vote.getVoteCount(2, "three");
        vm.stopPrank();

        assertEq(count11, 2);
        assertEq(count12, 0);
        assertEq(count13, 0);
        assertEq(count21, 1);
        assertEq(count22, 1);
        assertEq(count23, 0);
    }

    function test_RetractVote() public {
        vm.prank(user1);
        createProposal(1);

        vm.startPrank(user2);
        vote.castVote(1, "one");
        vote.retractVote(1);
        vm.stopPrank();

        vm.startPrank(user3);
        vote.castVote(1, "one");
        vote.retractVote(1);

        uint256 count = vote.getVoteCount(1, "one");
        uint256 usr2Count = voterRegistry.getParticipatedProposalsCount(user2);
        uint256 usr3Count = voterRegistry.getParticipatedProposalsCount(user3);
        vm.stopPrank();

        assertEq(count, 0);
        assertEq(usr2Count, 0);
        assertEq(usr3Count, 0);
    }

    function test_VoterRecords(
        uint256 num
    ) public {
        vm.assume(num <= 1000);
        vm.startPrank(user1);

        for (uint256 i = 0; i < num; ++i) {
            voterRegistry.recordUserCreatedProposal(user1, i);
        }

        for (uint256 i = 0; i < num; ++i) {
            voterRegistry.removeUserProposal(user1, i);
        }
        uint256 count = voterRegistry.getCreatedProposalsCount(user1);

        vm.stopPrank();

        assertEq(count, 0);
    }

    function createProposal(
        uint256 n
    ) public {
        for (uint256 i = 0; i < n; ++i) {
            string[] memory options = new string[](3);
            options[0] = "one";
            options[1] = "two";
            options[2] = "three";

            vote.createProposal(
                "First prop", options, 100_000_000_000, 200_000_000_000
            );
        }
    }
}
