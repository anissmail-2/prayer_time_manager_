#!/bin/bash

# TaskFlow Pro - Comprehensive Test Runner Script
# This script runs all tests with coverage and generates reports

set -e  # Exit on error

echo "🧪 TaskFlow Pro - Test Runner"
echo "=============================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Step 1: Clean previous coverage
echo -e "${BLUE}📦 Cleaning previous coverage...${NC}"
rm -rf coverage/
flutter clean > /dev/null 2>&1

# Step 2: Get dependencies
echo -e "${BLUE}📥 Getting dependencies...${NC}"
flutter pub get

# Step 3: Run analyzer
echo -e "${BLUE}🔍 Running static analysis...${NC}"
flutter analyze || {
    echo -e "${YELLOW}⚠️  Analysis found issues (non-blocking)${NC}"
}

# Step 4: Format check
echo -e "${BLUE}✨ Checking code formatting...${NC}"
dart format --set-exit-if-changed . || {
    echo -e "${YELLOW}⚠️  Formatting issues found (non-blocking)${NC}"
}

# Step 5: Run unit and widget tests
echo -e "${BLUE}🧪 Running unit and widget tests...${NC}"
flutter test --coverage --reporter expanded

# Step 6: Run integration tests
echo -e "${BLUE}🔗 Running integration tests...${NC}"
flutter test test/integration/ --reporter expanded || {
    echo -e "${YELLOW}⚠️  Integration tests failed (non-blocking)${NC}"
}

# Step 7: Generate coverage report (if lcov is installed)
if command -v lcov &> /dev/null && command -v genhtml &> /dev/null; then
    echo -e "${BLUE}📊 Generating coverage report...${NC}"

    # Remove generated files from coverage
    lcov --remove coverage/lcov.info \
        '**/*.g.dart' \
        '**/*.freezed.dart' \
        '**/*.mocks.dart' \
        '**/generated/**' \
        'test/**' \
        -o coverage/lcov_filtered.info

    # Generate HTML report
    genhtml coverage/lcov_filtered.info -o coverage/html

    echo -e "${GREEN}✅ Coverage report generated at coverage/html/index.html${NC}"
else
    echo -e "${YELLOW}⚠️  lcov not found, skipping HTML coverage report${NC}"
    echo -e "${YELLOW}   Install with: sudo apt-get install lcov${NC}"
fi

# Step 8: Display coverage summary
if [ -f "coverage/lcov.info" ]; then
    echo -e "${BLUE}📈 Coverage Summary:${NC}"
    if command -v lcov &> /dev/null; then
        lcov --summary coverage/lcov.info 2>&1 | grep -E "lines\.\.\.|functions\.\.\."
    fi
fi

echo ""
echo -e "${GREEN}✅ All tests completed!${NC}"
echo ""
echo "Next steps:"
echo "  - View coverage: open coverage/html/index.html"
echo "  - Run specific test: flutter test test/path/to/test.dart"
echo "  - Watch mode: flutter test --watch"
