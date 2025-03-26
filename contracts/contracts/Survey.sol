// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

import { SepoliaZamaFHEVMConfig } from "fhevm/config/ZamaFHEVMConfig.sol";
import { SepoliaZamaGatewayConfig } from "fhevm/config/ZamaGatewayConfig.sol";

import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import { MetadataType } from "./interfaces/IMetadata.sol";

import { ISurvey, SurveyParams, SurveyData, VoteData } from "./interfaces/ISurvey.sol";
import { IAnalyze, QueryData, Filter, VerifierType } from "./interfaces/IAnalyze.sol";

contract Survey is ISurvey, IAnalyze, SepoliaZamaFHEVMConfig, SepoliaZamaGatewayConfig, GatewayCaller {
    uint256 private _surveyIds;

    mapping(uint256 => SurveyParams) public surveyParams;
    mapping(uint256 => SurveyData) public surveyData;

    mapping(uint256 => VoteData[]) voteData;
    mapping(uint256 => mapping(address => bool)) public hasVoted;

    function createSurvey(SurveyParams memory params) external returns (uint256) {
        // FIXME: check params value

        euint256 eResponses = TFHE.asEuint256(0);
        TFHE.allowThis(eResponses);

        surveyParams[_surveyIds] = params;
        surveyData[_surveyIds] = SurveyData({
            participantCount: 0,
            encryptedResponses: eResponses,
            decryptedResponses: 0 // FIXME: add indicator for decrypted or not
        });
        _surveyIds++;

        // TODO: emit event

        return _surveyIds - 1;
    }

    /// metadata parameter will be a list of encrypted arguments that should match the user type
    /// We could have [euint256, ebool, euint8, ...] input
    function _submitEntry(
        uint256 surveyId,
        einput eInputVote,
        einput[] memory metadata,
        bytes calldata inputProof,
        bytes32[] memory whitelistProof
    ) internal {
        require(surveyId < _surveyIds, "invalid");
        require(!hasVoted[surveyId][msg.sender], "already_voted");
        require(surveyParams[surveyId].metadataTypes.length == metadata.length, "Invalid length");

        // Check if user is whitelisted
        if (surveyParams[surveyId].isWhitelisted) {
            bytes32 leaf = keccak256(bytes.concat(keccak256(abi.encode(msg.sender))));
            require(
                MerkleProof.verify(whitelistProof, surveyParams[surveyId].whitelistRootHash, leaf),
                "Invalid proof"
            );
        }

        // Check metadata type
        uint256[] memory checkedMetadatValue = new uint256[](surveyParams[surveyId].metadataTypes.length);
        for (uint256 i = 0; i < surveyParams[surveyId].metadataTypes.length; i++) {
            MetadataType _type = surveyParams[surveyId].metadataTypes[i];

            if (_type == MetadataType.BOOLEAN) {
                ebool val = TFHE.asEbool(metadata[i], inputProof);
                checkedMetadatValue[i] = ebool.unwrap(val);

                TFHE.allowThis(val); // FIXME:
            } else if (_type == MetadataType.UINT256) {
                euint256 val = TFHE.asEuint256(metadata[i], inputProof);
                checkedMetadatValue[i] = euint256.unwrap(val);

                TFHE.allowThis(val); // FIXME:
            }
        }

        // (v1) no verification on the metadata yet!

        // Add a new vote
        euint256 eVote = TFHE.asEuint256(eInputVote, inputProof);
        TFHE.allowThis(eVote); // TODO: Need to have authorization to do operation

        // TODO:: Do we need to authorize user access or can skip it?

        surveyData[surveyId].encryptedResponses = TFHE.add(surveyData[surveyId].encryptedResponses, eVote);
        surveyData[surveyId].participantCount++;

        // TODO :: Understand more deeply what does the allow this
        TFHE.allowThis(surveyData[surveyId].encryptedResponses);

        // Save vote info
        VoteData memory _voteData = VoteData({ data: eVote, metadata: checkedMetadatValue });
        voteData[surveyId].push(_voteData);

        // Add user to the hasvoted list
        hasVoted[surveyId][msg.sender] = true;

        // Emit event
    }

    function submitEntry(
        uint256 surveyId,
        einput eInputVote,
        einput[] memory metadata,
        bytes calldata inputProof
    ) external {
        // FIXME: protect and double check no by pass whitelist or whatever
        _submitEntry(surveyId, eInputVote, metadata, inputProof, new bytes32[](0));
    }

    function submitWhitelistedEntry(
        uint256 surveyId,
        einput eInputVote,
        einput[] memory metadata,
        bytes calldata inputProof,
        bytes32[] memory whitelistProof
    ) external {
        _submitEntry(surveyId, eInputVote, metadata, inputProof, whitelistProof);
    }

    mapping(uint256 requestId => uint256 surveyId) gatewayRequestId;

    mapping(uint256 surveyId => uint256 result) surveyResult;

    function revealResults(uint256 surveyId) external {
        // FIXME: add condition
        // require(block.timestamp == 0 || block.timestamp > endVoteTime, "VOTE_PENDING");

        uint256[] memory cts = new uint256[](1);
        cts[0] = Gateway.toUint256(surveyData[surveyId].encryptedResponses);
        uint256 _requestId = Gateway.requestDecryption(
            cts,
            this.gatewayDecryptVoteResult.selector,
            0,
            block.timestamp + 100,
            false
        );

        gatewayRequestId[_requestId] = surveyId;
    }

    //////////////////////////////////////////////////////////////////
    /// Analyse the data
    //////////////////////////////////////////////////////////////////

    uint256 private _queryIds;
    mapping(uint256 => QueryData) public queryData;

    function createQuery(uint256 voteId, Filter[][] memory params) external returns (uint256) {
        // FIXME: add constraint on the current vote.
        // Do we want to add constraint on the current vote?
        // Min threshold maybe?

        // // FIXME: Need to verify the input filter compared to the type
        // Filter[][] storage _filters = new Filter[][](params.length);
        // for (uint256 i = 0; i < params.length; i++) {
        //     _filters[i] = new Filter[](params[i].length);
        //     for (uint256 j = 0; j < params[i].length; j++) {
        //         // Copy individual Filter struct
        //         _filters[i][j] = params[i][j];
        //     }
        // }

        euint256 pendingResult = TFHE.asEuint256(0);
        euint256 numberOfSelected = TFHE.asEuint256(0);

        // TODO: seems not mandatory, need more info
        // TFHE.allowThis(pendingResult);
        // TFHE.allowThis(numberOfSelected);

        // FIXME: here issue ----
        queryData[_queryIds] = QueryData({
            voteId: voteId,
            filters: params,
            pendingResult: pendingResult,
            numberOfSelected: numberOfSelected,
            cursor: 0,
            isFinished: false,
            isSucceed: false,
            selectedCount: 0,
            result: 0
        });

        _queryIds++;

        // FIXME: emit event

        return _queryIds - 1;
    }

    function _applyFilter(Filter memory filter, uint256 userData) internal returns (ebool) {
        // FIXME: when building I have an issue here as it seems I cannot build it in legacy mode
        // "--via-ir" need to provide this option.

        ebool isVerified;
        // TFHE.allowThis(isVerified);

        VerifierType _verifierType = filter.verifier;

        if (_verifierType == VerifierType.LargerThan) {
            // TODO:

            // TODO: for tomorrow need to see how I want to handle those value.
            // Should the analyst pass it in clear
            // Or should it be enctrypted
            // Nevertheless when comparing it should be the same type

            // FIXME: to be done here maybe!!
            euint256 eVal = TFHE.asEuint256(abi.decode(filter.value, (uint256))); // TFHE.asEuint256();

            // euint256 eUsr = TFHE.asEuint256(userData); // euint256.wrap(userData); // TFHE.asEuint256();
            euint256 eUsr = euint256.wrap(userData);
            // TFHE.allowThis(eUsr);

            isVerified = TFHE.gt(eUsr, eVal);
        } else if (_verifierType == VerifierType.SmallerThan) {
            // TODO:
        } else {
            // FIXME:
        }

        return isVerified;
    }

    function _applyMetadataFilter(Filter[][] memory filters, uint256[] memory userFilter) internal returns (ebool) {
        // By default, it is accepted
        ebool isValid = TFHE.asEbool(true);
        // TFHE.allowThis(isValid);

        // In this part, we can assume the filter are valid, as we will verify them before
        for (uint256 i = 0; i < filters.length; i++) {
            // Apply the filter on the user metadata
            for (uint256 j = 0; j < filters[i].length; j++) {
                isValid = TFHE.and(isValid, _applyFilter(filters[i][j], userFilter[i]));

                // ebool isVerified;

                // // VerifierType _verifierType = filters[i][j].verifier;

                // if (filters[i][j].verifier == VerifierType.LargerThan) {
                //     // TODO:

                //     euint256 eVal = euint256.wrap(abi.decode(filters[i][j].value, (uint256))); // TFHE.asEuint256();
                //     // euint256 eUsr = TFHE.asEuint256(userData); // euint256.wrap(userData); // TFHE.asEuint256();
                //     euint256 eUsr = euint256.wrap(userFilter[i]);

                //     isVerified = TFHE.gt(eUsr, eVal);
                // } else if (filters[i][j].verifier == VerifierType.SmallerThan) {
                //     // TODO:
                // } else {
                //     // FIXME:
                // }

                // isValid = TFHE.and(isValid, isVerified);
            }
        }

        return isValid;
    }

    // FIXME: Possibility to add another functions that will take a integer as parameter
    // allowing us to handle the iteration logic with a custom integer.
    function executeQuery(uint256 queryId) external {
        require(queryId < _queryIds, "INVALID_QUERY_ID");
        // FIXME: Other things in mind??

        uint256 voteId = queryData[queryId].voteId;

        uint256 limit = 10;
        uint256 start = queryData[queryId].cursor;

        // FIXME: Simplify all the code
        // Please: first check that you understand the allowthis --> which one do I need!
        // To avoid potential leaks!

        while (
            queryData[queryId].cursor < start + limit && // Limit the iterator
            queryData[queryId].cursor < voteData[voteId].length // Still data to read
        ) {
            // Process
            VoteData memory data = voteData[voteId][queryData[queryId].cursor];

            // Apply the filter
            ebool takeIt = _applyMetadataFilter(queryData[queryId].filters, data.metadata);
            // TFHE.allowThis(takeIt);
            // ebool takeIt = TFHE.asEbool(true);

            euint256 one = TFHE.asEuint256(1);
            euint256 zero = TFHE.asEuint256(0);

            euint256 increment = TFHE.select(takeIt, one, zero);
            euint256 addValue = TFHE.select(takeIt, data.data, zero);

            queryData[queryId].numberOfSelected = TFHE.add(queryData[queryId].numberOfSelected, increment);

            queryData[queryId].pendingResult = TFHE.add(queryData[queryId].pendingResult, addValue);

            queryData[queryId].cursor++;
        }

        // In case of last iteration - Potentially reveal the value
        // FIXME: handle it

        if (queryData[queryId].cursor >= voteData[voteId].length) {
            // FIXME: double check that we do not have a potential leak
            // Else we assume that we reach a correct threshold and does not impact privacy

            // TFHE.allowThis(queryData[queryId].numberOfSelected);
            // TFHE.allowThis(queryData[queryId].pendingResult);

            uint256[] memory cts = new uint256[](2);
            cts[0] = Gateway.toUint256(queryData[queryId].numberOfSelected);
            cts[1] = Gateway.toUint256(queryData[queryId].pendingResult);
            uint256 _requestId = Gateway.requestDecryption(
                cts,
                this.gatewayDecryptAnalyse.selector, // FIXME: naming
                0,
                block.timestamp + 100,
                false
            );

            gatewayRequestId[_requestId] = queryId;
        }
    }

    //////////////////////////////////////////////////////////////////
    /// Gateway Callback Functions
    //////////////////////////////////////////////////////////////////

    /// Gateway Callback - Decrypt the vote result
    function gatewayDecryptVoteResult(uint256 requestId, uint256 result) public onlyGateway {
        uint256 surveyId = gatewayRequestId[requestId];
        surveyData[surveyId].decryptedResponses = result;

        // emit GatewayTotalValueRequested(_gatewayProcess[requestId], result);
    }

    ///
    function gatewayDecryptAnalyse(
        uint256 requestId,
        uint256 numberOfSelected,
        uint256 pendingResult
    ) public onlyGateway {
        // queryData[requestId].isFinished

        uint256 queryId = gatewayRequestId[requestId];

        // FIXME: have better naming please
        queryData[queryId].selectedCount = numberOfSelected;
        queryData[queryId].result = pendingResult;

        // emit event
    }
}
