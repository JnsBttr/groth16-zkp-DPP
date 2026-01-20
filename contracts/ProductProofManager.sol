// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

contract ProductProofManager {
    // --- Custom errors (gas-efficient) ---
    error OnlyOwner(); // access control violation
    error ZeroAddress(); // zero address not allowed
    error NotAContract(); // address has no code
    error VerifierNotRegistered(); // missing verifier for proofType
    error ProofNotValid(); // input[0] must be 1
    error AlreadyVerified(); // productHash already verified globally
    error VerificationInProgress(); // per-product reentrancy lock active
    error VerificationFailed(); // verifier call failed or returned false

    mapping(bytes32 => address) public verifiers; // proofType => verifier address
    uint256 public proofCounter; // sequential proof id
    mapping(uint256 => bool) public verifiedHashes; // productHash => verified flag

    mapping(uint256 => bool) private verifying; // productHash => submission lock

    struct ProductProof {
        bytes32 proofType; // type key used to select verifier
        address submitter; // msg.sender who submitted the proof
        uint256 product_hash; // Poseidon hash of product attributes
        uint256 submitted_at; // block timestamp of submission
    }

    mapping(uint256 => ProductProof) public proofs; // proofId => ProductProof

    address public owner; // contract admin

    modifier onlyOwner() {
        if (msg.sender != owner) revert OnlyOwner(); // restrict to owner
        _; // continue execution
    }

    event ProofSubmitted(uint256 indexed proofId, address indexed submitter, bytes32 indexed proofType); // emitted on successful submission
    event VerifierRegistered(bytes32 indexed proofType, address verifier); // emitted on register/update verifier
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner); // emitted on owner change

    constructor() {
        owner = msg.sender; // set deployer as owner
        emit OwnershipTransferred(address(0), msg.sender); // announce initial owner
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) revert ZeroAddress(); // disallow zero owner
        emit OwnershipTransferred(owner, newOwner); // emit before change
        owner = newOwner; // update owner
    }

    function registerVerifier(bytes32 proofType, address verifier) external onlyOwner {
        if (verifier == address(0)) revert ZeroAddress(); // must be non-zero
        if (verifier.code.length == 0) revert NotAContract(); // must be a contract
        verifiers[proofType] = verifier; // set verifier
        emit VerifierRegistered(proofType, verifier); // log change
    }

    // input layout: [is_valid, product_hash]
    function submitProof(
        bytes32 proofType, // verifier key
        uint256[2] calldata a, // groth16 a
        uint256[2][2] calldata b, // groth16 b
        uint256[2] calldata c, // groth16 c
        uint256[2] calldata input // public inputs
    ) external {
        if (input[0] != 1) revert ProofNotValid(); // must signal valid proof

        uint256 productHash = input[1]; // extract product hash
        if (verifiedHashes[productHash]) revert AlreadyVerified(); // enforce single verification per product across all types (original behavior)
        if (verifying[productHash]) revert VerificationInProgress(); // prevent reentrant duplicate on same product

        address verifier = verifiers[proofType]; // load verifier address
        if (verifier == address(0)) revert VerifierNotRegistered(); // verifier must exist

        verifying[productHash] = true; // set per-product lock before external call

        (bool ok, bytes memory ret) = verifier.staticcall( // enforce read-only verifier
            abi.encodeWithSelector(
                IVerifier.verifyProof.selector,
                a,
                b,
                c,
                input
            )
        ); // low-level call for safety
        bool verified = ok && ret.length >= 32 && abi.decode(ret, (bool)); // robust decode to bool

        verifying[productHash] = false; // clear lock; revert below clears state anyway

        if (!verified) revert VerificationFailed(); // bubble failure

        proofs[proofCounter] = ProductProof({ // store proof metadata
            proofType: proofType, // set type
            submitter: msg.sender, // set submitter
            product_hash: productHash, // set product hash
            submitted_at: block.timestamp // set timestamp
        }); // end struct init

        verifiedHashes[productHash] = true; // mark product as verified (global, as in original)

        emit ProofSubmitted(proofCounter, msg.sender, proofType); // emit success

        unchecked { proofCounter++; } // gas save; overflow unrealistic
    }

    function isProductVerified(uint256 productHash) external view returns (bool) {
        return verifiedHashes[productHash]; // read verification flag
    }
}

interface IVerifier {
    function verifyProof(
        uint256[2] calldata a, // groth16 a
        uint256[2][2] calldata b, // groth16 b
        uint256[2] calldata c, // groth16 c
        uint256[2] calldata input // [is_valid, product_hash]
    ) external view returns (bool); // returns success flag
}
