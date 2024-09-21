from web3 import Web3

class MerkleTools(object):
    def __init__(self,
        tree_height: int,
        leaves: [[str, int]],
        empty_leaf_data: [str, int],
        sort_leaves=True
    ):
        self.tree_height = tree_height
        self.tree_leaves_count = 2 ** tree_height - 1
        self.empty_leaf_data = empty_leaf_data
        self.reset_tree()
        self.init_tree(leaves)

    def init_tree(self, leaves: [[str, int]], sort_leaves=True):
        existUpperCase = False
        for leaf in leaves:
            if not leaf[0].islower():
                existUpperCase = True
                break
        if existUpperCase:
            raise Exception("All addresses in leaves should be lowercase")

        sorted_leaves = sorted(leaves, key=lambda x: x[0])
        print("sorted_leaves", sorted_leaves)
        leaves_length = len(sorted_leaves)
        if leaves_length > self.tree_leaves_count:
            raise Exception("Leaves length is greater than the tree height")
        elif leaves_length < self.tree_leaves_count:
            for i in range(self.tree_leaves_count - leaves_length):
                sorted_leaves.append(self.empty_leaf_data)

        for data in sorted_leaves:
            self.add_leaf(data)

        self.make_tree()

    def hash_leaf(self, values: [str, int]) -> str:
        return Web3.solidity_keccak(['address', 'uint256'], [Web3.to_checksum_address(values[0]), values[1]])

    # Corresponds to merklejs sortPairs=True. Hash the pairs in sorted order.
    def hash_pair(self, v1, v2) -> str:
        if v1 < v2:
            val = Web3.solidity_keccak(["bytes32", "bytes32"], [v1, v2])
        else:
            val = Web3.solidity_keccak(["bytes32", "bytes32"], [v2, v1])
        return val

    def _to_hex(self, x):
        return x.hex()

    def reset_tree(self):
        self.leaves = list()
        self.levels = None
        self.is_ready = False

    # Since we don't sort the leaves. The order in which you add the leaves
    # matters in how the root is generated.
    def add_leaf(self, values: [str, int]):
        self.is_ready = False
        v = self.hash_leaf(values)
        self.leaves.append(v)

    def get_index(self, value):
        hsh = self.hash_leaf(value)
        for idx, val in enumerate(self.leaves):
            if val == hsh:
                return idx
        return None

    def get_leaf(self, index):
        return self._to_hex(self.leaves[index])

    def get_leaf_count(self):
        return len(self.leaves)

    def get_tree_ready_state(self):
        return self.is_ready

    def _calculate_next_level(self):
        solo_leave = None
        N = len(self.levels[0])  # number of leaves on the level
        if N % 2 == 1:  # if odd number of leaves on the level
            solo_leave = self.levels[0][-1]
            N -= 1

        new_level = []
        for l, r in zip(self.levels[0][0:N:2], self.levels[0][1:N:2]):
            hsh = self.hash_pair(l, r)
            new_level.append(hsh)
        if solo_leave is not None:
            new_level.append(solo_leave)
        self.levels = [
            new_level,
        ] + self.levels  # prepend new level

    def make_tree(self):
        self.is_ready = False
        if self.get_leaf_count() > 0:
            self.levels = [
                self.leaves,
            ]
            while len(self.levels[0]) > 1:
                self._calculate_next_level()
        self.is_ready = True

    def get_merkle_root(self):
        if self.is_ready:
            if self.levels is not None:
                return self._to_hex(self.levels[0][0])
            else:
                return None
        else:
            return None

    def get_proof_for_value(self, value, value_only=True):
        idx = self.get_index(value)
        if idx is None:
            return []

        return self.get_proof(idx, value_only)

    def get_proof(self, index, value_only=True):
        if self.levels is None:
            return None
        elif not self.is_ready or index > len(self.leaves) - 1 or index < 0:
            return None
        else:
            proof = []
            for x in range(len(self.levels) - 1, 0, -1):
                level_len = len(self.levels[x])
                if (index == level_len - 1) and (
                    level_len % 2 == 1
                ):  # skip if this is an odd end node
                    index = int(index / 2.0)
                    continue
                is_right_node = index % 2
                sibling_index = index - 1 if is_right_node else index + 1
                sibling_pos = "left" if is_right_node else "right"
                sibling_value = self._to_hex(self.levels[x][sibling_index])
                if value_only:
                    proof.append(sibling_value)
                else:
                    proof.append({sibling_pos: sibling_value})
                index = int(index / 2.0)
            return proof

    def validate_proof(self, proof, target_hash, merkle_root):
        if len(proof) == 0:
            return target_hash == merkle_root
        else:
            proof_hash = target_hash
            for p in proof:
                proof_hash = self.hash_pair(p, proof_hash).hex()

            return proof_hash == merkle_root

    # Add convenience function to print the tree
    def __str__(self) -> str:
        if not self.is_ready:
            return ""

        s = self.get_merkle_root() + "\n"
        for idx, level in enumerate(self.levels):
            s += f"Level: {idx} "
            for node in level:
                s += f" {self._to_hex(node)} "
            s += "\n"
        return s