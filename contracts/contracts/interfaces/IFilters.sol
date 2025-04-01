// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

enum MetadataType {
    BOOLEAN,
    UINT256
}

enum VerifierType {
    LargerThan,
    SmallerThan,
    EqualTo
}

struct Filter {
    VerifierType verifier;
    bytes value;
}

// TODO: update naming + DOC + Test
contract MetadataVerifier {
    // Nested mapping to track allowed verifiers per metadata type
    mapping(MetadataType => mapping(VerifierType => bool)) public isOperationAllowed;

    constructor() {
        // UINT256 supports all verifiers
        isOperationAllowed[MetadataType.UINT256][VerifierType.LargerThan] = true;
        isOperationAllowed[MetadataType.UINT256][VerifierType.SmallerThan] = true;
        isOperationAllowed[MetadataType.UINT256][VerifierType.EqualTo] = true;

        // BOOLEAN only supports equality checks
        isOperationAllowed[MetadataType.BOOLEAN][VerifierType.EqualTo] = true;
    }

    // Validate a Filter against a MetadataType
    function validateFilter(MetadataType[] calldata metadataType, Filter[][] calldata filter) external view {
        for (uint256 i = 0; i < metadataType.length; i++) {
            for (uint256 j = 0; j < filter[i].length; j++) {
                require(isOperationAllowed[metadataType[i]][filter[i][j].verifier], "Invalid filter");
            }
        }
    }

    function _applyFilter(Filter memory filter, uint256 userData) internal returns (ebool) {
        ebool isVerified;

        VerifierType _verifierType = filter.verifier;

        if (_verifierType == VerifierType.LargerThan) {
            // TODO: Depending of th number of data, we can have a huge cost here
            // by doing abi.decode() and asEuint256 operation.
            // Need to think a smarter approach, maybe?
            euint256 eVal = TFHE.asEuint256(abi.decode(filter.value, (uint256)));

            euint256 eUsr = euint256.wrap(userData);

            isVerified = TFHE.gt(eUsr, eVal);
        } else if (_verifierType == VerifierType.SmallerThan) {
            // TODO:
        } else {
            // FIXME:
        }

        return isVerified;
    }

    function applyFilterOnMetadata(Filter[][] memory filters, uint256[] memory userFilter) external returns (ebool) {
        // By default, it is accepted
        ebool isValid = TFHE.asEbool(true);

        // In this part, we can assume the filter are valid, as we will verify them before
        for (uint256 i = 0; i < filters.length; i++) {
            // Apply the filter on the user metadata
            for (uint256 j = 0; j < filters[i].length; j++) {
                isValid = TFHE.and(isValid, _applyFilter(filters[i][j], userFilter[i]));
            }
        }

        return isValid;
    }
}
