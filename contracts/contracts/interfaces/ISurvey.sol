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
    uint256 decryptedResponses;
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
    einput[] metadata;
}

interface ISurvey {
    /// @notice Create a new survey.
    /// @param params Parameter of the Survey.
    /// @return surveyId The id of the survey.
    function createSurvey(SurveyParams memory params) external returns (uint256);

    // FIXME: Create two functions - one for whitelisted and another for simple one
    // Two entrypoints but go to a single one
    // Easier on frontend integration

    function submitEntry(
        uint256 surveyId,
        einput eInputVote,
        einput[] memory metadata,
        bytes calldata inputProof
    ) external;

    function submitWhitelistedEntry(
        uint256 surveyId,
        einput eInputVote,
        einput[] memory metadata,
        bytes calldata inputProof,
        bytes32[] memory whitelistProof
    ) external;

    function revealResults(uint256 surveyId) external;

    function hasVoted(uint256 surveyId, address user) external view returns (bool);
}
