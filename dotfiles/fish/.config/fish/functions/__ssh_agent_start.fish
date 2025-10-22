function __ssh_agent_start -d "start a new ssh agent"
ssh-agent -c | sed 's/^echo/#echo/' >$SSH_ENV
chmod 600 $SSH_ENV
source $SSH_ENV >/dev/null

# Create a symlink to SSH_AUTH_SOCK
ln -sf "$SSH_AUTH_SOCK" ~/.ssh/auth_sock
end
