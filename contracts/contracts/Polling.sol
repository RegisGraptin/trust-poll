// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

// import "fhevm/lib/TFHE.sol";
// import "fhevm/gateway/GatewayCaller.sol";

// import { SepoliaZamaFHEVMConfig } from "fhevm/config/ZamaFHEVMConfig.sol";
// import { SepoliaZamaGatewayConfig } from "fhevm/config/ZamaGatewayConfig.sol";

// import { ISurvey } from "./interfaces/ISurvey.sol";

// // FIXME: Here we manage a single vote
// // Could we hanlde the switch to have multiple one?
// // How can we leverage this vote to incentivate users

// /// Create a simple polling contract allowing the user to vote on "yes" or "no".
// contract SimplePolling is ISurvey, SepoliaZamaFHEVMConfig, SepoliaZamaGatewayConfig, GatewayCaller {
//     uint256 private _voteIds;

//     mapping(address => bool) hasVoted;

//     // In case of endVoteTime = 0 we do not use it as a verification
//     uint256 public endVoteTime;
//     uint256 public numberOfParticipants;

//     uint256 public voteResult;

//     euint8 totalVote;

//     mapping(uint256 id => SurveyParams) public params;

//     enum Type {
//         UINT256
//     }
//     // , uint128, uint64 }

//     Type[] public types; // Dynamic array to store types

//     mapping(uint256 voteId => string attribute) public metadataAttribute;
//     mapping(uint256 voteId => Type acceptedType) public metadataType;
//     mapping(Type => VerifierType[]) public typeVerifiers;

//     constructor(uint256 _endVoteTime) {
//         endVoteTime = _endVoteTime;
//     }

//     // bytes32[]

//     // Constructor definition
//     // metadata = "uint8,uint8,uint8"

//     // How to compose the verification?

//     // TODO: In v2: add metadata attached to it
//     function vote(uint256 voteId, einput eVote, bytes32[] memory eMetadata, bytes calldata inputProof) external {
//         // Valid vode id
//         require(voteId < _voteIds, "INVALID_VOTE_ID");
//         require(block.timestamp == 0 || block.timestamp <= endVoteTime, "VOTE_FINISHED"); // Check vote non finished
//         require(!hasVoted[msg.sender], "ALREADY_VOTED"); // Check user has not already voted
//         // FIXME: Check metadata length
//         // FIXME: Check metadata type

//         // FIXME: additinal - based on vote type & check definition by user
//         // FIXME: check vote value [0,1]

//         euint8 eAmount = TFHE.asEuint8(eVote, inputProof);

//         totalVote = TFHE.add(totalVote, eAmount);

//         TFHE.allowThis(totalVote);

//         numberOfParticipants++;
//     }

//     function revealVote(uint256 voteId) external {
//         // FIXME: update
//         require(block.timestamp == 0 || block.timestamp > endVoteTime, "VOTE_PENDING");
//         uint256[] memory cts = new uint256[](1);
//         cts[0] = Gateway.toUint256(totalVote);
//         uint256 _requestId = Gateway.requestDecryption(
//             cts,
//             this.gatewayDecryptVoteResult.selector,
//             0,
//             block.timestamp + 100,
//             false
//         );
//         // Save id and vote
//     }

//     /// Gateway Callback - Decrypt the vote result
//     function gatewayDecryptVoteResult(uint256 requestId, uint256 result) public onlyGateway {
//         voteResult = result;
//         // emit GatewayTotalValueRequested(_gatewayProcess[requestId], result);
//     }

//     // TODO: Need to have a cursor mechanism in case too large
//     // function analyse(uint256 vodeId, Filter[][] memory params) external {}
// }
