// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

import { ISurvey, SurveyParams, SurveyData, VoteData } from "./interfaces/ISurvey.sol";

contract Survey is ISurvey {
    uint256 private _surveyIds;

    mapping(uint256 => SurveyParams) surveyParams;
    mapping(uint256 => SurveyData) surveyData;

    mapping(uint256 => VoteData[]) voteData;
    mapping(uint256 => mapping(address => bool)) hasVoted;

    function createSurvey(SurveyParams memory params) external returns (uint256) {
        // FIXME: check params value

        surveyParams[_surveyIds] = params;
        surveyData[_surveyIds] = SurveyData({ participantCount: 0, encryptedResponses: TFHE.asEuint256(0) });
        _surveyIds++;

        // TODO: emit event

        return _surveyIds - 1;
    }

    /// metadata parameter will be a list of encrypted arguments that should match the user type
    /// We could have [euint256, ebool, euint8, ...] input
    function submitEntry(
        uint256 surveyId,
        einput eInputVote,
        uint256[] memory metadata,
        bytes calldata inputProof
    ) external {
        require(surveyId < _surveyIds, "invalid");
        require(!hasVoted[surveyId][msg.sender], "already_voted");
        // FIXME:

        // Check metadata type

        // (v1) no verification on the metadata yet!

        // Add a new vote
        euint256 eVote = TFHE.asEuint256(eInputVote, inputProof);
        surveyData[surveyId].encryptedResponses = TFHE.add(surveyData[surveyId].encryptedResponses, eVote);
        surveyData[surveyId].participantCount++;

        // Save vote info
        VoteData memory _voteData = VoteData({ data: eVote, metadata: metadata });
        voteData[surveyId].push(_voteData);

        // Add user to the hasvoted list
        hasVoted[surveyId][msg.sender] = true;

        // Emit event
    }

    function revealResults(uint256 surveyId) external {}
}
