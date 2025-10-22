#!/usr/bin/env just --justfile

# Target directory for stow (defaults to home)
target := env_var_or_default("STOW_TARGET", "~")

# List available recipes
@default:
    just --list

# Install all dotfiles
@install-all: install-brew install-dotfiles

# Install Homebrew packages
@install-brew:
    echo "Installing Homebrew packages..."
    brew bundle --file=dotfiles/brew/.Brewfile

# Install dotfiles using stow
@install-dotfiles: ensure-stow
    #!/usr/bin/env bash
    cd dotfiles
    echo "Stowing dotfiles to {{target}}..."
    for dir in */; do
        if [ -d "$dir" ]; then
            package="${dir%/}"
            echo "  → Stowing $package..."
            stow -v -R -t {{target}} "$package"
        fi
    done

# Uninstall dotfiles
@uninstall-dotfiles:
    #!/usr/bin/env bash
    cd dotfiles
    echo "Unstowing dotfiles from {{target}}..."
    for dir in */; do
        if [ -d "$dir" ]; then
            package="${dir%/}"
            echo "  → Unstowing $package..."
            stow -v -D -t {{target}} "$package"
        fi
    done

# Ensure stow is installed
@ensure-stow:
    command -v stow >/dev/null 2>&1 || brew install stow

# Simulate stow (dry run)
@dry-run:
    #!/usr/bin/env bash
    cd dotfiles
    echo "Simulating stow (dry run) to {{target}}..."
    for dir in */; do
        if [ -d "$dir" ]; then
            package="${dir%/}"
            echo "  → Dry run for $package..."
            stow -n -v -R -t {{target}} "$package"
        fi
    done

# Install a specific package
@install package:
    cd dotfiles && echo "Stowing {{package}} to {{target}}..." && stow -v -R -t {{target}} {{package}}

# Uninstall a specific package
@uninstall package:
    cd dotfiles && echo "Unstowing {{package}} from {{target}}..." && stow -v -D -t {{target}} {{package}}

# Restow (useful after adding new files)
@restow package="":
    #!/usr/bin/env bash
    cd dotfiles
    if [ -z "{{package}}" ]; then
        echo "Restowing all packages to {{target}}..."
        for dir in */; do
            if [ -d "$dir" ]; then
                package="${dir%/}"
                echo "  → Restowing $package..."
                stow -v -R -t {{target}} "$package"
            fi
        done
    else
        echo "Restowing {{package}} to {{target}}..."
        stow -v -R -t {{target}} {{package}}
    fi

# Check for conflicts
@check:
    #!/usr/bin/env bash
    cd dotfiles
    echo "Checking for conflicts in {{target}}..."
    has_conflicts=false
    for dir in */; do
        if [ -d "$dir" ]; then
            package="${dir%/}"
            if stow -n -v -R -t {{target}} "$package" 2>&1 | grep -i conflict; then
                has_conflicts=true
                echo "  ⚠ Conflicts found in $package"
            fi
        fi
    done
    if [ "$has_conflicts" = false ]; then
        echo "✓ No conflicts found"
    fi

# Clean broken symlinks in target directory
@clean:
    echo "Finding broken symlinks in {{target}}..."
    find {{target}} -maxdepth 3 -type l ! -exec test -e {} \; -print

# Test with a temporary directory
@test-install tmpdir="/tmp/dotfiles-test":
    #!/usr/bin/env bash
    echo "Testing dotfiles installation in {{tmpdir}}..."
    mkdir -p {{tmpdir}}
    STOW_TARGET={{tmpdir}} just install-dotfiles
    echo ""
    echo "Installed files in {{tmpdir}}:"
    find {{tmpdir}} -type l -ls