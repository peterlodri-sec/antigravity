# Antigravity CLI for Vaked Swarm

The zero-dependency Anti-Gravity Capability Graph CLI tool (`ag`) built for Vaked Swarm (Genesis `7c242080`) in Zig 0.16.0.

## Core Features
- **Capability Graph Representation**: Nodes, edges with trust scores, and trust rating commitments.
- **Strict Validations**: Rejects empty node names, invalid score ranges ($0.0 \le \text{trust} \le 1.0$), and references to non-existent nodes.
- **Cryptographic Seals**: Generates deterministic commitments utilizing SHA-256 over graph state, Genesis hash, and timestamp.
- **Zero Dependencies**: Pure Zig standard library, using `std.Io` for I/O routing and Arena Allocator for memory layout.

## Subcommands
- `ag init` — Initialize the `.ag/` storage directory and schema file.
- `ag declare node <name>` — Add a named capability node.
- `ag declare edge <from> <to> <trust>` — Declare a trust relationship edge.
- `ag declare trust <node> <score>` — Set a capability trust score.
- `ag link <from> <to>` — Link two existing nodes with default trust `0.95`.
- `ag status` — Print status summary of nodes, edges, trust scores, and seal.
- `ag push` — Print graph state in the `.vaked` grammar.
- `ag seal` — Crytographically sign the state database file.

## Building the CLI
Ensure you have the Zig 0.16.0 compiler installed.

```bash
zig build
```
This builds and installs the executable to `zig-out/bin/ag`.

## Running Tests
Run the automated test suite:
```bash
bash scratch/run_tests.sh
```
