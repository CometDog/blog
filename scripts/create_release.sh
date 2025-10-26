#!/bin/bash

set -e  # Exit on any error

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
DEFAULT='\033[0m'

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

validate_version_format() {
    if [[ ! $1 =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        print_error "Version must be in semantic version format (e.g., 1.0.0, 2.1.3)"
        exit 1
    fi
}

get_current_version() {
    if [[ ! -f "release-version.yml" ]]; then
        print_error "release-version.yml not found in current directory"
        exit 1
    fi
    
    # Extract version from YAML file
    local version=$(grep "release-version:" release-version.yml | sed 's/release-version: *//' | tr -d ' ')
    echo "$version"
}

increment_version() {
    local version=$1
    local part=$2
    
    IFS='.' read -ra PARTS <<< "$version"
    local major=${PARTS[0]}
    local minor=${PARTS[1]}
    local patch=${PARTS[2]}
    
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

update_release_version_yml() {
    local new_version=$1
    print_info "Updating release-version.yml to $new_version"

    # Only works on macOS sed
    sed -i '' "s/release-version: .*/release-version: $new_version/" release-version.yml

    print_success "Updated release-version.yml"
}

update_package_json() {
    local new_version=$1
    print_info "Updating package.json to $new_version"

    # Only works on macOS sed
    sed -i '' "s/\"version\": \".*\"/\"version\": \"$new_version\"/" package.json

    print_success "Updated package.json version"
}

commit_and_tag() {
    local version=$1
    local commit_message="Release v$version"
    local tag_name="v$version"
    
    print_info "Staging changes..."
    git add release-version.yml package.json
    
    print_info "Committing changes with message: '$commit_message'"
    git commit -m "$commit_message"
    
    print_info "Creating tag: $tag_name"
    git tag "$tag_name"
    
    print_success "Created commit and tag for version $version"
}

show_usage() {
    echo "Usage: $0 [--part major|minor|patch] | [version]"
    echo ""
    echo "Examples:"
    echo "  $0 --part major   # Increment major version (e.g., 1.2.3 -> 2.0.0)"
    echo "  $0 --part minor   # Increment minor version (e.g., 1.2.3 -> 1.3.0)"
    echo "  $0 --part patch   # Increment patch version (e.g., 1.2.3 -> 1.2.4)"
    echo ""
    echo "Current version: $(get_current_version)"
}

main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi

    # Check if working directory is clean
    if [[ -n $(git status --porcelain) ]]; then
        print_warning "Working directory has uncommitted changes. Please commit or stash them first."
        git status --short
        exit 1
    fi
    
    local current_version=$(get_current_version)
    print_info "Current version: $current_version"
    
    local new_version
    
    if [[ $1 == "--part" ]]; then
        if [[ $# -ne 2 ]]; then
            print_error "When using --part, you must specify the version part to bump (major, minor, or patch)"
            show_usage
            exit 1
        fi
        
        local part=$2
        case $part in
            "major"|"minor"|"patch")
                new_version=$(increment_version "$current_version" "$part")
                ;;
            *)
                print_error "Invalid version part: $part. Use: major, minor, or patch"
                exit 1
                ;;
        esac
    else
        # Part is required
        print_error "You may only specify the version part to bump using --part (major, minor, or patch)"
        exit 1
    fi
    
    print_info "New version will be: $new_version"
    
    echo -n "Proceed with release $new_version? (y/N): "
    read -r confirmation
    if [[ ! $confirmation =~ ^[Yy]$ ]]; then
        print_info "Release cancelled"
        exit 0
    fi
    
    update_release_version_yml "$new_version"
    update_package_json "$new_version"
    commit_and_tag "$new_version"
    
    print_success "Release $new_version created successfully!"
    print_info "To deploy, push the tag: git push origin v$new_version"
}

main "$@"
