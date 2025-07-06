// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Test.sol";
import {AccessControlManager} from "../../src/access/AccessControlManager.sol";
import {ProposalState} from "../../src/proposal/ProposalState.sol";
import {ProposalOrchestrator} from "../../src/proposal/ProposalOrchestrator.sol";
import {ProposalValidator} from "../../src/validation/ProposalValidator.sol";
import {VoterRegistry} from "../../src/voter/VoterRegistry.sol";
import {VotingFacade} from "../../src/VotingFacade.sol";
import {IProposalState} from "../../src/interfaces/IProposalState.sol";

/**
 * @title VoterManagerTest
 * @notice Integration tests for voter management functionality
 * @dev Tests voter registration, verification, and participation tracking
 */
contract VoterManagerTest is Test {

    AccessControlManager public accessControl;
    ProposalValidator public proposalValidator;
    ProposalState public proposalState;
    VoterRegistry public voterRegistry;
    ProposalOrchestrator public proposalOrchestrator;
    VotingFacade public votingFacade;

    address public user1 = address(0x1);
    address public user2 = address(0x2);
    address public user3 = address(0x3);
    address public admin = address(0x4);

    /**
     * @notice Sets up the test environment with all system components
     * @dev Deploys contracts, sets up roles, and registers test voters
     */
    function setUp() public {
        vm.prank(admin);
        accessControl = new AccessControlManager();
        proposalState = new ProposalState(address(accessControl));
        proposalValidator = new ProposalValidator(
            address(accessControl), address(proposalState)
        );
        voterRegistry = new VoterRegistry(address(accessControl));

        proposalOrchestrator = new ProposalOrchestrator(
            address(accessControl),
            address(proposalValidator),
            address(proposalState),
            address(voterRegistry)
        );

        votingFacade = new VotingFacade(
            address(accessControl),
            address(voterRegistry),
            address(proposalOrchestrator)
        );

        // Grant necessary roles
        vm.startPrank(admin);
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(),
            address(proposalOrchestrator)
        );
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(),
            address(proposalValidator)
        );
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(), address(proposalState)
        );
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(), address(voterRegistry)
        );
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(), address(votingFacade)
        );
        accessControl.grantRole(
            accessControl.getADMIN_ROLE(), address(votingFacade)
        );
        accessControl.grantRole(accessControl.getADMIN_ROLE(), address(this));
        accessControl.grantRole(
            accessControl.getAUTHORIZED_CALLER_ROLE(), admin
        );

        // Register test voters
        votingFacade.registerVoter(address(this), bytes32(uint256(1)), new int256[](0));
        votingFacade.registerVoter(user1, bytes32(uint256(2)), new int256[](0));
        votingFacade.registerVoter(user2, bytes32(uint256(3)), new int256[](0));
        votingFacade.registerVoter(user3, bytes32(uint256(4)), new int256[](0));
        vm.stopPrank();
    }

    /**
     * @notice Tests voter verification status
     * @dev Verifies that registered voters are properly verified
     */
    function test_VerifiedUser() public view {
        assertTrue(
            votingFacade.isVoterVerified(address(this)),
            "Test contract should be verified"
        );
        assertTrue(
            votingFacade.isVoterVerified(user1), "User1 should be verified"
        );
    }

    /**
     * @notice Tests proposal recording and removal
     * @dev Verifies tracking of user-created proposals
     */
    function test_RecordAndRemoveProposals() public {
        vm.startPrank(admin);
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
        vm.stopPrank();
    }

    /**
     * @notice Tests voter registration with biometric data
     * @dev Verifies registration process and verification status
     */
    function test_VoterRegistration() public {
        address newUser = makeAddr("newUser");
        int256[] memory embeddings = new int256[](3);
        embeddings[0] = 12_345;
        embeddings[1] = 67_890;
        embeddings[2] = 11_111;

        vm.startPrank(admin);
        votingFacade.registerVoter(newUser, bytes32(uint256(5)), embeddings);
        vm.stopPrank();

        assertTrue(
            votingFacade.isVoterVerified(newUser),
            "User should be verified after registration"
        );
    }

    /**
     * @notice Tests voter participation in proposals
     * @dev Verifies participation tracking for a single proposal
     */
    function test_VoterParticipation() public {
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        vm.prank(user1);
        uint256 proposalId = votingFacade.createProposal(
            "Test Proposal",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        vm.warp(block.timestamp + 1 days);

        vm.prank(address(this));
        votingFacade.castVote(proposalId, "Yes");

        uint256[] memory participatedProposals =
            votingFacade.getVoterParticipatedProposals();
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

    /**
     * @notice Tests voter participation history across multiple proposals
     * @dev Verifies participation tracking for multiple proposals
     */
    function test_VoterParticipationHistory() public {
        string[] memory options = new string[](2);
        options[0] = "Yes";
        options[1] = "No";

        // Create multiple proposals
        vm.startPrank(user1);
        uint256 proposal1 = votingFacade.createProposal(
            "Proposal 1",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );

        uint256 proposal2 = votingFacade.createProposal(
            "Proposal 2",
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + 1 days,
            block.timestamp + 10 days
        );
        vm.stopPrank();

        vm.warp(block.timestamp + 1 days);

        // Vote on both proposals
        vm.startPrank(address(this));
        votingFacade.castVote(proposal1, "Yes");
        votingFacade.castVote(proposal2, "No");
        vm.stopPrank();

        uint256[] memory participatedProposals =
            votingFacade.getVoterParticipatedProposals();
        assertEq(
            participatedProposals.length,
            2,
            "Should have participated in 2 proposals"
        );
        assertEq(
            participatedProposals[0],
            proposal1,
            "Should have participated in proposal 1"
        );
        assertEq(
            participatedProposals[1],
            proposal2,
            "Should have participated in proposal 2"
        );

        string memory vote1 = votingFacade.getVoterSelectedOption(proposal1);
        string memory vote2 = votingFacade.getVoterSelectedOption(proposal2);
        assertEq(vote1, "Yes", "Should have voted Yes on proposal 1");
        assertEq(vote2, "No", "Should have voted No on proposal 2");
    }

    function test_OnlyAdminCanRegisterVoter() public {
        address newUser = makeAddr("newUser");

        vm.startPrank(user1);
        vm.expectRevert();
        votingFacade.registerVoter(newUser, bytes32(uint256(5)), new int256[](0));
        vm.stopPrank();
    }

}
