# Overview

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

Nothing is going to work straight out of the box, that would be too easy. I am going to start with the requirements of the system you are using, and then have the software requirements listed after. The idea is that if you satisify the requirements in this order, you shouldn't have to worry about it at a later stage. That's the theory anyway.

## System Requirements

None of what this guide is trying to do matters if your CPU doesn't support direct access virtualization technology. In the year 2021, I would certainly hope that this isn't something that you have to actually think about when buying processors, but we are still going to take the time to check.

Intel calls their technology `VT-d` and AMD is `AMD-V`. While your system might support these features, there is no guarantee that it is enabled by default. We can check for the feature using a simple terminal command:

If you are using an Intel CPU:

	sudo grep --color vmx /proc/cpuinfo

If you are using an AMD CPU:

	sudo grep --color svm /proc/cpuinfo

If these commands do not return a result, you likely need to enable the feature in your system BIOS. After doing that, these will confirm that you have virtualization technology available for the coming steps

### Configure the System

Now that we are sure that the system supports virtualization, we can set some of the required parameters. First we have to enable `IOMMU` so that we can get the performance benefit of connecting a GPU directly to our VM.

This configuration is set my modifying the GRUB boot parameters to enable these configurations at boot time.

We are going to edit the `/etc/default/grub` config file and make the following changes:


For Intel based systems:

        GRUB_CMDLINE_LINUX="intel_iommu=on iommu=pt rd.driver.pre=vfio-pci"

For AMD based system:

        GRUB_CMDLINE_LINUX="iommu=pt amd_iommu=on rd.driver.pre=vfio-pci"

After the change is made the grub configuration has to be updated with the following command:

        sudo grub2-mkconfig -o /boot/grub2/grub.cfg

Reboot for the changes to take effect and then check that our virtualization is ready for use:

        dmesg | grep -e iommu


This command should give you an output that lists the kernel boot image and commands, and gives the iommu groups that the system is using. 

### Isolate the graphics card

Once the ability to passthrough a PCI device is configured, we can now work on isolating the card that we are going to give to our VM.

To do that we need to use `lspci` to find the graphics card that we want, and the PCI bus that it is connected to.

        sudo lspci | grep -i vga

This command will return all of the PCI devices on the system that are VGA devices. On the far left we will have the bus that we want to work with.
There is also an audio device connected to the graphics card, that we want to pass through to the VM. It's not a requirement, but I like to be complete. 

To get the audio device, we have to use `lspci` again to list the devices that share the bus with our desired video card. In my case, I want to pass the 980TI through to my VM so it's bus 4:00

        sudo lspci | grep -i 4:00

This shows that there is an audio device that we can pass through, and we will need these bus numbers for the VM configurations later. 

Before that though, we need the device ids of these two devices, so that we can have the vfio driver connect to them at startup. We can use `lspci` to get that information as well, and it takes a small edit to our previous command

        sudo lspci -nn | grep -i 4:00

You can see that we now have vendor and device id information displayed in our output. Both of these items are going to go in to a configuration file so that they are assigned the vfio driver, and not the nvidia driver.

We do that by creating a configuration file in the `/etc/modeprobe.d/` directory and adding these ids as devices for the vfio-pci driver

        echo "options vfio-pci ids=10de:17c8 10de:0fb0" | sudo tee /etc/modprobe.d/vfio.conf >> /dev/null

This will load up the proper driver when the device is initialized.

One more step to actually get these drivers and devices to load up properly is including them in the initrd file. 

We are going to create another configuration file to handle this for us, this time in the `/etc/dracut.conf.d/` directory.

        echo 'add_drivers+="vfio vfio_iommu_type1 vfio_pci vfio_virqfd"' | sudo tee /etc/dracut.conf.d/gpu-passthrough.conf >> /dev/null

And then regenerate the initrd file

        sudo dracut --force /boot/initrd $(uname -r)

At this point you can reboot the machine and verify that the graphics card is being assigned the proper vfio-pci driver.
On OpenSUSE this is done with the `hwinfo --gfxcard` command, and checking the `Driver:` line of the appropriate card. If it's working properly, you should see:

        Driver: "vfio-pci"
        Driver Modules: "vfio-pci"

If the driver is not loading at this point, we have another place where we can put the driver loading in the `/etc/modules-load.d/` directory

For my AMD based system, this is the command that I needed:

        echo -e "vfio \nvfio_iommu_type1 \nvfio_pci \nkvm \nkvm_amd" | sudo tee /etc/modules-load.d/vfio-pci.conf >> /dev/null

For an Intel base system, a single item needs to be changed:

        echo -e "vfio \nvfio_iommu_type1 \nvfio_pci \nkvm \nkvm_intel" | sudo tee /etc/modules-load.d/vfio-pci.conf >> /dev/null

Some, older, guides will say that you also need to include `pci_stub` in this list, but it is included in the kernel at this point and is not needed here.

After making this change, restart the system and check the driver status of your graphics card again. This should now give you the result that you want.


## VM Software Requirements

You can't create VMs without the proper software on your sytem. For this guide I used `virt` and `virt-manager`, so that I have a nice GUI at the end of it. The software pieces that were needed are:

* libvirt
* virt-manager
* kvm
* qemu-kvm
* qemu-ovmf

This last item gives us EFI support in our VMs which is essential for Looking Glass to function properly. I spent a lot of time going in circles before I realized this.

And these can be installed with the command:

        sudo zypper in libvirt virtmanager kvm qemu-kvm qemu-ovmf-x86_64

SUSE recommends disabling MSR(Model Specific Register) if you are creating Windows guests, and since that is my plan, I am going to follow this advice.
I put this in this area because it goes with the configurations necessary to make the VM actually work, though it could go earlier. I might move this, but probably not.

        echo "options kvm ignore_msrs=1" | sudo tee /etc/modprobe.d/kvm.conf >> /dev/null

At this point we are ready to start working on the VM, and we just need to start the `libvirtd` service

        sudo systemctl start libvirtd

If you want to have the service start when your system boots

        sudo systemctl enable libvirtd

And we are set to move on.

## Creating the VM

Now we start getting in to the fun part, actually working on our guest VM. With all of the prerequisites installed, and the system options set, we can turn towards actually creating the VM that will have our GPU getting passed in to it.

From here I initially used `virt-manager` to build my VM through the GUI, so will include those steps first. It is possible to do all of these steps using `virt-install` but I do not currently have those steps available to me, becuase I didn't do it!

## Preparing for Looking Glass

## Building the Looking Glass Client

## Configuring the VM for Looking Glass

## Configuring the Guest VM

## Installing Guest VM Software

## Finalzing and testing
