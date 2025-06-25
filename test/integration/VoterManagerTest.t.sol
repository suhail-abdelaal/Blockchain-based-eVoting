// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test, console} from "forge-std/Test.sol";
import {VotingFacade} from "../../src/VotingFacade.sol";
import {AccessControlManager} from "../../src/access/AccessControlManager.sol";
import {VoterRegistry} from "../../src/voter/VoterRegistry.sol";
import {ProposalOrchestrator} from "../../src/proposal/ProposalOrchestrator.sol";
import {ProposalState} from "../../src/proposal/ProposalState.sol";
import {VoteTallying} from "../../src/voting/VoteTallying.sol";
import {ProposalValidator} from "../../src/validation/ProposalValidator.sol";
import {TestHelper} from "../helpers/TestHelper.sol";
import {IProposalState} from "../../src/interfaces/IProposalState.sol";

contract VoterManagerTest is Test {

    VotingFacade public votingSystem;
    AccessControlManager public accessControl;
    VoterRegistry public voterRegistry;
    ProposalOrchestrator public proposalOrchestrator;
    ProposalState public proposalState;
    VoteTallying public voteTallying;
    ProposalValidator public proposalValidator;

    address public user1 = makeAddr("user1");
    address public admin = 0x45586259E1816AC7784Ae83e704eD354689081b1;

    function setUp() public {
        // Deploy the refactored system
        vm.prank(admin);
        accessControl = new AccessControlManager();
        proposalState = new ProposalState(address(accessControl));
        voteTallying =
            new VoteTallying(address(accessControl), address(proposalState));
        voterRegistry = new VoterRegistry(address(accessControl));
        proposalValidator = new ProposalValidator(
            address(accessControl), address(proposalState)
        );

        proposalOrchestrator = new ProposalOrchestrator(
            address(accessControl),
            address(proposalValidator),
            address(proposalState),
            address(voteTallying),
            address(voterRegistry)
        );

        votingSystem = new VotingFacade(
            address(accessControl),
            address(voterRegistry),
            address(proposalOrchestrator)
        );

        vm.deal(admin, 10 ether);
        vm.deal(user1, 10 ether);

        // Grant necessary roles using proper access control
        vm.startPrank(admin);
        accessControl.grantRole(
            accessControl.AUTHORIZED_CALLER(), address(this)
        );
        accessControl.grantRole(
            accessControl.AUTHORIZED_CALLER(), address(proposalOrchestrator)
        );
        accessControl.grantRole(
            accessControl.AUTHORIZED_CALLER(), address(voterRegistry)
        );
        accessControl.grantRole(
            accessControl.AUTHORIZED_CALLER(), address(votingSystem)
        );
        accessControl.grantRole(
            accessControl.AUTHORIZED_CALLER(), address(proposalState)
        );
        accessControl.grantRole(
            accessControl.AUTHORIZED_CALLER(), address(voteTallying)
        );
        // Grant admin role to VotingFacade so it can call admin functions on
        // behalf of users
        accessControl.grantRole(
            accessControl.ADMIN_ROLE(), address(votingSystem)
        );
        // Grant admin role to test contract so it can call admin functions
        accessControl.grantRole(accessControl.ADMIN_ROLE(), address(this));
        vm.stopPrank();

        // Register initial voters using the admin
        vm.startPrank(admin);
        votingSystem.registerVoter(address(this), 1, new int256[](0));
        votingSystem.registerVoter(user1, 2, new int256[](0));
        // Also grant verified voter roles directly to ensure they can create
        // proposals
        accessControl.grantRole(accessControl.VERIFIED_VOTER(), address(this));
        accessControl.grantRole(accessControl.VERIFIED_VOTER(), user1);
        vm.stopPrank();
    }

    function test_VerifiedUser() public view {
        assertTrue(
            votingSystem.isVoterVerified(address(this)),
            "Test contract should be verified"
        );
        assertTrue(
            votingSystem.isVoterVerified(user1), "User1 should be verified"
        );
    }

    function test_RecordAndRemoveProposals() public {
        // Record proposals for user1
        for (uint256 i = 1; i <= 5; ++i) {
            voterRegistry.recordUserCreatedProposal(user1, i);
        }

        uint256 proposalCount = voterRegistry.getCreatedProposalsCount(user1);
        assertEq(proposalCount, 5, "Should have 5 created proposals");

        // Remove proposals for user1
        for (uint256 i = 1; i <= 5; ++i) {
            voterRegistry.removeUserProposal(user1, i);
        }

        proposalCount = voterRegistry.getCreatedProposalsCount(user1);
        assertEq(
            proposalCount, 0, "Proposal count should be zero after removal"
        );
    }

    function test_VoterRegistration() public {
        address newUser = makeAddr("newUser");
        int256[] memory embeddings = new int256[](3);
        embeddings[0] = 12_345;
        embeddings[1] = 67_890;
        embeddings[2] = 11_111;

        vm.startPrank(admin);
        votingSystem.registerVoter(newUser, 5, embeddings);
        vm.stopPrank();

        assertTrue(
            votingSystem.isVoterVerified(newUser),
            "User should be verified after registration"
        );
    }

    function test_VoterParticipation() public {
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        vm.prank(user1);
        uint256 proposalId = votingSystem.createProposal(
            "Test Proposal",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        vm.warp(block.timestamp + 1 days);

        vm.prank(address(this));
        votingSystem.castVote(proposalId, "Yes");

        uint256[] memory participatedProposals =
            votingSystem.getVoterParticipatedProposals();
        assertEq(
            participatedProposals.length,
            1,
            "Should have participated in 1 proposal"
        );
        assertEq(
            participatedProposals[0],
            proposalId,
            "Should have participated in the correct proposal"
        );
    }

    function test_VoterParticipationHistory() public {
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        // Create multiple proposals
        vm.startPrank(user1);
        uint256 proposal1 = votingSystem.createProposal(
            "Proposal 1",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        uint256 proposal2 = votingSystem.createProposal(
            "Proposal 2",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        // Vote on both proposals as the test contract
        vm.startPrank(address(this));
        votingSystem.castVote(proposal1, "Yes");
        votingSystem.castVote(proposal2, "No");
        vm.stopPrank();

        uint256[] memory participatedProposals =
            votingSystem.getVoterParticipatedProposals();
        assertEq(
            participatedProposals.length,
            2,
            "Should have participated in 2 proposals"
        );

        string memory option1 = votingSystem.getVoterSelectedOption(proposal1);
        string memory option2 = votingSystem.getVoterSelectedOption(proposal2);

        assertEq(option1, "Yes", "Should have selected Yes for proposal 1");
        assertEq(option2, "No", "Should have selected No for proposal 2");
    }

    function test_OnlyAdminCanRegisterVoter() public {
        address newUser = makeAddr("newUser");

        vm.startPrank(user1);
        vm.expectRevert();
        votingSystem.registerVoter(newUser, 5, new int256[](0));
        vm.stopPrank();
    }

}
