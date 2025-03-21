// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "@openzeppelin/contracts/access/Ownable.sol";

contract VoterRegistry is Ownable {
    /* Erros and Events */
    error VoterAlreadyVerified(address voter);

    event VoterVerified(address indexed voter);

    /* User Defined Datatypes */
    struct Voter {
        string name;
        bool isVerified;
        uint256[] featureVector;
        mapping(uint256 => string) selectedOption;
        uint256[] participatedProposalsId;
        uint256[] createdProposalsId;

    }

    /* State Variables */
    mapping(address => Voter) public voters;

    /* Constructor */
    constructor() Ownable(msg.sender) {}


    /* Public Methods */
    function verifyVoter(
        address _voter,
        string calldata _voterName,
        uint256[] calldata _featureVector
        ) public onlyOwner {

        if (voters[_voter].isVerified) {
            revert VoterAlreadyVerified(_voter);
        }

        // verify voter
        voters[_voter].name = _voterName;
        voters[_voter].isVerified = true;
        for (uint256 i = 0; i < _featureVector.length; ++i) {
            voters[_voter].featureVector.push(_featureVector[i]);
        }

        emit VoterVerified(_voter);
    }

    function getVoterVerification(address _voter) external view returns (bool) {
        return voters[_voter].isVerified;
    }

    function getVoterParticipatedProposals(
        address _voter
        ) external view returns (uint256[] memory) {

        return voters[_voter].participatedProposalsId;
    }

    function getVoterSelectedOption(
        address _voter,
        uint256 _proposalId
        ) external view returns (string memory) {

        return voters[_voter].selectedOption[_proposalId];
    }

    function getVoterCreatedProposals(
        address _voter
        ) external view returns (uint256[] memory) {

        return voters[_voter].createdProposalsId;
    }

    function addUserParticipatedProposal(
        address _voter,
        uint256 _proposalId,
        string calldata _selectedOption) external {

        voters[_voter].participatedProposalsId.push(_proposalId);
        voters[_voter].selectedOption[_proposalId] = _selectedOption;
    }

    function addUserCreatedProposal(
        address _voter,
        uint256 _proposalId
        ) external {
        
        voters[_voter].createdProposalsId.push(_proposalId);
    }

}
