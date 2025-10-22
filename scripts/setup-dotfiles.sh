#!/usr/bin/env bash
set -euo pipefail

DOTFILES_ROOT="$(pwd)"

echo "Install"

main () {
  submodules
  symlinks
  platform
  generic
}

submodules () {
  echo "Initialising submodules"
  git submodule init && git submodule update
}

platform () {
  platform="unknown"
  if [[ "$(uname)" == "Darwin" ]]; then
     platform="macos"
  elif [[ "$(uname -s | cut -c1-5)" == "Linux" ]]; then
     platform="linux"
  elif [[ "$(uname -s | cut -c1-10)" == "MINGW32_NT" ]]; then
      platform="windows"
  fi

  echo "Running installers for $platform"

  fd -t f "$platform.sh" . | while IFS= read -r installer; do echo "$installer" && sh "$installer"; done
}

generic () {
  echo "Running generic installers"

  fd -t f "all.sh" . | while IFS= read -r installer; do sh "$installer" > /dev/null; done
}

symlinks () {
  echo "Create symlinks"

  overwrite_all=false
  backup_all=false
  skip_all=false

  while IFS= read -r -d '' source; do
    dest="$HOME/.$(basename "${source%.*}")"

    if [ -f "$dest" ] || [ -d "$dest" ]; then

      overwrite=false
      backup=false
      skip=false

      if [ "$overwrite_all" = "false" ] && [ "$backup_all" = "false" ] && [ "$skip_all" = "false" ]; then
          user "File already exists: $(basename "$source"), what do? [s]kip, [S]kip all, [o]verwrite, Overwrite [a]ll, [b]ackup, [B]ackup all?"
          read -n 1 action

          case "$action" in
            o )
              overwrite=true;;
            O )
              overwrite_all=true;;
            b )
              backup=true;;
            B )
              backup_all=true;;
            s )
              skip=true;;
            S )
              skip_all=true;;
            * )
              ;;
          esac
      fi

      if [ "$overwrite" = "true" ] || [ "$overwrite_all" = "true" ]; then
        rm -rf "$dest"
        success "removed $dest"
      fi

      if [ "$backup" = "true" ] || [ "$backup_all" = "true" ]; then
        mv "$dest" "$dest.backup"
        success "moved $dest to $dest.backup"
      fi

      if [ "$skip" = "false" ] && [ "$skip_all" = "false" ]; then
        link_files "$source" "$dest"
      else
        success "skipped $source"
      fi

    else
      link_files "$source" "$dest"
    fi

  done < <(fd -t f -d 2 --extension symlink . "$DOTFILES_ROOT" -0)
}

link_files () {
  ln -s "$1" "$2"
  success "linked $1 to $2"
}

user () {
  printf "\r  [ \033[0;33m?\033[0m ] $1 "
}

success () {
  printf "\r\033[2K  [ \033[00;32mOK\033[0m ] $1\n"
}

main