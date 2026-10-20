# Include extras when available.
[ -r ~/.dot-star/tools/bash/extra.sh ] && . ~/.dot-star/tools/bash/extra.sh
# Include machine-local extras, tracked in no repo, when available.
[ -r ~/.dot-star/tools/bash/extra.local.sh ] && . ~/.dot-star/tools/bash/extra.local.sh
