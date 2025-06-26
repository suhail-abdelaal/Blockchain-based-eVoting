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

contract TestHelper is Test {

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

    function setUp() public virtual {
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

        // Register voters
        voterRegistry.registerVoter(address(this), 1, new int256[](0));
        voterRegistry.registerVoter(user1, 2, new int256[](0));
        voterRegistry.registerVoter(user2, 3, new int256[](0));
        voterRegistry.registerVoter(user3, 4, new int256[](0));

        // Verify voters in access control
        accessControl.verifyVoter(address(this));
        accessControl.verifyVoter(user1);
        accessControl.verifyVoter(user2);
        accessControl.verifyVoter(user3);
        vm.stopPrank();

        // Deal ether to test accounts
        vm.deal(user1, 10 ether);
        vm.deal(user2, 10 ether);
        vm.deal(user3, 10 ether);
        vm.deal(admin, 10 ether);
    }

    function createTestProposal(
        address creator,
        string memory title,
        string[] memory options,
        uint256 startOffset,
        uint256 duration
    ) internal returns (uint256) {
        vm.prank(creator);
        return votingFacade.createProposal(
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
        votingFacade.castVote(proposalId, option);
    }

    function retractVote(address voter, uint256 proposalId) internal {
        vm.prank(voter);
        votingFacade.retractVote(proposalId);
    }

    function changeVote(
        address voter,
        uint256 proposalId,
        string memory newOption
    ) internal {
        vm.prank(voter);
        votingFacade.changeVote(proposalId, newOption);
    }

    function warpToProposalStart(uint256 startTimestamp) internal {
        vm.warp(startTimestamp);
    }

    function warpToProposalEnd(uint256 endTimestamp) internal {
        vm.warp(endTimestamp);
    }

    function assertVoteCount(
        uint256 proposalId,
        string memory option,
        uint256 expectedCount
    ) internal {
        uint256 actualCount = votingFacade.getVoteCount(proposalId, option);
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
            votingFacade.getProposalWinners(proposalId);
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
