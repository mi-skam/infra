function cpr
    if test (count $argv) -eq 1
        set file $argv[1]
        if test -e $file
            cp $file $file.bak
            echo "Created backup: $file.bak"
        else
            echo "Error: $file does not exist."
        end
    else
        echo "Usage: cpr <filename>"
    end
end
