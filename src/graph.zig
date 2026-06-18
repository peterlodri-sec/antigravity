//! VAKED Swarm · Genesis: 7c242080 · Anti-Gravity Graph Model
//! Core Onboarding Norms:
//! 1. DERIVE, NEVER ASSERT: Mechanically verify all claims.
//! 2. HONESTY AT THE ARTIFACT: No fabricated metrics; document residuals.
//! 3. EXTERNAL & FAILABLE VERIFY: Seals live outside the verified codebase.
//! 4. OWNER-GATED EFFECT: Peter has merge/run authority via labels.
//! 5. NO BUILD ON DEV MACHINE: Build/verify locally, compile on CI.
//! 6. TOKEN DISCIPLINE: Keep context compact; offload bulk work.
//! 7. GRAMMAR BEFORE CODE: Design and plan via RFCs first.

const std = @import("std");
const Io = std.Io;

/// Node represents a named agent or capability domain.
pub const Node = struct {
    name: []const u8,
    kind: []const u8, // "node" | "trust" etc.
};

/// Edge represents a directed capability transfer between two nodes with a trust score.
pub const Edge = struct {
    from: []const u8,
    to: []const u8,
    trust: f64,
};

/// Trust holds the local trust rating for a specific node.
pub const Trust = struct {
    node: []const u8,
    score: f64,
};

/// Seal represents the cryptographic genesis commitment seal.
pub const Seal = struct {
    genesis: []const u8,
    timestamp: i64,
    signature: []const u8,
};

/// Graph manages the in-memory capability representation and its JSON state persistence.
pub const Graph = struct {
    nodes: std.ArrayList(Node),
    edges: std.ArrayList(Edge),
    trusts: std.ArrayList(Trust),
    seal: ?Seal = null,
    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator) Graph {
        return .{
            .nodes = .empty,
            .edges = .empty,
            .trusts = .empty,
            .seal = null,
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *Graph) void {
        for (self.nodes.items) |n| {
            self.allocator.free(n.name);
            self.allocator.free(n.kind);
        }
        self.nodes.deinit(self.allocator);

        for (self.edges.items) |e| {
            self.allocator.free(e.from);
            self.allocator.free(e.to);
        }
        self.edges.deinit(self.allocator);

        for (self.trusts.items) |t| {
            self.allocator.free(t.node);
        }
        self.trusts.deinit(self.allocator);

        if (self.seal) |s| {
            self.allocator.free(s.genesis);
            self.allocator.free(s.signature);
        }
    }

    pub fn addNode(self: *Graph, name: []const u8, kind: []const u8) !void {
        if (name.len == 0) return error.EmptyNodeName;
        if (kind.len == 0) return error.EmptyNodeKind;
        // De-duplicate nodes
        for (self.nodes.items) |n| {
            if (std.mem.eql(u8, n.name, name)) {
                return;
            }
        }
        const name_copy = try self.allocator.dupe(u8, name);
        const kind_copy = try self.allocator.dupe(u8, kind);
        try self.nodes.append(self.allocator, .{ .name = name_copy, .kind = kind_copy });
    }

    pub fn addEdge(self: *Graph, from: []const u8, to: []const u8, trust: f64) !void {
        if (from.len == 0 or to.len == 0) return error.EmptyNodeName;
        if (trust < 0.0 or trust > 1.0) return error.InvalidTrustScore;

        // Check that both nodes exist
        var from_exists = false;
        var to_exists = false;
        for (self.nodes.items) |n| {
            if (std.mem.eql(u8, n.name, from)) from_exists = true;
            if (std.mem.eql(u8, n.name, to)) to_exists = true;
        }
        if (!from_exists or !to_exists) return error.NodeNotFound;

        // De-duplicate edges
        for (self.edges.items) |e| {
            if (std.mem.eql(u8, e.from, from) and std.mem.eql(u8, e.to, to)) {
                return;
            }
        }
        const from_copy = try self.allocator.dupe(u8, from);
        const to_copy = try self.allocator.dupe(u8, to);
        try self.edges.append(self.allocator, .{ .from = from_copy, .to = to_copy, .trust = trust });
    }

    pub fn addTrust(self: *Graph, node: []const u8, score: f64) !void {
        if (node.len == 0) return error.EmptyNodeName;
        if (score < 0.0 or score > 1.0) return error.InvalidTrustScore;

        // Check node exists
        var node_exists = false;
        for (self.nodes.items) |n| {
            if (std.mem.eql(u8, n.name, node)) {
                node_exists = true;
                break;
            }
        }
        if (!node_exists) return error.NodeNotFound;

        // Update trust if it already exists
        for (self.trusts.items) |*t| {
            if (std.mem.eql(u8, t.node, node)) {
                t.score = score;
                return;
            }
        }
        const node_copy = try self.allocator.dupe(u8, node);
        try self.trusts.append(self.allocator, .{ .node = node_copy, .score = score });
    }

    pub fn setSeal(self: *Graph, genesis: []const u8, timestamp: i64, signature: []const u8) !void {
        if (self.seal) |s| {
            self.allocator.free(s.genesis);
            self.allocator.free(s.signature);
        }
        const gen_copy = try self.allocator.dupe(u8, genesis);
        const sig_copy = try self.allocator.dupe(u8, signature);
        self.seal = .{
            .genesis = gen_copy,
            .timestamp = timestamp,
            .signature = sig_copy,
        };
    }

    pub fn loadFromFile(self: *Graph, io: Io, path: []const u8) !void {
        const cwd = Io.Dir.cwd();
        const content = cwd.readFileAlloc(io, path, self.allocator, Io.Limit.limited(1024 * 1024)) catch |err| {
            if (err == error.FileNotFound) return;
            return err;
        };
        defer self.allocator.free(content);

        const trimmed = std.mem.trim(u8, content, " \t\r\n");
        if (trimmed.len == 0 or std.mem.eql(u8, trimmed, "{}")) {
            return;
        }

        const parsed = std.json.parseFromSlice(std.json.Value, self.allocator, content, .{}) catch {
            return error.MalformedJson;
        };
        defer parsed.deinit();

        if (parsed.value != .object) return;
        const obj = parsed.value.object;

        if (obj.get("nodes")) |nodes_v| {
            if (nodes_v == .array) {
                for (nodes_v.array.items) |item| {
                    if (item == .object) {
                        const name = item.object.get("name") orelse continue;
                        const kind = item.object.get("kind") orelse continue;
                        if (name == .string and kind == .string) {
                            try self.addNode(name.string, kind.string);
                        }
                    }
                }
            }
        }

        if (obj.get("edges")) |edges_v| {
            if (edges_v == .array) {
                for (edges_v.array.items) |item| {
                    if (item == .object) {
                        const from = item.object.get("from") orelse continue;
                        const to = item.object.get("to") orelse continue;
                        const trust = item.object.get("trust") orelse continue;
                        if (from == .string and to == .string) {
                            const trust_val = switch (trust) {
                                .float => |f| f,
                                .integer => |i| @as(f64, @floatFromInt(i)),
                                else => 0.0,
                            };
                            try self.addEdge(from.string, to.string, trust_val);
                        }
                    }
                }
            }
        }

        if (obj.get("trusts")) |trusts_v| {
            if (trusts_v == .array) {
                for (trusts_v.array.items) |item| {
                    if (item == .object) {
                        const node = item.object.get("node") orelse continue;
                        const score = item.object.get("score") orelse continue;
                        if (node == .string) {
                            const score_val = switch (score) {
                                .float => |f| f,
                                .integer => |i| @as(f64, @floatFromInt(i)),
                                else => 0.0,
                            };
                            try self.addTrust(node.string, score_val);
                        }
                    }
                }
            }
        }

        if (obj.get("seal")) |seal_v| {
            if (seal_v == .object) {
                const genesis_opt = seal_v.object.get("genesis");
                const timestamp_opt = seal_v.object.get("timestamp");
                const signature_opt = seal_v.object.get("signature");
                if (genesis_opt) |g| {
                    if (timestamp_opt) |t| {
                        if (signature_opt) |s| {
                            if (g == .string and t == .integer and s == .string) {
                                try self.setSeal(g.string, t.integer, s.string);
                            }
                        }
                    }
                }
            }
        }
    }

    pub fn toJson(self: Graph, a: std.mem.Allocator) ![]u8 {
        var buf: std.ArrayList(u8) = .empty;
        errdefer buf.deinit(a);
        try buf.appendSlice(a, "{\n  \"nodes\": [\n");
        for (self.nodes.items, 0..) |n, i| {
            if (i > 0) try buf.appendSlice(a, ",\n");
            try buf.appendSlice(a, "    {\n      \"name\": \"");
            try buf.appendSlice(a, n.name);
            try buf.appendSlice(a, "\",\n      \"kind\": \"");
            try buf.appendSlice(a, n.kind);
            try buf.appendSlice(a, "\"\n    }");
        }
        try buf.appendSlice(a, "\n  ],\n  \"edges\": [\n");
        for (self.edges.items, 0..) |e, i| {
            if (i > 0) try buf.appendSlice(a, ",\n");
            try buf.appendSlice(a, "    {\n      \"from\": \"");
            try buf.appendSlice(a, e.from);
            try buf.appendSlice(a, "\",\n      \"to\": \"");
            try buf.appendSlice(a, e.to);
            try buf.appendSlice(a, "\",\n      \"trust\": ");
            const trust_str = try std.fmt.allocPrint(a, "{d}", .{e.trust});
            defer a.free(trust_str);
            try buf.appendSlice(a, trust_str);
            try buf.appendSlice(a, "\n    }");
        }
        try buf.appendSlice(a, "\n  ],\n  \"trusts\": [\n");
        for (self.trusts.items, 0..) |t, i| {
            if (i > 0) try buf.appendSlice(a, ",\n");
            try buf.appendSlice(a, "    {\n      \"node\": \"");
            try buf.appendSlice(a, t.node);
            try buf.appendSlice(a, "\",\n      \"score\": ");
            const score_str = try std.fmt.allocPrint(a, "{d}", .{t.score});
            defer a.free(score_str);
            try buf.appendSlice(a, score_str);
            try buf.appendSlice(a, "\n    }");
        }
        try buf.appendSlice(a, "\n  ]");
        if (self.seal) |s| {
            try buf.appendSlice(a, ",\n  \"seal\": {\n    \"genesis\": \"");
            try buf.appendSlice(a, s.genesis);
            try buf.appendSlice(a, "\",\n    \"timestamp\": ");
            const ts_str = try std.fmt.allocPrint(a, "{d}", .{s.timestamp});
            defer a.free(ts_str);
            try buf.appendSlice(a, ts_str);
            try buf.appendSlice(a, ",\n    \"signature\": \"");
            try buf.appendSlice(a, s.signature);
            try buf.appendSlice(a, "\"\n  }");
        }
        try buf.appendSlice(a, "\n}");
        return try buf.toOwnedSlice(a);
    }

    pub fn saveToFile(self: Graph, io: Io, path: []const u8) !void {
        const content = try self.toJson(self.allocator);
        defer self.allocator.free(content);
        const cwd = Io.Dir.cwd();
        try cwd.writeFile(io, .{ .sub_path = path, .data = content });
    }
};
