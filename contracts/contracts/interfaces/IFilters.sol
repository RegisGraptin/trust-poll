// SPDX-License-Identifier: BSD-3-Clause-Clear
pragma solidity ^0.8.24;

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
