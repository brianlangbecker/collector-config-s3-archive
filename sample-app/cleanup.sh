#!/bin/bash

# Cleanup script for virtual environment and generated files
# This script removes all files created during testing and setup

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

echo "🧹 Virtual Environment Cleanup Script"
echo "====================================="
echo

# Check if we're in the sample-app directory
if [ ! -f "app.py" ] || [ ! -f "requirements.txt" ]; then
    print_error "This script must be run from the sample-app directory"
    exit 1
fi

print_status "Checking for files to clean up..."

# Track what we're cleaning up
CLEANUP_COUNT=0

# Remove virtual environment
if [ -d "venv" ]; then
    print_status "Removing virtual environment (venv/)..."
    rm -rf venv
    print_success "Removed venv/"
    CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
fi

# Remove any test virtual environments
if [ -d "test_venv" ]; then
    print_status "Removing test virtual environment (test_venv/)..."
    rm -rf test_venv
    print_success "Removed test_venv/"
    CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
fi

# Remove generated scripts
if [ -f "run-direct.sh" ]; then
    print_status "Removing generated run script (run-direct.sh)..."
    rm -f run-direct.sh
    print_success "Removed run-direct.sh"
    CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
fi

if [ -f "run-direct-test.sh" ]; then
    print_status "Removing generated test script (run-direct-test.sh)..."
    rm -f run-direct-test.sh
    print_success "Removed run-direct-test.sh"
    CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
fi

# Remove Python cache
if [ -d "__pycache__" ]; then
    print_status "Removing Python cache (__pycache__/)..."
    rm -rf __pycache__
    print_success "Removed __pycache__/"
    CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
fi

# Remove any .pyc files
if find . -name "*.pyc" -type f | grep -q .; then
    print_status "Removing compiled Python files (*.pyc)..."
    find . -name "*.pyc" -delete
    print_success "Removed *.pyc files"
    CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
fi

# Remove any temporary directories created by tests
if [ -d "path" ]; then
    print_status "Removing test path directory (path/)..."
    rm -rf path
    print_success "Removed path/"
    CLEANUP_COUNT=$((CLEANUP_COUNT + 1))
fi

echo

if [ $CLEANUP_COUNT -eq 0 ]; then
    print_success "✨ Nothing to clean up - directory is already clean!"
else
    print_success "🎉 Cleanup completed! Removed $CLEANUP_COUNT items."
fi

echo
print_status "Files remaining in sample-app directory:"
ls -la --color=never | grep -v "^total"

echo
print_status "✅ Directory is now clean and ready for fresh setup"
print_status "💡 Run ./test-venv-setup-auto.sh to recreate the environment"