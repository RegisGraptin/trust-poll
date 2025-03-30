// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

import { MetadataType, Filter } from "./IFilters.sol";

enum SurveyType {
    POLLING,
    BENCHMARK
}

struct SurveyParams {
    string surveyPrompt;
    SurveyType surveyType;
    bool isWhitelisted; // Indicates if the survey is restricted to a whitelisted users
    bytes32 whitelistRootHash; // Merkle root hash for allowlist verification (if restricted)
    uint256 numberOfParticipants; // Number of participant
    uint256 surveyEndTime; // UNIX timestamp when survey closes
    uint256 minResponseThreshold; // Minimum number of responses required before analysis/reveal
    MetadataType[] metadataTypes; // List of metadata requirements from participants
    Filter[][] constraints; // List of metadata contraints to defined a valid metadata
}

struct SurveyData {
    uint256 currentParticipants; // Number of participants
    euint256 encryptedResponses; // Encrypted survey data
    uint256 finalResult; // Final decrypted result
    bool isCompleted; // Indicate if the survey processing is completed
    bool isInvalid; // Indicate if we had enough participants
}

struct VoteData {
    euint256 data;
    uint256[] metadata;
}

interface ISurvey {
    error InvalidSurveyId();
    error InvalidSurveyPrompt();
    error InvalidSurveyWhitelist();
    error InvalidEndTime();
    error InvalidResponseThreshold();
    error InvalidMetadata();
    error InvalidUserMetadata(); // Doublon?
    error InvalidNumberOfParticipants(); // TODO : Adjust naming

    error ResultAlreadyReveal();
    error UnfinishedSurveyPeriod();
    error UserAlreadyVoted();

    error FinishedSurvey();
    error ThresholdNeeded(); // TODO: better naming please
    error InvalidRevealAction();

    event SurveyCreated(uint256 indexed surveyId, address organizer, SurveyType surveyType, string surveyPrompt);

    event EntrySubmitted(uint256 indexed surveyId, address user);

    event SurveyCompleted(uint256 indexed surveyId, SurveyType surveyType, uint256 numberOfVotes, uint256 response);

    /// View function
    function surveyData(uint256 surveyId) external view returns (SurveyData memory);

    function surveyParams(uint256 surveyId) external view returns (SurveyParams memory);

    /// Action function

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
