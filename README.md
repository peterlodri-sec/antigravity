<p align="center">
  <img src="assets/logo.png" alt="Antigravity Logo" width="220" />
</p>

# Antigravity CLI for Vaked Swarm

The zero-dependency Anti-Gravity Capability Graph CLI tool (`ag`) built for Vaked Swarm (Genesis `7c242080`) in Zig 0.16.0.

## Why It Was Born
In decentralized systems, verifying nodes and mapping dynamic capability paths without central coordinate authorities is a major challenge. The Antigravity CLI was born to serve as a high-performance, lightweight trust anchor for Vaked Swarm nodes. Operating on zero external runtime dependencies, it provides instantaneous verification of trust edges, node attributes, and capability links, enforcing security-hardened rules directly in the shell.

## Original Inspiration
This project is inspired by the Vaked Swarm trust propagation protocols and the Genesis block cryptographic specifications (Genesis `7c242080`). Transitive trust systems like those used in capability-based security kernels are combined with SHA-256 seal commitments to provide verifiable local proof of decentralized node trust matrices.

## Key Use Cases
1. **Capability Trust Mapping**: Modeling which nodes possess specific trust relationships and capabilities.
2. **Path Integrity Auditing**: Resolving capability chains to verify that nodes do not bypass security policies.
3. **Genesis Seal Attestation**: Creating cryptographically sealed proofs (`ag seal`) of local graph states concatenated with the Genesis hash and timestamps.
4. **Decentralized Verification**: Exporting `.vaked` grammar representations (`ag push`) to stdout for easy ingestion by upstream policy compilers or pipeline filters.

---

## Installation & Build
Ensure you have the Zig 0.16.0 compiler installed.

```bash
# Clone the repository and build the executable
zig build
```

This triggers custom build-time source path hash check step to ensure source file integrity during compile time:
```
[antigravity-build] verified path 'src/main.zig' hash: 9a7e06...
[antigravity-build] verified path 'src/graph.zig' hash: 411150...
```

The resulting binary is placed at `zig-out/bin/ag`.

---

## How to Use

### 1. Initialize Workspace
Initialize the `.ag/` local database schema.
```bash
ag init
# Output: [antigravity] initialized · genesis 7c242080
```

### 2. Declare Nodes
Declare the nodes participating in your swarm network.
```bash
ag declare node paris
ag declare node helsinki
```

### 3. Declare Trust Score
Set capability trust score ratings on nodes (must be between `0.0` and `1.0`).
```bash
ag declare trust paris 0.88
```

### 4. Link Nodes
Establish directed capability trust edges between nodes.
```bash
ag declare edge paris helsinki 0.95
```
Alternatively, use the convenience helper to link nodes with a default trust of `0.95`:
```bash
ag link paris helsinki
```

### 5. Check Graph Status
View the structured in-memory representation of nodes, edges, scores, and signatures.
```bash
ag status
```

### 6. Export to `.vaked` Grammar
Output the capability graph in the standard `.vaked` specification format.
```bash
ag push
```

### 7. Seal Graph Cryptographically
Generate a secure SHA-256 commitment of the current graph state concatenated with the Genesis hash and an epoch timestamp.
```bash
ag seal
```

---

## Verification & Testing
Run the integrated test suite to run validations on error handling, boundary limits, and subcommand behavior:
```bash
bash scratch/run_tests.sh
```
