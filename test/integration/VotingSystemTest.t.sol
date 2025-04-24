// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {VotingSystem} from "../../src/VotingSystem.sol";
import {RBAC} from "../../src/RBAC.sol";
import {VoterManager} from "../../src/VoterManager.sol";
import {ProposalManager} from "../../src/ProposalManager.sol";

contract VotingSystemTest is Test {

    VotingSystem public votingSystem;
    RBAC public rbac;
    VoterManager public voterManager;
    ProposalManager public proposalManager;

    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");
    address public admin = 0x45586259E1816AC7784Ae83e704eD354689081b1;

    function setUp() public {
        vm.deal(admin, 10 ether);
        vm.startPrank(admin);
        console.log("Admin address: ", admin);
        console.log("Contract address: ", address(this));

        rbac = new RBAC();
        voterManager = new VoterManager(address(rbac));
        proposalManager =
            new ProposalManager(address(rbac), address(voterManager));

        votingSystem = new VotingSystem(
            address(rbac), address(voterManager), address(proposalManager)
        );
        rbac.grantRole(rbac.AUTHORIZED_CALLER(), address(proposalManager));
        rbac.grantRole(rbac.AUTHORIZED_CALLER(), address(voterManager));
        rbac.grantRole(rbac.AUTHORIZED_CALLER(), address(votingSystem));

        rbac.verifyVoter(address(this));
        rbac.verifyVoter(user1);
        rbac.verifyVoter(user2);
        rbac.verifyVoter(user3);

        vm.stopPrank();

        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
    }

    function test_CastVote() public {
        string[] memory options = new string[](3);
        options[0] = "Option A";
        options[1] = "Option B";
        options[2] = "Option C";

        vm.prank(user1);
        votingSystem.createProposal(
            "Proposal 1",
            options,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );
        vm.warp(block.timestamp + 1 days);

        vm.prank(user2);
        votingSystem.castVote(1, "Option A");

        vm.prank(user3);
        votingSystem.castVote(1, "Option A");

        uint256 voteCount = votingSystem.getVoteCount(1, "Option A");
        assertEq(voteCount, 2, "Vote count mismatch");
    }

    function test_RetractVote() public {
        string[] memory options = new string[](3);
        options[0] = "Option A";
        options[1] = "Option B";
        options[2] = "Option C";

        vm.prank(user1);
        votingSystem.createProposal(
            "Proposal 1",
            options,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );
        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user2);
        votingSystem.castVote(1, "Option A");
        votingSystem.retractVote(1);
        vm.stopPrank();

        uint256 voteCount = votingSystem.getVoteCount(1, "Option A");
        assertEq(voteCount, 0, "Vote count should be zero after retraction");
    }

    function test_ChangeVote() public {
        string[] memory options = new string[](3);
        options[0] = "Option A";
        options[1] = "Option B";
        options[2] = "Option C";

        vm.prank(user1);
        votingSystem.createProposal(
            "Proposal 1",
            options,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );
        vm.warp(block.timestamp + 1 days);

        vm.startPrank(user2);
        votingSystem.castVote(1, "Option A");
        votingSystem.changeVote(1, "Option B");
        vm.stopPrank();

        uint256 voteCountOptionA = votingSystem.getVoteCount(1, "Option A");
        uint256 voteCountOptionB = votingSystem.getVoteCount(1, "Option B");

        assertEq(
            voteCountOptionA,
            0,
            "Vote count for Option A should be zero after changing vote"
        );
        assertEq(
            voteCountOptionB,
            1,
            "Vote count for Option B should be one after changing vote"
        );
    }

}
