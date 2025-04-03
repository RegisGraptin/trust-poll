// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

import { SepoliaZamaFHEVMConfig } from "fhevm/config/ZamaFHEVMConfig.sol";

import { Filter, MetadataType, FilterOperator } from "./interfaces/IFilter.sol";

/// @title Metadata Verifier
/// Apply filtering operation on encrypted metadata.
/// Notice that all the metadata are encrypted and, at no point, we can decypher them.
contract MetadataVerifier is SepoliaZamaFHEVMConfig {
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
        isOperationAllowed[MetadataType.UINT256][FilterOperator.DifferentTo] = true;

        // BOOLEAN only supports equality checks
        isOperationAllowed[MetadataType.BOOLEAN][FilterOperator.EqualTo] = true;
        isOperationAllowed[MetadataType.BOOLEAN][FilterOperator.DifferentTo] = true;
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

    function _applyBooleanFilter(Filter memory filter, uint256 userData) internal returns (ebool) {
        ebool isVerified;
        FilterOperator _filterOperator = filter.verifier;

        ebool eVal = TFHE.asEbool(abi.decode(filter.value, (bool)));
        ebool eUsr = ebool.wrap(userData);

        if (_filterOperator == FilterOperator.EqualTo) {
            isVerified = TFHE.and(eUsr, eVal);
        } else if (_filterOperator == FilterOperator.DifferentTo) {
            isVerified = TFHE.xor(eUsr, eVal);
        } else {
            revert UnmanagedOperator();
        }

        return isVerified;
    }

    function _applyUint256Filter(Filter memory filter, uint256 userData) internal returns (ebool) {
        ebool isVerified;
        FilterOperator _filterOperator = filter.verifier;

        euint256 eVal = TFHE.asEuint256(abi.decode(filter.value, (uint256)));
        euint256 eUsr = euint256.wrap(userData);

        if (_filterOperator == FilterOperator.LargerThan) {
            isVerified = TFHE.gt(eUsr, eVal);
        } else if (_filterOperator == FilterOperator.SmallerThan) {
            isVerified = TFHE.lt(eUsr, eVal);
        } else if (_filterOperator == FilterOperator.EqualTo) {
            isVerified = TFHE.eq(eUsr, eVal);
        } else if (_filterOperator == FilterOperator.DifferentTo) {
            isVerified = TFHE.ne(eUsr, eVal);
        } else {
            revert UnmanagedOperator();
        }

        return isVerified;
    }

    /// @notice Apply a filter on a metadata.
    /// @param filter Filter we want to applied.
    /// @param userData User metadata.
    /// @return isValid Returns an encrypted true value when the user metadata matches the input filter.
    function _applyFilter(Filter memory filter, MetadataType metadataType, uint256 userData) internal returns (ebool) {
        if (metadataType == MetadataType.BOOLEAN) {
            return _applyBooleanFilter(filter, userData);
        } else if (metadataType == MetadataType.UINT256) {
            return _applyUint256Filter(filter, userData);
        } else {
            revert UnmanagedType();
        }
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

        TFHE.allow(isValid, msg.sender);
        return isValid;
    }
}
