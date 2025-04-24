// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {VotingSystem} from "../../src/VotingSystem.sol";
import {RBAC} from "../../src/RBAC.sol";
import {VoterManager} from "../../src/VoterManager.sol";
import {ProposalManager} from "../../src/ProposalManager.sol";

contract VoterManagerTest is Test {

    VotingSystem public votingSystem;
    RBAC public rbac;
    VoterManager public voterManager;
    ProposalManager public proposalManager;

    address public user1 = makeAddr("user1");
    address public admin = 0x45586259E1816AC7784Ae83e704eD354689081b1;

    function setUp() public {
        rbac = new RBAC();
        voterManager = new VoterManager(address(rbac));
        proposalManager =
            new ProposalManager(address(rbac), address(voterManager));
        votingSystem = new VotingSystem(
            address(rbac), address(voterManager), address(proposalManager)
        );

        vm.deal(admin, 10 ether);
        vm.startPrank(admin);

        rbac.grantRole(rbac.AUTHORIZED_CALLER(), address(this));

        vm.stopPrank();
        
        rbac.verifyVoter(address(this));
        rbac.verifyVoter(user1);


        vm.deal(user1, 10 ether);
    }

    function test_VerifiedUser() public view {
        assert(votingSystem.isVoterVerified(address(this)));
        assert(votingSystem.isVoterVerified(user1));
    }

    function test_RecordAndRemoveProposals() public {
        for (uint256 i = 0; i < 5; ++i) {
            voterManager.recordUserCreatedProposal(user1, i);
        }

        for (uint256 i = 0; i < 5; ++i) {
            voterManager.removeUserProposal(user1, i);
        }

        uint256 proposalCount = voterManager.getCreatedProposalsCount(user1);

        assertEq(
            proposalCount, 0, "Proposal count should be zero after removal"
        );
    }

}
