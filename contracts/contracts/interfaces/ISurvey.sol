// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

import { MetadataType } from "./IMetadata.sol";

enum SurveyType {
    POLLING,
    BENCHMARK
}

struct SurveyData {
    uint256 participantCount; // Number of participants
    euint256 encryptedResponses; // Encrypted survey data
}

struct SurveyParams {
    string surveyPrompt;
    SurveyType surveyType;
    bool isWhitelisted;
    bytes32 whitelistRootHash;
    uint256 surveyEndTime;
    uint256 responseThreshold;
    MetadataType[] metadataTypes;
}

struct VoteData {
    euint256 data;
    uint256[] metadata;
}

interface ISurvey {
    /// @notice Create a new survey.
    /// @param params Parameter of the Survey.
    /// @return surveyId The id of the survey.
    function createSurvey(SurveyParams memory params) external returns (uint256);

    function submitEntry(
        uint256 surveyId,
        einput eInputVote,
        uint256[] memory metadata,
        bytes calldata inputProof
    ) external;

    function revealResults(uint256 surveyId) external;
}
