// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

import "fhevm/lib/TFHE.sol";
import "fhevm/gateway/GatewayCaller.sol";

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
    EqualTo,
    DifferentTo
}

/// @notice Filter that can be applied on an encrypted metadata.
/// @dev On the filter, we can customize it as we want, as we could have any kind of arguments
/// stored with bytes. However, this customization required us to decode the arguments, which
/// can lead to an additional costs for the request.
struct Filter {
    FilterOperator verifier;
    bytes value;
}
