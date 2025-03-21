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

    function getVoterVerification(address _voter) public view returns (bool) {
        return voters[_voter].isVerified;
    }
}
