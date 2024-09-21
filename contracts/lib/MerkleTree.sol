// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

library MerkleTree {
  function hashLeafPairs(bytes32 left, bytes32 right) public pure returns (bytes32 _hash) {
    assembly {
      switch lt(left, right)
      case 0 {
        mstore(0x0, right)
        mstore(0x20, left)
      }
      default {
        mstore(0x0, left)
        mstore(0x20, right)
      }
      _hash := keccak256(0x0, 0x40)
    }
  }

  /**
   *
   * PROOF VERIFICATION *
   *
   */
  function verifyProof(bytes32 root, bytes32[] memory proof, bytes32 valueToProve) external pure returns (bool) {
    // proof length must be less than max array size
    bytes32 rollingHash = valueToProve;
    uint256 length = proof.length;
    unchecked {
      for (uint256 i = 0; i < length; ++i) {
        rollingHash = hashLeafPairs(rollingHash, proof[i]);
      }
    }
    return root == rollingHash;
  }
}
