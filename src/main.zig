//! VAKED Swarm · Genesis: 7c242080 · Anti-Gravity CLI Dispatcher
//! Core Onboarding Norms:
//! 1. DERIVE, NEVER ASSERT: Mechanically verify all claims.
//! 2. HONESTY AT THE ARTIFACT: No fabricated metrics; document residuals.
//! 3. EXTERNAL & FAILABLE VERIFY: Seals live outside the verified codebase.
//! 4. OWNER-GATED EFFECT: Peter has merge/run authority via labels.
//! 5. NO BUILD ON DEV MACHINE: Build/verify locally, compile on CI.
//! 6. TOKEN DISCIPLINE: Keep context compact; offload bulk work.
//! 7. GRAMMAR BEFORE CODE: Design and plan via RFCs first.
//!
//! Ultra Metadata:
//! * Project Path: /tmp/antigravity/
//! * Native Build: zig build-exe src/main.zig -O ReleaseFast -fstrip --name ag
//! * Build Integration: zig build
//! * Zero-Dependency: pure Zig standard library, std.Io for I/O routing.
//! * Memory: std.heap.ArenaAllocator
//! * Subcommands:
//!   - init: create .ag/ graph storage and default schema
//!   - declare node: add node to graph state
//!   - declare edge: add trust edge relation
//!   - declare trust: set node capability trust score
//!   - link: bidirectional edge helper with default 0.95 trust
//!   - status: print graph summary
//!   - push: emit valid .vaked output to stdout
//!   - seal: sign state with SHA256(genesis + timestamp + graph)
//! * Exit Codes: 0 OK, 1 user error, 2 internal.

const std = @import("std");
const Io = std.Io;
const graph = @import("graph.zig");
const eexport = @import("export.zig");

pub fn main(init: std.process.Init) !void {
    const a = init.arena.allocator();
    const io = init.io;

    var stdout_buf: [4096]u8 = undefined;
    var stdout_writer = Io.File.stdout().writer(io, &stdout_buf);

    run(a, io, &stdout_writer, init) catch |err| {
        switch (err) {
            error.UserError => {
                stdout_writer.interface.flush() catch {};
                std.process.exit(1);
            },
            else => {
                stdout_writer.interface.print("[antigravity] internal error: {s}\n", .{@errorName(err)}) catch {};
                stdout_writer.interface.flush() catch {};
                std.process.exit(2);
            },
        }
    };

    try stdout_writer.interface.flush();
}

fn run(a: std.mem.Allocator, io: Io, stdout_writer: anytype, init: std.process.Init) !void {
    const argv_z = try init.minimal.args.toSlice(a);
    const args = try a.alloc([]const u8, argv_z.len);
    for (argv_z, 0..) |s, i| args[i] = s;

    if (args.len < 2) {
        try printUsage(stdout_writer);
        return error.UserError;
    }

    const cmd = args[1];

    if (std.mem.eql(u8, cmd, "init")) {
        try initWorkspace(io, stdout_writer);
        return;
    }

    // All other subcommands require the workspace to be initialized
    try checkWorkspace(io, stdout_writer);

    var g = graph.Graph.init(a);
    defer g.deinit();

    g.loadFromFile(io, ".ag/graph.json") catch |err| {
        try stdout_writer.interface.print("[antigravity] failed to load graph: {s}\n", .{@errorName(err)});
        return error.UserError;
    };

    if (std.mem.eql(u8, cmd, "declare")) {
        if (args.len < 3) {
            try stdout_writer.interface.print("[antigravity] usage: declare node|edge|trust [args]\n", .{});
            return error.UserError;
        }
        const kind = args[2];
        if (std.mem.eql(u8, kind, "node")) {
            if (args.len != 4) {
                try stdout_writer.interface.print("[antigravity] usage: declare node <name>\n", .{});
                return error.UserError;
            }
            try g.addNode(args[3], "node");
            try g.saveToFile(io, ".ag/graph.json");
            try stdout_writer.interface.print("[antigravity] declared node {s}\n", .{args[3]});
        } else if (std.mem.eql(u8, kind, "edge")) {
            if (args.len != 6) {
                try stdout_writer.interface.print("[antigravity] usage: declare edge <from> <to> <trust>\n", .{});
                return error.UserError;
            }
            const trust = std.fmt.parseFloat(f64, args[5]) catch {
                try stdout_writer.interface.print("[antigravity] invalid trust score: {s}\n", .{args[5]});
                return error.UserError;
            };
            if (trust < 0.0 or trust > 1.0) {
                try stdout_writer.interface.print("[antigravity] trust score must be between 0.0 and 1.0: {d}\n", .{trust});
                return error.UserError;
            }
            g.addEdge(args[3], args[4], trust) catch |err| {
                switch (err) {
                    error.NodeNotFound => {
                        try stdout_writer.interface.print("[antigravity] error: one or both nodes do not exist\n", .{});
                        return error.UserError;
                    },
                    else => return err,
                }
            };
            try g.saveToFile(io, ".ag/graph.json");
            try stdout_writer.interface.print("[antigravity] declared edge {s} -> {s} ({d})\n", .{ args[3], args[4], trust });
        } else if (std.mem.eql(u8, kind, "trust")) {
            if (args.len != 5) {
                try stdout_writer.interface.print("[antigravity] usage: declare trust <node> <score>\n", .{});
                return error.UserError;
            }
            const score = std.fmt.parseFloat(f64, args[4]) catch {
                try stdout_writer.interface.print("[antigravity] invalid trust score: {s}\n", .{args[4]});
                return error.UserError;
            };
            if (score < 0.0 or score > 1.0) {
                try stdout_writer.interface.print("[antigravity] trust score must be between 0.0 and 1.0: {d}\n", .{score});
                return error.UserError;
            }
            g.addTrust(args[3], score) catch |err| {
                switch (err) {
                    error.NodeNotFound => {
                        try stdout_writer.interface.print("[antigravity] error: node does not exist\n", .{});
                        return error.UserError;
                    },
                    else => return err,
                }
            };
            try g.saveToFile(io, ".ag/graph.json");
            try stdout_writer.interface.print("[antigravity] declared trust {s} ({d})\n", .{ args[3], score });
        } else {
            try stdout_writer.interface.print("[antigravity] unknown declare kind: {s}\n", .{kind});
            return error.UserError;
        }
    } else if (std.mem.eql(u8, cmd, "link")) {
        if (args.len != 4) {
            try stdout_writer.interface.print("[antigravity] usage: link <from> <to>\n", .{});
            return error.UserError;
        }
        g.addEdge(args[2], args[3], 0.95) catch |err| {
            switch (err) {
                error.NodeNotFound => {
                    try stdout_writer.interface.print("[antigravity] error: one or both nodes do not exist\n", .{});
                    return error.UserError;
                },
                else => return err,
            }
        };
        try g.saveToFile(io, ".ag/graph.json");
        try stdout_writer.interface.print("[antigravity] linked {s} → {s}\n", .{ args[2], args[3] });
    } else if (std.mem.eql(u8, cmd, "status")) {
        if (args.len != 2) {
            try stdout_writer.interface.print("[antigravity] usage: status\n", .{});
            return error.UserError;
        }
        try printStatus(stdout_writer, g);
    } else if (std.mem.eql(u8, cmd, "push")) {
        if (args.len != 2) {
            try stdout_writer.interface.print("[antigravity] usage: push\n", .{});
            return error.UserError;
        }
        const vaked = try eexport.toVaked(a, g);
        try stdout_writer.interface.writeAll(vaked);
    } else if (std.mem.eql(u8, cmd, "seal")) {
        if (args.len != 2) {
            try stdout_writer.interface.print("[antigravity] usage: seal\n", .{});
            return error.UserError;
        }
        const ts_now = std.Io.Timestamp.now(io, .real);
        const ts = @as(i64, @intCast(@divTrunc(ts_now.nanoseconds, std.time.ns_per_s)));
        g.seal = null;
        const json_data = try g.toJson(a);
        const sig = try eexport.sealSignature(a, eexport.GENESIS, ts, json_data);
        try g.setSeal(eexport.GENESIS, ts, sig);
        try g.saveToFile(io, ".ag/graph.json");
        try stdout_writer.interface.print("[antigravity] sealed with genesis {s}\n", .{eexport.GENESIS});
    } else {
        try stdout_writer.interface.print("[antigravity] unknown subcommand: {s}\n", .{cmd});
        return error.UserError;
    }

    try stdout_writer.interface.flush();
}

fn initWorkspace(io: Io, stdout_writer: anytype) !void {
    const cwd = Io.Dir.cwd();
    cwd.createDirPath(io, ".ag") catch |err| {
        if (err != error.PathAlreadyExists) return err;
    };
    try cwd.writeFile(io, .{ .sub_path = ".ag/graph.json", .data = "{\n  \"nodes\": [],\n  \"edges\": [],\n  \"trusts\": []\n}" });
    try stdout_writer.interface.print("[antigravity] initialized · genesis {s}\n", .{eexport.GENESIS});
}

fn checkWorkspace(io: Io, stdout_writer: anytype) !void {
    const cwd = Io.Dir.cwd();
    cwd.access(io, ".ag/graph.json", .{}) catch {
        try stdout_writer.interface.print("[antigravity] workspace not initialized\n", .{});
        return error.UserError;
    };
}

fn printStatus(stdout_writer: anytype, g: graph.Graph) !void {
    try stdout_writer.interface.print("Nodes: {d}\n", .{g.nodes.items.len});
    for (g.nodes.items) |n| {
        try stdout_writer.interface.print("  - {s} ({s})\n", .{ n.name, n.kind });
    }
    try stdout_writer.interface.print("Edges: {d}\n", .{g.edges.items.len});
    for (g.edges.items) |e| {
        try stdout_writer.interface.print("  - {s} -> {s} ({d})\n", .{ e.from, e.to, e.trust });
    }
    try stdout_writer.interface.print("Trust Scores: {d}\n", .{g.trusts.items.len});
    for (g.trusts.items) |t| {
        try stdout_writer.interface.print("  - {s}: {d}\n", .{ t.node, t.score });
    }
    if (g.seal) |s| {
        try stdout_writer.interface.print("Seal: genesis {s} (timestamp: {d}, signature: {s})\n", .{ s.genesis, s.timestamp, s.signature });
    }
}

fn printUsage(stdout_writer: anytype) !void {
    try stdout_writer.interface.writeAll(
        \\ag init                      Initialize workspace
        \\ag declare node|edge|trust   Declare graph element
        \\ag link <from> <to>          Connect nodes
        \\ag status                    Show graph
        \\ag push                      Emit .vaked
        \\ag seal                      Sign with Genesis
        \\
    );
}
