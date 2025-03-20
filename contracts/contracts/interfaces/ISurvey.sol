// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import { MetadataType } from "./IMetadata.sol";

enum SurveyType {
    POLLING,
    BENCHMARK
}

// Need to defined all the type of accepted mode
enum VoteMode {
    Time,
    Threshold,
    Participant
}

struct SurveyParams {
    uint256 endVotingTime;
    uint256 personThreshold; // FIXME: Do we need to defined a minimum?
    uint256 numberOfParticipants; // 0 -> unlimited
    VoteMode voteMode; // FIXME: nommenclatrue
    SurveyType voteType;
    MetadataType[] metadataType;
}

interface ISurvey {
    /// @notice Create a new survey.
    /// @param params Parameter of the Survey.
    /// @return surveyId The id of the survey.
    function createSurvey(SurveyParams memory params) external returns (uint256);

    function submitEntry(uint256 surveyId) external;

    function revealResults(uint256 surveyId) external;
}
