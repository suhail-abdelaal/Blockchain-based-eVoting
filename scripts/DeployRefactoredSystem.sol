// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "forge-std/Script.sol";
import "../src/access/AccessControlManager.sol";
import "../src/proposal/ProposalState.sol";
import "../src/proposal/ProposalOrchestrator.sol";
import "../src/validation/ProposalValidator.sol";
import "../src/voter/VoterRegistry.sol";
import "../src/VotingFacade.sol";

contract DeployRefactoredSystem is Script {
    function run() external returns (
        address accessControl,
        address proposalState,
        address proposalOrchestrator,
        address proposalValidator,
        address voterRegistry,
        address votingFacade
    ) {
        vm.startBroadcast();

        // Deploy contracts
        accessControl = address(new AccessControlManager());
        proposalState = address(new ProposalState(accessControl));
        proposalValidator = address(new ProposalValidator(accessControl, proposalState));
        voterRegistry = address(new VoterRegistry(accessControl));
        
        proposalOrchestrator = address(new ProposalOrchestrator(
            accessControl,
            proposalValidator,
            proposalState,
            voterRegistry
        ));

        votingFacade = address(new VotingFacade(
            accessControl,
            proposalOrchestrator,
            voterRegistry
        ));

        vm.stopBroadcast();

        return (
            accessControl,
            proposalState,
            proposalOrchestrator,
            proposalValidator,
            voterRegistry,
            votingFacade
        );
    }
} 