// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "../src/access/AccessControlManager.sol";
import "../src/access/AccessControlWrapper.sol";
import "../src/validation/ProposalValidator.sol";
import "../src/proposal/ProposalState.sol";
import "../src/voting/VoteTallying.sol";
import "../src/voter/VoterRegistry.sol";
import "../src/proposal/ProposalOrchestrator.sol";
import "../src/VotingFacade.sol";

contract DeployRefactoredSystem {
    function deploy() external returns (
        address accessControl,
        address proposalValidator,
        address proposalState,
        address voteTallying,
        address voterRegistry,
        address proposalOrchestrator,
        address votingFacade
    ) {
        // 1. Deploy Access Control (Single Responsibility: Role Management)
        accessControl = address(new AccessControlManager());

        // 2. Deploy Proposal State (Single Responsibility: Proposal Lifecycle)
        proposalState = address(new ProposalState(accessControl));

        // 3. Deploy Vote Tallying (Single Responsibility: Vote Counting)
        voteTallying = address(new VoteTallying(accessControl, proposalState));

        // 4. Deploy Voter Registry (Single Responsibility: Voter Data)
        voterRegistry = address(new VoterRegistry(accessControl));

        // 5. Deploy Proposal Validator (Single Responsibility: Validation Logic)
        proposalValidator = address(new ProposalValidator(accessControl, proposalState));

        // 6. Deploy Proposal Orchestrator (Single Responsibility: Coordination)
        proposalOrchestrator = address(new ProposalOrchestrator(
            accessControl,
            proposalValidator,
            proposalState,
            voteTallying,
            voterRegistry
        ));

        // 7. Deploy Voting Facade (Single Responsibility: Simplified Interface)
        votingFacade = address(new VotingFacade(
            accessControl,
            voterRegistry,
            proposalOrchestrator
        ));

        return (
            accessControl,
            proposalValidator,
            proposalState,
            voteTallying,
            voterRegistry,
            proposalOrchestrator,
            votingFacade
        );
    }
} 