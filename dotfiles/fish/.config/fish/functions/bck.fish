function bck
    if test (count $argv) -lt 1
        echo "Usage: bck <file-or-dir> [file-or-dir ...]"
        return 1
    end

    for target in $argv
        if test -e $target
            set backup_path "$target.bak"
            mv -f $target $backup_path
            echo "Backup created: $backup_path"
        else
            echo "Error: '$target' does not exist."
        end
    end
end
