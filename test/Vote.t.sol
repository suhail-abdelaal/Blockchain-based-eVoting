// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {Vote} from "../src/Vote.sol";
import {RBAC} from "../src/RBAC.sol";
import {Ballot} from "../src/Ballot.sol";

contract VoteTest is Test {
    Vote public vote;
    Ballot public ballot;
    address public user = makeAddr("user");

    function setUp() public {
        vm.deal(0x45586259E1816AC7784Ae83e704eD354689081b1, 10 ether);
        vm.startPrank(0x45586259E1816AC7784Ae83e704eD354689081b1);
        RBAC rbac = new RBAC();
        vote = new Vote(address(rbac));
        rbac.grantRole(keccak256("ADMIN_ROLE"), address(vote));
        vm.stopPrank();

        vote.verifyVoter(user);
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

        vote.createProposal(
            "First prop", options, 100_000_000_000, 200_000_000_000
        );
        uint256 count = vote.getProposalCount();

        vm.stopPrank();
        assertEq(count, 1, "wrong proposal count");
    }
}
