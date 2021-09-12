#!/bin/bash

# This environment variable is required to launch a virtual machine without sudo
# Providing at the top of our script allows us to script the launch of the virtual machine
# and then also launch looking glass
#
# Since I always shutdown my Windows VM from inside of looking glass I don't need a way to 
# kill these processes. The VM will kill and looking glass will close leaving me in an
# acceptable state for my system
#
# I use a terminal argument here so that you can launch many virtual machines with a single
# script, rather than having to customize all of them for each VM.

export LIBVIRT_DEFAULT_URI="qemu:///system"

virsh start $1

looking-glass-client
