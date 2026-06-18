#!/bin/bash
set -e

AG="./zig-out/bin/ag"

echo "=== Cleaning environment ==="
rm -rf .ag

echo "=== Test 1: Workspace not initialized error ==="
# Should fail with exit code 1
set +e
$AG status
status_exit=$?
set -e
if [ $status_exit -ne 1 ]; then
    echo "FAIL: expected status to fail with 1 before init, got $status_exit"
    exit 1
fi
echo "Pass: status check failed as expected before init."

echo "=== Test 2: Initialize workspace ==="
$AG init
if [ ! -f .ag/graph.json ]; then
    echo "FAIL: graph.json was not created"
    exit 1
fi
echo "Pass: init succeeded."

echo "=== Test 3: Declare node (paris) ==="
$AG declare node paris
# Verify it's in the json
grep -q '"name": "paris"' .ag/graph.json
echo "Pass: declared node paris."

echo "=== Test 4: Declare node (helsinki) ==="
$AG declare node helsinki
grep -q '"name": "helsinki"' .ag/graph.json
echo "Pass: declared node helsinki."

echo "=== Test 5: Try to declare edge with invalid node ==="
set +e
$AG declare edge paris london 0.95
edge_exit=$?
set -e
if [ $edge_exit -ne 1 ]; then
    echo "FAIL: expected edge declaration with missing node to fail, got $edge_exit"
    exit 1
fi
echo "Pass: invalid node in edge rejected as expected."

echo "=== Test 6: Declare edge paris -> helsinki ==="
$AG declare edge paris helsinki 0.95
grep -q '"from": "paris"' .ag/graph.json
grep -q '"to": "helsinki"' .ag/graph.json
echo "Pass: declared edge."

echo "=== Test 7: Declare trust score ==="
$AG declare trust paris 0.88
grep -q '"node": "paris"' .ag/graph.json
grep -q '"score": 0.88' .ag/graph.json
echo "Pass: declared trust."

echo "=== Test 8: Try to declare trust for non-existent node ==="
set +e
$AG declare trust london 0.5
trust_exit=$?
set -e
if [ $trust_exit -ne 1 ]; then
    echo "FAIL: expected trust for non-existent node to fail, got $trust_exit"
    exit 1
fi
echo "Pass: trust on invalid node rejected."

echo "=== Test 9: Try to declare invalid trust score (< 0) ==="
set +e
$AG declare trust paris -0.5
score_exit=$?
set -e
if [ $score_exit -ne 1 ]; then
    echo "FAIL: expected negative trust score to fail, got $score_exit"
    exit 1
fi
echo "Pass: negative trust score rejected."

echo "=== Test 10: Try to declare invalid trust score (> 1) ==="
set +e
$AG declare trust paris 1.5
score_exit=$?
set -e
if [ $score_exit -ne 1 ]; then
    echo "FAIL: expected >1.0 trust score to fail, got $score_exit"
    exit 1
fi
echo "Pass: >1.0 trust score rejected."

echo "=== Test 11: Link (bidirectional edge helper) ==="
$AG link paris helsinki
echo "Pass: link command succeeded."

echo "=== Test 12: Status ==="
$AG status
echo "Pass: status command succeeded."

echo "=== Test 13: Push (.vaked format) ==="
$AG push
echo "Pass: push command succeeded."

echo "=== Test 14: Seal ==="
$AG seal
# Verify seal in graph.json
grep -q '"seal":' .ag/graph.json
echo "Pass: seal command succeeded."

echo "=== Test 15: Status after seal ==="
$AG status
echo "Pass: status post-seal succeeded."

echo "ALL TESTS PASSED!"
