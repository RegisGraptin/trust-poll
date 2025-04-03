// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

import { MetadataType, Filter } from "./IFilter.sol";

enum SurveyType {
    POLLING,
    BENCHMARK
}

struct SurveyParams {
    string surveyPrompt;
    SurveyType surveyType;
    bool isWhitelisted; // Indicates if the survey is restricted to a whitelisted users
    bytes32 whitelistRootHash; // Merkle root hash for allowlist verification (if restricted)
    uint256 surveyEndTime; // UNIX timestamp when survey closes
    uint256 minResponseThreshold; // Minimum number of responses required before analysis/reveal
    MetadataType[] metadataTypes; // List of metadata requirements from participants
    Filter[][] constraints; // Constraints defining a valid metadata
}

struct SurveyData {
    uint256 currentParticipants; // Number of participants
    euint256 encryptedResponses; // Encrypted survey data
    uint256 finalResult; // Final decrypted result
    bool isCompleted; // Indicate if the survey processing is completed
    bool isValid; // Indicate if we had enough participants
}

struct VoteData {
    address userAddress;
    euint256 data; // Encrypted entry
    uint256[] metadata; // Associated metadata
    bool isValid; // Match the survey constaints to be consider valid
}

interface ISurvey {
    error InvalidSurveyId();
    error InvalidSurveyParameter(string field);
    error InvalidUserMetadata();
    error InvalidMerkleProof();

    error UserAlreadyVoted();
    error FinishedSurvey();
    error UnfinishedSurvey();
    error ResultAlreadyReveal();

    event SurveyCreated(uint256 indexed surveyId, address organizer, SurveyType surveyType, string surveyPrompt);

    event EntrySubmitted(uint256 indexed surveyId, address user);

    event ConfirmUserEntry(uint256 indexed surveyId, address indexed user, bool isValid);

    event SurveyCompleted(
        uint256 indexed surveyId,
        bool isValid,
        SurveyType surveyType,
        uint256 numberOfVotes,
        uint256 response
    );

    /// @notice Returns the survey's parameter.
    /// @dev This represents the parameter of the survey defined by the organizer.
    /// @return SurveyParams The survey parameter.
    function surveyParams(uint256 surveyId) external view returns (SurveyParams memory);

    /// @notice Returns the survey's data.
    /// @dev It represents the current survey state.
    /// @return SurveyData The survey's data.
    function surveyData(uint256 surveyId) external view returns (SurveyData memory);

    /// @notice Indicates if a user has submitted an entry for a given survey.
    /// @dev Notice that it doesn't matter whether the entry is considered valid or not.
    /// @param surveyId Id of the survey.
    /// @param user Address of the user.
    /// @return hasVoted Returns true if the user has submitted an entry to a survey.
    function hasVoted(uint256 surveyId, address user) external view returns (bool);

    /// @notice Create a new survey.
    /// @param params Parameter of the Survey.
    /// @return surveyId The id of the survey created.
    function createSurvey(SurveyParams memory params) external returns (uint256);

    /// @notice Submit a new entry for a polling/benchmark survey.
    /// @param surveyId ID of the survey.
    /// @param eInputVote Encrypted entry of the user.
    /// @param metadata Associated metadata of the user.
    /// @param inputProof Cryptographic proof verifying the validity of the encrypted inputs.
    /// @custom:requirements
    /// - User has not already voted
    /// - The survey should still be active.
    /// - The input metadata lenght should match the survey one.
    function submitEntry(
        uint256 surveyId,
        einput eInputVote,
        einput[] memory metadata,
        bytes calldata inputProof
    ) external;

    /// @notice Submit a new entry for a whitelisted polling/benchmark survey.
    /// @param surveyId ID of the survey.
    /// @param eInputVote Encrypted entry of the user.
    /// @param metadata Associated metadata of the user.
    /// @param inputProof Cryptographic proof verifying the validity of the encrypted inputs.
    /// @param whitelistProof Merkle proof path to validate to confirm whitelisted user.
    /// @custom:requirements
    /// - User should be whitelisted and the merkle proof should be validated.
    /// - User has not already voted
    /// - The survey should still be active.
    /// - The input metadata lenght should match the survey one.
    function submitWhitelistedEntry(
        uint256 surveyId,
        einput eInputVote,
        einput[] memory metadata,
        bytes calldata inputProof,
        bytes32[] memory whitelistProof
    ) external;

    /// @notice Reveal the survey result.
    /// @dev When revealing the result of the survey, we need to ensure that we have reach the
    /// threshold number of participants, to avoid any leak in the vote.
    /// When the threshold is reached, we can rely on the Zama Gateway mechanism to decypher the vote.
    /// @param surveyId ID of the survey.
    /// @custom:requirements
    /// - The survey should be finished, meaning we reach the end of the submission time.
    function revealResults(uint256 surveyId) external;
}
