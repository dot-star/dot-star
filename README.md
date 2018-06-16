# dot-star

## Install

    mkdir -p ~/Projects
    cd ~/Projects
    git clone https://github.com/dot-star/dot-star.git
    cd dot-star
    ./install.sh

## Examples

### Search for files by file name

    $ f filter
    Searching paths and filenames containing "*filter*":
    ./admin/static/admin/js/SelectFilter2.js
    ./admin/templates/admin/filter.html
    ./admin/filters.py
    ./admindocs/templates/admin_doc/template_filter_index.html

### Search for files containing text

    $ s "admin.ModelAdmin"
    ./admin.py:26:class GroupAdmin(admin.ModelAdmin):
    ./admin.py:41:class UserAdmin(admin.ModelAdmin):

### Search for files containing text and edit

    $ se "admin.ModelAdmin"
    (file admin.py contains search keyword and is opened)

### Case-sensitive search for files containing text

    $ ss keyword

### Song duration added to `file' command

    $ file "Out of it All by Helen Jane Long.mp3"
    Out of it All by Helen Jane Long.mp3: Audio file with ID3 version 2.4.0, contains:MPEG ADTS, layer III, v2, 160 kbps, 22.05 kHz, Monaural (4,832,126 bytes)
    0:04:38

## Update

    dotstar
    ./update.sh

The installation and update may be run repeatedly. Neither action will remove nor overwrite files outside the dotstar directory.

## Compatibility
- Mac
- Ubuntu

## Mission

    There should be one-- and preferably only one --command to do it.
