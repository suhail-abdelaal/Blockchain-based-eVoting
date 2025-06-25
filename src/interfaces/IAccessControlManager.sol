// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

interface IAccessControlManager {

    function onlyAdmin(address account) external view;
    function onlyVerifiedVoter() external view;
    function onlyVerifiedAddr(address voter) external view;
    function onlyAuthorizedCaller(address caller) external view;
    function hasRole(
        bytes32 role,
        address account
    ) external view returns (bool);
    function grantRole(bytes32 role, address account) external;
    function revokeRole(bytes32 role, address account) external;
    function verifyVoter(address voter) external;
    function isVoterVerified(address voter) external view returns (bool);
    function getADMIN_ROLE() external view returns (bytes32);
    function getVERIFIED_VOTER_ROLE() external view returns (bytes32);
    function getAUTHORIZED_CALLER_ROLE() external view returns (bytes32);
}
