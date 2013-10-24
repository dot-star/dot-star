# Demo

## Version Control Agnostic
#### Git

    $ mkdir --parents /tmp/gitrepo
    $ cd /tmp/gitrepo
    $ git init
    Initialized empty Git repository in /tmp/gitrepo/.git/
    $ touch foo.txt
    $ add foo.txt
    $ commit -m "Add foo"
    [master (root-commit) 53c68d5] Add foo
     0 files changed
     create mode 100644 foo.txt
    $ log
    commit 53c68d554c14140065c18e933bd829a282475b53
    Author: User <user@example.com>
    Date:   Thu Oct 24 11:26:16 2013 -0700
    
        Add foo

#### Mercurial

    $ mkdir --parents /tmp/hgrepo
    $ cd /tmp/hgrepo
    $ hg init
    $ touch foo.txt
    $ add foo.txt
    adding foo.txt
    $ commit -m "Add foo"
    foo.txt
    committed changeset 0:9d695873ed2e
    $ log
    changeset:   0:9d695873ed2e
    tag:         tip
    user:        User <user@example.com>
    date:        Thu Oct 24 11:28:43 2013 -0700
    files:       foo.txt
    description:
    Add foo
