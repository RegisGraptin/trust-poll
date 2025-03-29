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
    uint256 lastDecryptedCount;
    uint256 decryptedResponses;
}

// FIXME: should merge (surveyParams & SurveyData)
// Or have it more explicitly defined

struct SurveyParams {
    string surveyPrompt;
    SurveyType surveyType;
    /// @notice Indicates if the survey is restricted to a whitelisted users
    bool isWhitelisted;
    /// @notice Merkle root hash for allowlist verification (if restricted)
    bytes32 whitelistRootHash;
    /// @notice Number of participant
    uint256 numberOfParticipants;
    /// @notice UNIX timestamp when survey automatically closes
    uint256 surveyEndTime;
    /// @notice Minimum number of responses required before analysis/reveal
    uint256 minResponseThreshold;
    /// @notice List of metadata requirements from participants
    MetadataType[] metadataTypes;
    /// @notice Authorize to reveal running survey result
    bool authorizePendingReveal;
    /// @notice Authorize to do analysis when the survey is still running
    bool authorizePendingAnalyze;
}

struct VoteData {
    euint256 data;
    uint256[] metadata;
}

interface ISurvey {
    error InvalidSurveyPrompt();
    error InvalidSurveyWhitelist();
    error InvalidEndTime();
    error InvalidResponseThreshold();
    error InvalidMetadata();

    error InvalidNumberOfParticipants(); // TODO : Adjust naming

    error ThresholdNeeded(); // TODO: better naming please

    error InvalidRevealAction();

    error UnfinishedSurveyPeriod();

    event SurveyCreated(uint256 indexed surveyId, address organizer, SurveyType surveyType, string surveyPrompt);

    event EntrySubmitted(uint256 indexed surveyId, address user);

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
