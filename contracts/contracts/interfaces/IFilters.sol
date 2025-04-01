// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

// TODO: update naming + DOC + Test

/// @notice List of all types managed.
enum MetadataType {
    BOOLEAN,
    UINT256
}

/// @notice List of operators available.
/// @dev When adding a new operator, you will have to add the expected mapping with the type
///      and the expected behaviour to have when the filter operation is applied.
enum FilterOperator {
    LargerThan,
    SmallerThan,
    EqualTo
}

/// @notice Filter that can be applied on an encrypted metadata.
struct Filter {
    FilterOperator verifier;
    bytes value;
}

/// @title Metadata Verifier
/// Apply filtering operation on encrypted metadata.
/// Notice that all the metadata are encrypted and, at no point, we can decypher them.
contract MetadataVerifier {
    error InvalidFilterParameter();
    error UnmanagedType();
    error UnmanagedOperator();

    // Nested mapping to track allowed verifiers per metadata type
    mapping(MetadataType => mapping(FilterOperator => bool)) public isOperationAllowed;

    constructor() {
        // UINT256 supports all verifiers
        isOperationAllowed[MetadataType.UINT256][FilterOperator.LargerThan] = true;
        isOperationAllowed[MetadataType.UINT256][FilterOperator.SmallerThan] = true;
        isOperationAllowed[MetadataType.UINT256][FilterOperator.EqualTo] = true;

        // BOOLEAN only supports equality checks
        isOperationAllowed[MetadataType.BOOLEAN][FilterOperator.EqualTo] = true;
    }

    /// @notice Verify we can applied the input filters on the metadata.
    /// @dev It should revert if the filters are invalid.
    /// @param metadataType List of metadata's type.
    /// @param filter Filters we want to applied.
    function validateFilter(MetadataType[] calldata metadataType, Filter[][] calldata filter) external view {
        for (uint256 i = 0; i < metadataType.length; i++) {
            for (uint256 j = 0; j < filter[i].length; j++) {
                if (!isOperationAllowed[metadataType[i]][filter[i][j].verifier]) {
                    revert InvalidFilterParameter();
                }
            }
        }
    }

    /// @notice Apply a filter on a metadata.
    /// @param filter Filter we want to applied.
    /// @param userData User metadata.
    /// @return isValid Returns an encrypted true value when the user metadata matches the input filter.
    function _applyFilter(Filter memory filter, MetadataType metadataType, uint256 userData) internal returns (ebool) {
        // FIXME: need types here, as can be bool or euint256 not the same operation

        ebool isVerified;

        FilterOperator _filterOperator = filter.verifier;

        // FIXME: not sure we can have "dynamic" types in solidity

        // Decode the value using the type
        if (metadataType == MetadataType.BOOLEAN) {
            // TODO:
        } else if (metadataType == MetadataType.UINT256) {
            // TODO:
        } else {
            revert UnmanagedType();
        }

        // TODO: Depending of th number of data, we can have a huge cost here
        // by doing abi.decode() and asEuint256 operation.
        // Need to think a smarter approach, maybe?

        if (_filterOperator == FilterOperator.LargerThan) {
            euint256 eVal = TFHE.asEuint256(abi.decode(filter.value, (uint256)));
            euint256 eUsr = euint256.wrap(userData);
            isVerified = TFHE.gt(eUsr, eVal);
        } else if (_filterOperator == FilterOperator.SmallerThan) {
            euint256 eVal = TFHE.asEuint256(abi.decode(filter.value, (uint256)));
            euint256 eUsr = euint256.wrap(userData);
            isVerified = TFHE.lt(eUsr, eVal);
        } else {
            revert UnmanagedOperator();
        }

        return isVerified;
    }

    /// @notice Apply a list of filters on the metadata
    /// @dev When calling this function, we assume the filters are valid and can be applied regarding the metadata type.
    /// @param filters Filters we want to applied.
    /// @param userMetadata User metadata to be verified.
    /// @return isValid Returns an encrypted true value when the user metadata matches all the filters.
    function applyFilterOnMetadata(
        Filter[][] memory filters,
        MetadataType[] memory metadataTypes,
        uint256[] memory userMetadata
    ) external returns (ebool) {
        // By default, it is accepted
        ebool isValid = TFHE.asEbool(true);

        for (uint256 i = 0; i < filters.length; i++) {
            // Apply the filter on the user metadata
            for (uint256 j = 0; j < filters[i].length; j++) {
                isValid = TFHE.and(isValid, _applyFilter(filters[i][j], metadataTypes[i], userMetadata[i]));
            }
        }

        return isValid;
    }
}
