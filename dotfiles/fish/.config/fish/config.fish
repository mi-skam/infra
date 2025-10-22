# GLOBAL 
set -g fish_escape_delay_ms 300 # hack to make esc-dot possible in fish
set -g fish_greeting # remove hello fish text

set -x GPG_TTY (tty)
set -x GOOGLE_CLOUD_PROJECT "n8n-eval"

# Start or re-use gpg-agent
gpgconf --launch gpg-agent
