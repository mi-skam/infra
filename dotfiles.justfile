#!/usr/bin/env just --justfile
# Dotfiles Management (Separated from main infrastructure automation)
#
# This file contains all dotfiles-related recipes using GNU Stow for
# symlink management. Separated to maintain clear boundaries between
# infrastructure automation (Terraform/Ansible) and local workstation setup.
#
# IMPORTANT: Set STOW_TARGET environment variable before running recipes.
# Default behavior: If STOW_TARGET is not set, recipes will use ~ (home directory).
# This follows the fail-early principle - explicit is better than implicit.

# Variables
target := env_var_or_default("STOW_TARGET", "~")

# ============================================================================
# Dotfiles Management (Private Helpers)
# ============================================================================

# Apply GNU Stow operation to all dotfile packages (PRIVATE HELPER)
#
# Parameters:
#   flags - Stow flags to apply (e.g., "-v -R" for restow, "-v -D" for delete)
#
# This private helper consolidates the bash loop pattern used by 5 dotfiles
# recipes. It iterates through all directories in dotfiles/, treating each
# as a package, and applies the specified stow operation.
#
# Called by: install-dotfiles, uninstall-dotfiles, dry-run, restow
#
# The loop:
# - Skips non-directories
# - Strips trailing / from directory name to get package name
# - Prints progress for each package
# - Applies stow with provided flags and target directory
[private]
@_stow-all flags:
    #!/usr/bin/env bash
    cd dotfiles && for dir in */; do [ -d "$dir" ] && package="${dir%/}" && echo "  → $package" && stow {{flags}} -t {{target}} "$package"; done

# ============================================================================
# Dotfiles Management (Public Recipes)
# ============================================================================

# Install Homebrew packages and all dotfiles (full setup)
#
# Two-step installation process:
# 1. Installs Homebrew packages from dotfiles/brew/.Brewfile
# 2. Stows all dotfile packages to target directory
#
# This is the recommended command for setting up a new macOS machine.
# It ensures all dependencies (like GNU Stow itself) are installed before
# attempting to stow dotfiles.
#
# Target directory can be customized via STOW_TARGET env var (default: ~).
@install-all: install-brew install-dotfiles

# Install Homebrew packages from Brewfile
#
# Installs all packages, casks, and taps defined in dotfiles/brew/.Brewfile.
# This includes development tools, CLI utilities, and applications.
#
# The Brewfile typically contains:
# - brew "stow" (required for dotfiles management)
# - brew "git", "jq", "fzf", etc. (common CLI tools)
# - cask "visual-studio-code" (GUI applications)
#
# Safe to run multiple times - Homebrew skips already-installed packages.
@install-brew:
    echo "Installing Homebrew packages..."
    brew bundle --file=dotfiles/brew/.Brewfile

# Install all dotfiles using GNU Stow (symlink creation)
#
# Stows (symlinks) all dotfile packages from dotfiles/ to target directory.
# Uses -R flag (restow) which removes then re-creates symlinks, making it
# safe to run multiple times.
#
# Each package directory (e.g., dotfiles/zsh/) gets stowed separately:
# - dotfiles/zsh/.zshrc → ~/.zshrc
# - dotfiles/git/.gitconfig → ~/.gitconfig
#
# Depends on: ensure-stow (installs stow if missing)
# Uses: _stow-all helper with "-v -R" flags (verbose, restow)
@install-dotfiles: ensure-stow
    echo "Stowing dotfiles to {{target}}..."
    just _stow-all "-v -R"

# Uninstall all dotfiles by removing symlinks (DESTRUCTIVE)
#
# ⚠️  WARNING: This removes all symlinks created by stow, effectively
# uninstalling all dotfiles. Your original files in dotfiles/ remain safe,
# but the symlinks in your home directory will be deleted.
#
# Use cases:
# - Preparing to install different dotfiles
# - Troubleshooting stow conflicts
# - Cleaning up before system migration
#
# This does NOT delete actual config files - only removes symlinks.
# Uses -D flag (delete) to unstow all packages.
@uninstall-dotfiles:
    echo "Unstowing dotfiles from {{target}}..."
    just _stow-all "-v -D"

# Ensure GNU Stow is installed (dependency check)
#
# Checks if stow command is available in PATH. If not found, installs it
# via Homebrew. This is a dependency recipe called by install-dotfiles.
#
# GNU Stow is required for dotfiles management. It creates symlinks from
# the dotfiles/ directory to the target directory (usually ~).
#
# Silent when stow is already installed. Only outputs when installing.
@ensure-stow:
    command -v stow >/dev/null 2>&1 || brew install stow

# Simulate dotfiles installation without making changes (dry run)
#
# Performs a stow dry run using -n flag (no-op). Shows what symlinks would
# be created without actually creating them. Useful for:
# - Previewing changes before actual installation
# - Checking for conflicts with existing files
# - Verifying stow will do what you expect
#
# Output shows:
# - LINK actions that would be performed
# - Conflicts with existing files (errors)
#
# Safe to run anytime - makes no changes to filesystem.
@dry-run:
    echo "Simulating stow (dry run) to {{target}}..."
    just _stow-all "-n -v -R"

# Install a specific dotfile package by name
#
# Parameters:
#   package - Package directory name (e.g., "zsh", "git", "nvim")
#
# Example usage:
#   just install zsh     # Stow only zsh dotfiles
#   just install git     # Stow only git dotfiles
#   just install nvim    # Stow only neovim dotfiles
#
# Package must exist as a directory in dotfiles/. Use -R flag (restow)
# to safely update existing symlinks.
#
# For installing all packages at once, use install-dotfiles instead.
@install package:
    cd dotfiles && echo "Stowing {{package}} to {{target}}..." && stow -v -R -t {{target}} {{package}}

# Uninstall a specific dotfile package by name
#
# Parameters:
#   package - Package directory name to remove (e.g., "zsh", "git")
#
# Example usage:
#   just uninstall zsh   # Remove only zsh symlinks
#   just uninstall git   # Remove only git symlinks
#
# This removes symlinks for the specified package only, leaving other
# packages intact. Useful for:
# - Temporarily disabling a package
# - Testing different configurations
# - Troubleshooting specific package conflicts
#
# For removing all packages, use uninstall-dotfiles instead.
@uninstall package:
    cd dotfiles && echo "Unstowing {{package}} from {{target}}..." && stow -v -D -t {{target}} {{package}}

# Restow a specific dotfile package (refresh symlinks)
#
# Parameters:
#   package - Package name to restow (REQUIRED - must specify a package)
#
# Example usage:
#   just restow zsh      # Restow only zsh package
#   just restow git      # Restow only git package
#
# Restowing (stow -R) means:
# 1. Unstow (remove existing symlinks)
# 2. Stow (create new symlinks)
#
# Useful for:
# - Refreshing symlinks after updating dotfiles
# - Fixing broken symlinks
# - Applying changes to stow structure
#
# IMPORTANT: Package parameter is REQUIRED (no default value per user preference).
# To restow all packages, use: just install-dotfiles
@restow package:
    cd dotfiles && echo "Restowing {{package}}..." && stow -v -R -t {{target}} {{package}}

# Check for stow conflicts before installation
#
# Performs dry-run stow for all packages and reports any conflicts.
# A conflict occurs when:
# - Target file exists and is not a symlink
# - Target symlink points to different location
# - Directory structure prevents symlink creation
#
# Output:
# - Lists packages with conflicts (⚠ symbol)
# - Shows specific conflicting files/paths
# - Displays "✓ No conflicts found" if clean
#
# Always run this before install-dotfiles on a new system to identify
# files that need manual backup/removal.
@check:
    #!/usr/bin/env bash
    cd dotfiles && echo "Checking for conflicts..." && has_conflicts=false
    for dir in */; do [ -d "$dir" ] && package="${dir%/}" && stow -n -v -R -t {{target}} "$package" 2>&1 | grep -i conflict && has_conflicts=true && echo "  ⚠ $package"; done
    [ "$has_conflicts" = false ] && echo "✓ No conflicts found"

# Find and list broken symlinks in target directory
#
# Searches target directory (default: ~) for symlinks that point to
# non-existent files. These "dangling" symlinks typically occur after:
# - Uninstalling a package but leaving some symlinks
# - Moving/renaming files in dotfiles/ directory
# - Deleting source files while symlinks remain
#
# Search depth limited to 3 levels to avoid scanning entire filesystem.
# To remove broken symlinks manually:
#   find {{target}} -maxdepth 3 -type l ! -exec test -e {} \; -delete
#
# Run this occasionally to keep target directory clean.
@clean:
    echo "Finding broken symlinks in {{target}}..."
    find {{target}} -maxdepth 3 -type l ! -exec test -e {} \; -print

# Test dotfiles installation in a temporary directory
#
# Parameters:
#   tmpdir - Path to empty test directory (e.g., "/tmp/dotfiles-test")
#
# Example usage:
#   just test-install /tmp/test-dotfiles
#
# This installs dotfiles to a temporary directory instead of your home
# directory, allowing you to:
# - Verify dotfiles structure before real installation
# - Test changes to dotfiles/ without affecting current setup
# - Debug stow issues in isolated environment
#
# The tmpdir should be empty or non-existent (will be created).
# After testing, inspect with: ls -la /tmp/test-dotfiles
# Clean up with: rm -rf /tmp/test-dotfiles
@test-install tmpdir:
    #!/usr/bin/env bash
    echo "Testing dotfiles installation in {{tmpdir}}..." && mkdir -p {{tmpdir}}
    STOW_TARGET={{tmpdir}} just install-dotfiles
    echo "Installed files:" && find {{tmpdir}} -type l -ls
