#Overview

This is an attempt to document the steps needed to setup pci-passthrough, specifically for nvidia GPUS, and enable looking glass to access the new VM without the need for additional monitors, keyboards, and mice on OpenSUSE Tumbleweed.

There will of course be differences for other distros, but the concepts are hopefully the same.

The process is poorly documented, and fragmented, across many articles and blogs. My efforts lead me down many differen paths, with no clear inidication of what was missing when things went wrong. 

I hope to identify the issues that I ran in to, as well as the requirements to correct them as I discovered them.

# Steps

The entire process can be broken down in to several different phases. The two biggest ones are obviously Configuring PCI Passthrough, and Configuring Looking Glass. There are other pieces that are important to the entire process. First is Creating the VM. There are specific steps needed to get a VM that works with Looking Glass, and I spent a lot of time trying to figure out what I was doing wrong here. And even before that, we have the pre-requisites for both the VM and the Looking Glass software. These things don't just magically work, so knowing the required legwork to make it possible was a big part of the search. Thankfully, this was better documented than most parts, and didn't take too much thinking.

# OS of Choice

I am personally attached to rpm based distributions, and with the move that RedHat made recently to push CentOS in to a rolling release distribution, and expect people to join the RedHat developer platform, I wanted to find a different option. This lead me down the path to OpenSUSE which has the LTS version of Leap, and the Rolling Release version of Tumbleweed. Since I am doing this build on my personal desktop system I am using Tumbleweed.

# System Specs

Some of the documentation is catered specifically towards my hardware, but I am doing my best to include the pieces that would be needed for hardware other than my own. I am of course not going to be able to test every possibility, but I am making an effort.

* AMD Ryzen 9 5900X
* 32 GB DDR4 RAM
* ASUS TUF NVIDIA 3070 8 GB
* ASUS NVIDIA 980 TI

These are the major pieces of hardware that we will be focusing on. I'm not here to flex, just to inform. What's important from here is to make sure that you have enough storage space to support your VM with the OS and the software that you plan to install.

# References

OpenSUSE documentation on pci-passthrough
looking glass documentation

# Pre-Requisites

## System Requirements

## VM Software Requirements

## Creating the VM

## Preparing for Looking Glass

## Building the Looking Glass Client

## Configuring the VM for Looking Glass

## Configuring the Guest VM

## Installing Guest VM Software

## Finalzing and testing
