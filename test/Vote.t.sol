// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {Vote} from "../src/Vote.sol";
import {Ballot} from "../src/Ballot.sol";

contract VoteTest is Test {


    Vote public vote;
    address public user = makeAddr("user");

    function setUp() public {
        vote = new Vote();
        vm.deal(0x45586259E1816AC7784Ae83e704eD354689081b1, 10 ether);
        vm.prank(0x45586259E1816AC7784Ae83e704eD354689081b1);
        vote.grantRole(keccak256("VERIFIED_VOTER_ROLE"), user);
        vm.deal(user, 10 ether);
    }


    function test_VerifiedUser() public view {
        console.log(user);
        assert(vote.isVoterVerified(user));
    }


    function test_CreateProposal() public {
        vm.startPrank(user);
        
        string[] memory options = new string[](3);
        options[0] = "one";
        options[1] = "two";
        options[2] = "three";

        vote.createProposal("First prop", options, 100000000000, 200000000000);

        vm.stopPrank();
        assertEq(vote.getProposalCount(), 1, "wrong proposal count");
    }

}
