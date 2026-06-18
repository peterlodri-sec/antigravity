# Zig Anti-Gravity CLI Audit Report

## Overview

I've reviewed the source code for the `ag` CLI tool built with Zig 0.16.0. Below are my findings categorized by issue type with recommended fixes.

## 1. Memory Management Issues

### Issue 1: Uninitialized ArrayList in Graph.init()
**File**: src/graph.zig  
**Line**: ~90  
**Problem**: The Graph.init() function creates empty ArrayLists without initializing them with the allocator.  
**Fix**:
```zig
pub fn init(allocator: std.mem.Allocator) Graph {
    return .{
        .nodes = std.ArrayList(Node).init(allocator),
        .edges = std.ArrayList(Edge).init(allocator),
        .trusts = std.ArrayList(Trust).init(allocator),
        .seal = null,
        .allocator = allocator,
    };
}
```

### Issue 2: Potential Leak in toJson()
**File**: src/graph.zig  
**Line**: ~300  
**Problem**: The toJson() function allocates temporary strings for numbers but doesn't properly handle errors before freeing them.  
**Fix**:
```zig
const trust_str = try std.fmt.allocPrint(a, "{d}", .{e.trust});
errdefer a.free(trust_str);
try buf.appendSlice(a, trust_str);
a.free(trust_str);
```

## 2. JSON Parsing Issues

### Issue 3: Missing Error Handling for Malformed JSON
**File**: src/graph.zig  
**Line**: ~180  
**Problem**: The JSON parsing doesn't properly validate all required fields before use.  
**Fix**:
```zig
if (item == .object) {
    const name = item.object.get("name") orelse return error.MissingNodeName;
    const kind = item.object.get("kind") orelse return error.MissingNodeKind;
    // ... same for other object types
}
```

### Issue 4: No Validation for Trust Score Range
**File**: src/graph.zig  
**Line**: ~240  
**Problem**: Trust scores should be validated to be between 0.0 and 1.0.  
**Fix**:
```zig
const score_val = switch (score) {
    .float => |f| if (f < 0.0 or f > 1.0) return error.InvalidTrustScore else f,
    .integer => |i| if (i < 0 or i > 1) return error.InvalidTrustScore else @as(f64, @floatFromInt(i)),
    else => return error.InvalidTrustScore,
};
```

## 3. Logic Bugs

### Issue 5: Missing Node Existence Check in addEdge()
**File**: src/graph.zig  
**Line**: ~130  
**Problem`: The addEdge() function doesn't verify that the nodes exist before creating an edge.  
**Fix**:
```zig
pub fn addEdge(self: *Graph, from: []const u8, to: []const u8, trust: f64) !void {
    // Check nodes exist
    var from_exists = false;
    var to_exists = false;
    for (self.nodes.items) |n| {
        if (std.mem.eql(u8, n.name, from)) from_exists = true;
        if (std.mem.eql(u8, n.name, to)) to_exists = true;
    }
    if (!from_exists or !to_exists) return error.NodeNotFound;
    
    // Rest of existing logic...
}
```

### Issue 6: No Validation for Empty Names
**File**: src/graph.zig  
**Line**: ~120  
**Problem`: Empty node names should be rejected.  
**Fix**:
```zig
pub fn addNode(self: *Graph, name: []const u8, kind: []const u8) !void {
    if (name.len == 0) return error.EmptyNodeName;
    // Rest of existing logic...
}
```

## 4. Zig 0.16.0 Compatibility

### Issue 7: Deprecated std.Io Usage
**File**: Throughout codebase  
**Problem`: std.Io is being deprecated in favor of std.fs and std.io.  
**Recommended Action**: Migrate to:
```zig
const std = @import("std");
const fs = std.fs;
const io = std.io;
```

## 5. Missing Validation Checks

### Issue 8: No File Size Limit in loadFromFile()
**File**: src/graph.zig  
**Line**: ~170  
**Problem`: Unlimited file size could lead to memory exhaustion.  
**Fix**:
```zig
const content = cwd.readFileAlloc(io, path, self.allocator, 1 << 20) // 1MB limit
    catch |err| {
        if (err == error.FileNotFound) return;
        return err;
    };
```

### Issue 9: No Validation for Duplicate Trust Entries
**File**: src/graph.zig  
**Line**: ~150  
**Problem`: The code updates existing trust entries but doesn't validate the score range.  
**Fix**:
```zig
pub fn addTrust(self: *Graph, node: []const u8, score: f64) !void {
    if (score < 0.0 or score > 1.0) return error.InvalidTrustScore;
    // Rest of existing logic...
}
```

## Recommendations

1. Add comprehensive error handling for all file operations
2. Implement size limits for all allocations and file reads
3. Add validation for all string inputs (empty strings, max lengths)
4. Consider using std.json.parseFromSliceLeaky() for better performance
5. Add tests for edge cases in JSON parsing
6. Document all error conditions in function signatures

The code is generally well-structured and follows Zig idioms, but would benefit from these additional safety checks and modernizations.