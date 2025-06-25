// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import {Test} from "forge-std/Test.sol";
import {VotingFacade} from "../../src/VotingFacade.sol";
import {AccessControlManager} from "../../src/access/AccessControlManager.sol";
import {VoterRegistry} from "../../src/voter/VoterRegistry.sol";
import {ProposalOrchestrator} from "../../src/proposal/ProposalOrchestrator.sol";
import {ProposalState} from "../../src/proposal/ProposalState.sol";
import {VoteTallying} from "../../src/voting/VoteTallying.sol";
import {ProposalValidator} from "../../src/validation/ProposalValidator.sol";
import {IProposalState} from "../../src/interfaces/IProposalState.sol";

contract TestHelper is Test {

    VotingFacade public votingSystem;
    AccessControlManager public accessControl;
    VoterRegistry public voterRegistry;
    ProposalOrchestrator public proposalOrchestrator;
    ProposalState public proposalState;
    VoteTallying public voteTallying;
    ProposalValidator public proposalValidator;

    address public admin = 0x45586259E1816AC7784Ae83e704eD354689081b1;
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");
    address public user3 = makeAddr("user3");

    function setUp() public virtual {
        // Deploy the refactored system
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

        // Grant necessary roles
        vm.prank(admin);
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

        // Register test voters
        vm.prank(admin);
        votingSystem.registerVoter(address(this), 1, new int256[](0));
        vm.prank(admin);
        votingSystem.registerVoter(user1, 2, new int256[](0));
        vm.prank(admin);
        votingSystem.registerVoter(user2, 3, new int256[](0));
        vm.prank(admin);
        votingSystem.registerVoter(user3, 4, new int256[](0));

        // Fund accounts
        vm.deal(admin, 10 ether);
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
    }

    function createTestProposal(
        address creator,
        string memory title,
        string[] memory options,
        uint256 startOffset,
        uint256 duration
    ) internal returns (uint256) {
        vm.prank(creator);
        return votingSystem.createProposal(
            title,
            options,
            IProposalState.VoteMutability.MUTABLE,
            block.timestamp + startOffset,
            block.timestamp + startOffset + duration
        );
    }

    function createStandardProposal(address creator)
        internal
        returns (uint256)
    {
        string[] memory options = new string[](3);
        options[0] = "Option A";
        options[1] = "Option B";
        options[2] = "Option C";

        return createTestProposal(
            creator, "Test Proposal", options, 1 days, 10 days
        );
    }

    function castVote(
        address voter,
        uint256 proposalId,
        string memory option
    ) internal {
        vm.prank(voter);
        votingSystem.castVote(proposalId, option);
    }

    function retractVote(address voter, uint256 proposalId) internal {
        vm.prank(voter);
        votingSystem.retractVote(proposalId);
    }

    function changeVote(
        address voter,
        uint256 proposalId,
        string memory newOption
    ) internal {
        vm.prank(voter);
        votingSystem.changeVote(proposalId, newOption);
    }

    function warpToProposalStart(uint256 proposalId) internal {
        // This would need to be implemented based on actual proposal start time
        // For now, we'll just warp forward by 1 day
        vm.warp(block.timestamp + 1 days);
    }

    function warpToProposalEnd(uint256 proposalId) internal {
        // This would need to be implemented based on actual proposal end time
        // For now, we'll just warp forward by 11 days
        vm.warp(block.timestamp + 11 days);
    }

    function assertVoteCount(
        uint256 proposalId,
        string memory option,
        uint256 expectedCount
    ) internal {
        uint256 actualCount = votingSystem.getVoteCount(proposalId, option);
        assertEq(
            actualCount,
            expectedCount,
            string.concat("Vote count for ", option, " mismatch")
        );
    }

    function assertProposalWinner(
        uint256 proposalId,
        string[] memory expectedWinners,
        bool expectedIsDraw
    ) internal {
        (string[] memory winners, bool isDraw) =
            votingSystem.getProposalWinner(proposalId);
        assertEq(
            winners.length, expectedWinners.length, "Winner count mismatch"
        );
        assertEq(isDraw, expectedIsDraw, "Draw status mismatch");

        for (uint256 i = 0; i < expectedWinners.length; i++) {
            assertEq(
                winners[i],
                expectedWinners[i],
                string.concat("Winner ", vm.toString(i), " mismatch")
            );
        }
    }

}
