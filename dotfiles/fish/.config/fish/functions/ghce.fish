function ghce
    set -l GH_DEBUG "$GH_DEBUG"
    set -l GH_HOST "$GH_HOST"

    set -l __USAGE "
Wrapper around 'gh copilot explain' to explain a given input command in natural language.

USAGE
  ghce [flags] <command>

FLAGS
  -d, --debug      Enable debugging
  -h, --help       Display help usage
      --hostname   The GitHub host to use for authentication

EXAMPLES

# View disk usage, sorted by size
ghce 'du -sh | sort -h'

# View git repository history as text graphical representation
ghce 'git log --oneline --graph --decorate --all'

# Remove binary objects larger than 50 megabytes from git history
ghce 'bfg --strip-blobs-bigger-than 50M'
"

    set -l args (argparse 'd/debug' 'h/help' 'hostname=' -- $argv)
    or return

    for flag in $args
        switch $flag
            case -d --debug
                set GH_DEBUG "api"
            case -h --help
                echo "$__USAGE"
                return 0
            case --hostname
                set GH_HOST $args[(math (contains --hostname $args) + 1)]
        end
    end

    env GH_DEBUG="$GH_DEBUG" GH_HOST="$GH_HOST" gh copilot explain $argv
end