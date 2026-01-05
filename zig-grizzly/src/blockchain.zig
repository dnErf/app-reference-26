const std = @import("std");
const crypto = std.crypto;

/// Blockchain - Immutable append-only data structure for secure, verifiable storage
/// Uses SHA-256 hashing for block integrity and proof-of-work for consensus
pub const Blockchain = struct {
    allocator: std.mem.Allocator,
    base_path: []const u8,
    blocks: std.ArrayList(*Block),
    difficulty: u32,
    pending_transactions: std.ArrayList([]const u8),

    pub const Block = struct {
        index: usize,
        timestamp: i64,
        transactions: std.ArrayList([]const u8),
        previous_hash: []const u8,
        hash: []const u8,
        nonce: u64,
        allocator: std.mem.Allocator,

        pub fn init(allocator: std.mem.Allocator, index: usize, transactions: std.ArrayList([]const u8), previous_hash: []const u8) !*Block {
            const block = try allocator.create(Block);
            errdefer allocator.destroy(block);

            var tx_copy = try std.ArrayList([]const u8).initCapacity(allocator, transactions.items.len);
            errdefer tx_copy.deinit(allocator);

            for (transactions.items) |tx| {
                const tx_dup = try allocator.dupe(u8, tx);
                try tx_copy.append(allocator, tx_dup);
            }

            const prev_hash_copy = try allocator.dupe(u8, previous_hash);

            block.* = Block{
                .index = index,
                .timestamp = std.time.milliTimestamp(),
                .transactions = tx_copy,
                .previous_hash = prev_hash_copy,
                .hash = try allocator.dupe(u8, "genesis"), // Placeholder
                .nonce = 0,
                .allocator = allocator,
            };

            // Calculate hash
            const hash = try block.calculateHash();
            allocator.free(block.hash);
            block.hash = hash;

            return block;
        }

        pub fn deinit(self: *Block, allocator: std.mem.Allocator) void {
            for (self.transactions.items) |tx| {
                allocator.free(tx);
            }
            self.transactions.deinit(self.allocator);
            allocator.free(self.previous_hash);
            allocator.free(self.hash);
            allocator.destroy(self);
        }

        fn calculateHash(self: *Block) ![]const u8 {
            var buffer = try std.ArrayList(u8).initCapacity(self.allocator, 1024);
            defer buffer.deinit(self.allocator);

            try std.fmt.format(buffer.writer(self.allocator), "{d}_{d}_{s}_{d}", .{
                self.index,
                self.timestamp,
                self.previous_hash,
                self.nonce,
            });

            for (self.transactions.items) |tx| {
                try buffer.appendSlice(self.allocator, tx);
            }

            var hash: [32]u8 = undefined;
            crypto.hash.sha2.Sha256.hash(buffer.items, &hash, .{});

            const hex_array = std.fmt.bytesToHex(&hash, .lower);
            return std.fmt.allocPrint(self.allocator, "{s}", .{&hex_array});
        }

        pub fn mineBlock(self: *Block, difficulty: u32) !void {
            while (true) {
                const hash = try self.calculateHash();
                defer self.allocator.free(hash);

                // Simple proof-of-work (in real blockchain, this would be more complex)
                const target_str = try self.allocator.alloc(u8, difficulty);
                defer self.allocator.free(target_str);
                @memset(target_str, '0');
                if (std.mem.eql(u8, hash[0..difficulty], target_str)) {
                    self.allocator.free(self.hash);
                    self.hash = try self.allocator.dupe(u8, hash);
                    break;
                }

                self.nonce += 1;
            }
        }
    };

    pub fn init(allocator: std.mem.Allocator, base_path: []const u8) !*Blockchain {
        const path_copy = try allocator.dupe(u8, base_path);
        errdefer allocator.free(path_copy);

        const blockchain = try allocator.create(Blockchain);
        errdefer allocator.destroy(blockchain);

        // Create genesis block
        var genesis_tx = try std.ArrayList([]const u8).initCapacity(allocator, 1);

        const genesis_tx_data = try allocator.dupe(u8, "GENESIS BLOCK");
        try genesis_tx.append(allocator, genesis_tx_data);

        const genesis_block = try Block.init(allocator, 0, genesis_tx, "0");
        errdefer genesis_block.deinit(allocator);

        // Free the original transaction data since Block.init made copies
        allocator.free(genesis_tx_data);
        defer genesis_tx.deinit(allocator);

        blockchain.* = Blockchain{
            .allocator = allocator,
            .base_path = path_copy,
            .blocks = try std.ArrayList(*Block).initCapacity(allocator, 1),
            .difficulty = 2, // Easy for demo
            .pending_transactions = try std.ArrayList([]const u8).initCapacity(allocator, 0),
        };

        blockchain.blocks.appendAssumeCapacity(genesis_block);

        return blockchain;
    }

    pub fn deinit(self: *Blockchain) void {
        self.allocator.free(self.base_path);

        for (self.blocks.items) |block| {
            block.deinit(self.allocator);
        }
        self.blocks.deinit(self.allocator);

        for (self.pending_transactions.items) |tx| {
            self.allocator.free(tx);
        }
        self.pending_transactions.deinit(self.allocator);

        self.allocator.destroy(self);
    }

    pub fn addBlock(self: *Blockchain, transaction: []const u8) ![]const u8 {
        // Add transaction to pending
        const tx_copy = try self.allocator.dupe(u8, transaction);
        errdefer self.allocator.free(tx_copy);

        try self.pending_transactions.append(self.allocator, tx_copy);

        // Create new block with pending transactions
        const previous_block = self.blocks.items[self.blocks.items.len - 1];
        const new_block = try Block.init(self.allocator, self.blocks.items.len, self.pending_transactions, previous_block.hash);
        errdefer new_block.deinit(self.allocator);

        // Mine the block
        try new_block.mineBlock(self.difficulty);

        try self.blocks.append(self.allocator, new_block);

        // Clear pending transactions
        for (self.pending_transactions.items) |tx| {
            self.allocator.free(tx);
        }
        self.pending_transactions.clearRetainingCapacity();

        return self.allocator.dupe(u8, new_block.hash);
    }

    pub fn verifyChain(self: *Blockchain) !bool {
        for (self.blocks.items[1..], 1..) |block, block_index| {
            const previous_block = self.blocks.items[block_index - 1];

            // Check hash
            const calculated_hash = block.calculateHash() catch return false;
            defer self.allocator.free(calculated_hash);

            if (!std.mem.eql(u8, block.hash, calculated_hash)) {
                return false;
            }

            // Check previous hash
            if (!std.mem.eql(u8, block.previous_hash, previous_block.hash)) {
                return false;
            }

            // Check proof-of-work
            const target = try self.allocator.alloc(u8, self.difficulty);
            defer self.allocator.free(target);
            @memset(target, '0');
            if (!std.mem.eql(u8, block.hash[0..self.difficulty], target)) {
                return false;
            }
        }

        return true;
    }

    pub fn getLatestBlock(self: *Blockchain) *Block {
        return self.blocks.items[self.blocks.items.len - 1];
    }

    pub fn getBlockCount(self: *Blockchain) usize {
        return self.blocks.items.len;
    }
};
