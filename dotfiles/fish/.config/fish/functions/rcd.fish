function rcd
  set -f dir "/tmp/$(uuidgen)"
  mkdir -p "$dir"
  cd "$dir"
end
