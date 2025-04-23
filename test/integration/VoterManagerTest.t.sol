// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {VotingSystem} from "../../src/VotingSystem.sol";
import {VoterManager} from "../../src/VoterManager.sol";

contract VoterManagerTest is Test {
    VotingSystem public votingSystem;
    VoterManager public voterManager;
    address public user1 = makeAddr("user1");
    address public admin = 0x45586259E1816AC7784Ae83e704eD354689081b1;

    function setUp() public {
        vm.deal(admin, 10 ether);

        vm.startPrank(admin);

        votingSystem = new VotingSystem();

        votingSystem.verifyVoter(address(this));
        votingSystem.verifyVoter(user1);
        voterManager = VoterManager(votingSystem.getVoterManager());

        vm.stopPrank();

        vm.deal(user1, 10 ether);
    }

    function test_VerifiedUser() public view {
        assert(votingSystem.isVoterVerified(address(this)));
        assert(votingSystem.isVoterVerified(user1));
    }

    function test_RecordAndRemoveProposals() public {
        vm.startPrank(user1);

        for (uint256 i = 0; i < 5; ++i) {
            voterManager.recordUserCreatedProposal(user1, i);
        }

        for (uint256 i = 0; i < 5; ++i) {
            voterManager.removeUserProposal(user1, i);
        }

        uint256 proposalCount = voterManager.getCreatedProposalsCount(user1);
        
        vm.stopPrank();

        assertEq(
            proposalCount, 0, "Proposal count should be zero after removal"
        );
    }
}
