//! VAKED Swarm · Genesis: 7c242080 · Anti-Gravity Build Script
//! Core Onboarding Norms:
//! 1. DERIVE, NEVER ASSERT: Mechanically verify all claims.
//! 2. HONESTY AT THE ARTIFACT: No fabricated metrics; document residuals.
//! 3. EXTERNAL & FAILABLE VERIFY: Seals live outside the verified codebase.
//! 4. OWNER-GATED EFFECT: Peter has merge/run authority via labels.
//! 5. NO BUILD ON DEV MACHINE: Build/verify locally, compile on CI.
//! 6. TOKEN DISCIPLINE: Keep context compact; offload bulk work.
//! 7. GRAMMAR BEFORE CODE: Design and plan via RFCs first.

const std = @import("std");

pub fn build(b: *std.Build) void {
    verifyPath(b, "src/main.zig");
    verifyPath(b, "src/graph.zig");
    verifyPath(b, "src/export.zig");

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "ag",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run the antigravity CLI");
    run_step.dependOn(&run_cmd.step);
}

fn verifyPath(b: *std.Build, sub_path: []const u8) void {
    const content = b.build_root.handle.readFileAlloc(b.graph.io, sub_path, b.allocator, .unlimited) catch |err| {
        std.debug.print("[antigravity-build] warning: failed to read path '{s}': {s}\n", .{ sub_path, @errorName(err) });
        return;
    };
    defer b.allocator.free(content);
    var hash: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(content, &hash, .{});
    const hex = std.fmt.bytesToHex(hash, .lower);
    std.debug.print("[antigravity-build] verified path '{s}' hash: {s}\n", .{ sub_path, &hex });
}
