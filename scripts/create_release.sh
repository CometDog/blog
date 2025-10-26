#!/bin/bash
set -e

# =============================================================================
# Blog Release Script
# =============================================================================
# This script automates the creation of new releases for the blog.
# It handles version bumping, git commits, and tag creation.
#
# Usage:
#   ./create_release.sh --part major|minor|patch
#
# What it does:
#   1. Bumps version in release-version.yml and package.json
#   2. Commits the changes with a release message
#   3. Creates a git tag for the new version
# =============================================================================

# =============================================================================
# COLOR CONSTANTS AND OUTPUT UTILITY FUNCTIONS
# =============================================================================

# ANSI color codes for terminal output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly DEFAULT='\033[0m'

# Standardized output functions with color coding
print_info() {
    echo -e "${BLUE}[INFO]${DEFAULT} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${DEFAULT} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${DEFAULT} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${DEFAULT} $1"
}

# =============================================================================
# VERSION MANAGEMENT FUNCTIONS
# =============================================================================

# Validates that a version string follows semantic versioning (x.y.z)
validate_version_format() {
    local version=$1
    if [[ ! $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Version must be in semantic version format (e.g., 1.0.0, 2.1.3)"
        exit 1
    fi
}

# Reads the current version from release-version.yml
get_current_version() {
    if [[ ! -f "release-version.yml" ]]; then
        print_error "release-version.yml not found in current directory"
        exit 1
    fi
    
    # Extract version from release-version.yml
    local version=$(grep "release-version:" release-version.yml | sed 's/release-version: *//' | tr -d ' ')
    echo "$version"
}

# Increments a version number based on the specified part (major/minor/patch)
increment_version() {
    local version=$1
    local part=$2
    
    # Split version into major.minor.patch components
    IFS='.' read -ra PARTS <<< "$version"
    local major=${PARTS[0]}
    local minor=${PARTS[1]}
    local patch=${PARTS[2]}
    
    # Increment the appropriate part and reset lower parts according to semver rules
    case $part in
        "major")
            major=$((major + 1))
            minor=0
            patch=0
            ;;
        "minor")
            minor=$((minor + 1))
            patch=0
            ;;
        "patch")
            patch=$((patch + 1))
            ;;
        *)
            print_error "Invalid version part. Use: major, minor, or patch"
            exit 1
            ;;
    esac
    
    echo "$major.$minor.$patch"
}

# =============================================================================
# FILE UPDATE FUNCTIONS
# =============================================================================

# Updates the version in release-version.yml
update_release_version_yml() {
    local new_version=$1
    print_info "Updating release-version.yml to $new_version"

    # Replace the version line in release-version.yml (macOS only)
    sed -i '' "s/release-version: .*/release-version: $new_version/" release-version.yml

    print_success "Updated release-version.yml"
}

# Updates the version in package.json
update_package_json() {
    local new_version=$1
    print_info "Updating package.json to $new_version"

    # Replace the version line in package.json (macOS only)
    sed -i '' "s/\"version\": \".*\"/\"version\": \"$new_version\"/" package.json

    print_success "Updated package.json version"
}

# =============================================================================
# GIT OPERATIONS
# =============================================================================

# Creates a commit with version changes and tags it
commit_and_tag() {
    local version=$1
    local commit_message="Release v$version"
    local tag_name="v$version"
    
    print_info "Staging version file changes..."
    git add release-version.yml package.json
    
    print_info "Creating commit: '$commit_message'"
    git commit -m "$commit_message"
    
    print_info "Creating tag: $tag_name"
    git tag "$tag_name"
    
    print_success "Created commit and tag for version $version"
}

# =============================================================================
# UI AND ORCHESTRATION FUNCTIONS
# =============================================================================

# Displays usage information and examples
show_usage() {
    echo "Blog Release Script"
    echo "==================="
    echo ""
    echo "Usage: $0 --part major|minor|patch"
    echo ""
    echo "Examples:"
    echo "  $0 --part major   # Increment major version (e.g., 1.2.3 -> 2.0.0)"
    echo "  $0 --part minor   # Increment minor version (e.g., 1.2.3 -> 1.3.0)"
    echo "  $0 --part patch   # Increment patch version (e.g., 1.2.3 -> 1.2.4)"
    echo ""
    echo "Current version: $(get_current_version)"
    echo ""
    echo "After running this script, deploy with:"
    echo "  git push origin v[NEW_VERSION]"
}

# Validates that the environment is ready for a release
validate_environment() {
    # Check if we're in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        print_error "Not in a git repository"
        exit 1
    fi
    
    # Check if working directory is clean (no uncommitted changes)
    if [[ -n $(git status --porcelain) ]]; then
        print_warning "Working directory has uncommitted changes."
        print_warning "Please commit or stash them before creating a release."
        echo ""
        git status --short
        exit 1
    fi
}

main() {
    # Validate arguments
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi

    # Validate environment before proceeding
    validate_environment
    
    # Get and display current version
    local current_version=$(get_current_version)
    print_info "Current version: $current_version"
    
    local new_version
    
    # Parse command line arguments
    if [[ $1 == "--part" ]]; then
        if [[ $# -ne 2 ]]; then
            print_error "When using --part, you must specify the version part to bump"
            print_error "Valid options: major, minor, patch"
            echo ""
            show_usage
            exit 1
        fi
        
        local part=$2
        case $part in
            "major"|"minor"|"patch")
                new_version=$(increment_version "$current_version" "$part")
                ;;
            *)
                print_error "Invalid version part: '$part'"
                print_error "Valid options: major, minor, patch"
                exit 1
                ;;
        esac
    else
        print_error "Invalid usage. You must specify --part with the version part to bump."
        echo ""
        show_usage
        exit 1
    fi
    
    # Display the planned version change
    print_info "Version change: $current_version → $new_version"
    echo ""
    
    # Confirm the action
    echo -n "Proceed with release $new_version? (y/N): "
    read -r confirmation
    if [[ ! $confirmation =~ ^[Yy]$ ]]; then
        print_info "Release cancelled"
        exit 0
    fi
    
    echo ""
    
    # Execute the release process
    update_release_version_yml "$new_version"
    update_package_json "$new_version"
    commit_and_tag "$new_version"
    
    echo ""
    print_success "Release $new_version created successfully!"
    print_info "To deploy this release, run:"
    print_info "  git push origin v$new_version"
}

# Execute main function with all provided arguments
main "$@"
