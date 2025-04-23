// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {VotingSystem} from "../src/VotingSystem.sol";
import {ProposalManager} from "../src/ProposalManager.sol";
import {VoterManager} from "../src/VoterManager.sol";

contract VoteTest is Test {
    VotingSystem public votingSysstem;
    ProposalManager public proposalManager;
    VoterManager public voterManager;

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public admin = 0x45586259E1816AC7784Ae83e704eD354689081b1;

    function setUp() public {
        vm.deal(admin, 100 ether);
        vm.startPrank(admin);

        votingSysstem = new VotingSystem();
        votingSysstem.grantRole(keccak256("ADMIN_ROLE"), address(votingSysstem));
        voterManager = VoterManager(votingSysstem.getVoterManager());
        proposalManager = ProposalManager(votingSysstem.getProposalManager());

        votingSysstem.verifyVoter(user1);
        votingSysstem.verifyVoter(user2);
        votingSysstem.verifyVoter(user3);

        vm.stopPrank();

        vm.deal(user1, 100 ether);
        vm.deal(user2, 100 ether);
        vm.deal(user3, 100 ether);
    }

    function test_VerifiedUser() public view {
        // console.log(user1);
        assert(votingSysstem.isVoterVerified(user1));
        assert(votingSysstem.isVoterVerified(user2));
        assert(votingSysstem.isVoterVerified(user3));
    }

    function test_CreateProposal() public {
        vm.prank(user1);
        createProposal(1);

        vm.prank(user2);
        createProposal(1);

        vm.prank(user3);
        createProposal(1);

        vm.prank(admin);
        uint256 count = votingSysstem.getProposalCount();

        assertEq(count, 3, "wrong proposal count");
    }

    function test_ProposalFinalizationNoDraw() public {
        vm.prank(user1);
        createProposal(1);

        vm.prank(user2);
        votingSysstem.castVote(1, "one");

        vm.prank(user3);
        votingSysstem.castVote(1, "one");

        vm.startPrank(user1);
        votingSysstem.castVote(1, "one");

        vm.warp(block.timestamp + 11 days);
        (string[] memory winners, bool isDraw) = votingSysstem.getPoposalWinner(1);
        vm.stopPrank();
        assertEq(winners[0], "one");
        assert(!isDraw);
    }

    function test_ProposalFinalizationDraw() public {
        vm.prank(user1);
        createProposal(1);

        vm.prank(user2);
        votingSysstem.castVote(1, "one");

        vm.prank(user3);
        votingSysstem.castVote(1, "two");

        vm.startPrank(user1);
        votingSysstem.castVote(1, "three");

        vm.warp(block.timestamp + 11 days);
        (string[] memory winners, bool isDraw) = votingSysstem.getPoposalWinner(1);
        vm.stopPrank();
    
        assertEq(winners.length, 3);
        assert(isDraw);
    }

    function test_VoteCast() public {
        vm.startPrank(user1);
        createProposal(2);
        vm.stopPrank();

        vm.startPrank(user2);
        votingSysstem.castVote(1, "one");
        votingSysstem.castVote(2, "one");
        vm.stopPrank();

        vm.startPrank(user3);
        votingSysstem.castVote(1, "one");
        votingSysstem.castVote(2, "two");

        uint256 count11 = votingSysstem.getVoteCount(1, "one");
        uint256 count12 = votingSysstem.getVoteCount(1, "two");
        uint256 count13 = votingSysstem.getVoteCount(1, "three");
        uint256 count21 = votingSysstem.getVoteCount(2, "one");
        uint256 count22 = votingSysstem.getVoteCount(2, "two");
        uint256 count23 = votingSysstem.getVoteCount(2, "three");
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
        votingSysstem.castVote(1, "one");
        votingSysstem.retractVote(1);
        vm.stopPrank();

        vm.startPrank(user3);
        votingSysstem.castVote(1, "one");
        votingSysstem.retractVote(1);

        uint256 count = votingSysstem.getVoteCount(1, "one");
        uint256 usr2Count = voterManager.getParticipatedProposalsCount(user2);
        uint256 usr3Count = voterManager.getParticipatedProposalsCount(user3);
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
            voterManager.recordUserCreatedProposal(user1, i);
        }

        for (uint256 i = 0; i < num; ++i) {
            voterManager.removeUserProposal(user1, i);
        }
        uint256 count = voterManager.getCreatedProposalsCount(user1);

        vm.stopPrank();

        assertEq(count, 0);
    }

    function test_ProposalStatus() public {
        vm.startPrank(user1);
        string[] memory options = new string[](3);
        options[0] = "one";
        options[1] = "two";
        options[2] = "three";

        uint256 start = block.timestamp + 1 days;
        uint256 end = start + 1 days;

        votingSysstem.createProposal("Prop", options, start, end);

        vm.expectRevert();
        votingSysstem.castVote(1, "one");

        vm.warp(block.timestamp + 1 days);
        votingSysstem.castVote(1, "one");
        uint256 count = votingSysstem.getVoteCount(1, "one");

        vm.warp(block.timestamp + 1 days);

        vm.expectRevert();
        votingSysstem.castVote(1, "one");

        vm.stopPrank();
        assertEq(count, 1);
    }

    function createProposal(
        uint256 n
    ) public {
        for (uint256 i = 0; i < n; ++i) {
            string[] memory options = new string[](3);
            options[0] = "one";
            options[1] = "two";
            options[2] = "three";

            votingSysstem.createProposal(
                "Prop",
                options,
                block.timestamp + 11 minutes,
                block.timestamp + 10 days
            );
        }
        vm.warp(block.timestamp + 11 minutes);
    }
}
