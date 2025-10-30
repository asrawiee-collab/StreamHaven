#!/bin/bash
# Run StreamHaven SQLite tests serially to avoid database locking issues
# This script runs each test class individually rather than all together

set -e

echo "🧪 Running StreamHaven SQLite Tests (Serial Execution)"
echo "=================================================="

# Array of test classes
test_classes=(
    "FullTextSearchManagerTests"
    "FTSTriggerTests"
    "EPGParserTests"
    "PerformanceRegressionTests"
    "M3UPlaylistParserTests"
    "PlaylistCacheManagerTests"
)

total_passed=0
total_failed=0

# Function to wait for any existing swift processes to finish
wait_for_swift_processes() {
    local max_wait=30
    local waited=0
    
    while pgrep -q "swift-test\|swift-build\|swift-package" 2>/dev/null; do
        if [ $waited -ge $max_wait ]; then
            echo "⚠️  Timeout waiting for Swift processes, killing..."
            pkill -9 "swift-test" 2>/dev/null || true
            pkill -9 "swift-build" 2>/dev/null || true
            pkill -9 "swift-package" 2>/dev/null || true
            sleep 2
            break
        fi
        echo "⏳ Waiting for previous Swift process to finish... (${waited}s)"
        sleep 2
        waited=$((waited + 2))
    done
    
    # Clean up any stale lock files
    if [ -f ".build/.lock" ]; then
        rm -f ".build/.lock"
    fi
}

# Build once before running tests to avoid rebuilding for each test class
echo ""
echo "🔨 Building test target..."
swift build --build-tests
wait_for_swift_processes

# Run each test class individually
for test_class in "${test_classes[@]}"; do
    echo ""
    echo "📋 Running $test_class..."
    echo "--------------------------------------------------"
    
    wait_for_swift_processes
    
    if swift test --skip-build --filter "StreamHavenSQLiteTests.$test_class" 2>&1 | tee /tmp/test_output.txt; then
        # Extract pass/fail counts
        passed=$(grep -o "Executed [0-9]* test" /tmp/test_output.txt | grep -o "[0-9]*" | head -1 || echo "0")
        echo "✅ $test_class: $passed tests passed"
        total_passed=$((total_passed + passed))
    else
        echo "❌ $test_class: FAILED"
        total_failed=$((total_failed + 1))
    fi
    
    # Wait a moment between test runs
    sleep 1
done

echo ""
echo "=================================================="
echo "📊 Summary:"
echo "   Total Passed: $total_passed tests"
echo "   Total Failed: $total_failed test classes"

if [ $total_failed -eq 0 ]; then
    echo "✅ All SQLite tests passed!"
    exit 0
else
    echo "❌ Some SQLite tests failed"
    exit 1
fi
