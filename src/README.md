# Overview

This is the source for all of the automation related to the configuration steps. If you don't want to go through
all the hassle of doing it by hand, this is where the place for you. 

# Goals

Provide easy automation through bash scripts and/or ansible to set up and configure the system.

# Requirements

- j2cli

The `.desktop` file is created using jinja2 templates, and we accomplish this with `j2cli`

    pip install j2cli

Once you have `j2cli` installed, update the `user.yml` file with the name of your vm.

You can generate, and place, the desktop file by using the following command

    j2 win10efi.desktop.j2 user.yml -o $HOME/.local/share/applications/win10efi.desktop

This will create the working desktop file in your personal applications directory. This
will cause it to show up in your Applications List for easy access through the GUI
