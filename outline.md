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

FOR NOW, I'm going to skip how to create a VM through the GUI because I'm lazy and don't want to do a bunch of screen grabs. I will leave the requirements for the created VM and a couple bits of advice.

ADVICE: On the last screen before it starts creating and installing the VM, make sure you check the box to customize the VM before installing. You will lose access to some of the settings after the VM is created, and they are important.

VM REQUIREMENTS & SUGGESTIONS:

* CPU: I used 4 cores for testing, but will likely increase this to 8 for actual use
* RAM: I'm using 8 GB, 8192 MB, at the moment. The system is very response still, and this can alos be increased later
* CHIPSET: Q35. This can not be changed later and should be set right away
* BIOS: UEFI x86_64
    * /usr/share/qemu/ovmf-x86_64-smm-ms-code.bin
    * Based on the names of these UEFI files, this appears to be geared towards Microsoft systems
* GRAPHIC: Spice
* VIDEO: qxl
* NETWORK: Set the NIC to use the `virtio` device model
* PCI DEVICE: You can add the GPU that you are wanting to passthrough before the system is installed.

After you do these configurations you can begin the installation. If all is well, it should take a few moments, and then start booting the VM. Allow the `Push any key to boot from CD or DVD` screen to timeout, so that you get the prompt to enter the BIOS. Once in the BIOS disable Secure Boot, save your settings, and exit. The system will reset, and this time you want to boot from DVD.

Follow the prompts to install Windows, and prepare for the next step in our adventure.

You can go ahead and install the drivers for your graphics card at this point, and it should already be outputting to the external display. Congratulations! You have cleared one of the major hurdles and are one step closer to getting this completed.

## Preparing for Looking Glass

Looking Glass is a wonderful piece of software that allows you to grab the output from a VM on your system and use it without the need for an external monitor, keyboard, and mouse. It behaves as a part of your main system, but gets the benefits of being graphically accellerated.

As with the previous steps there are some pieces that we want to get configured before we move forward just to make our lives a little bit easier.


These are all of the packages that we are going to use to build the looking glass linux client in the next step. Some of these package names are very different from their Debian counterparts, which is what the creator of looking glass uses, so make sure you adhere to this list for OpenSUSE systems.

OpenSUSE does not use Wayland, and nvidia plays dirty with it anyway, so those dependencies are not included in this list.

* cmake
* make
* gcc
* pkgconf
* pkgconf-pkg-config
* clang
* Mesa-libEGL
* Mesa-libEGL1-devel
* free-ttf-fonts
* fontconfig-devel
* gmp-devel
* libspice-server-devel
* libnettle-devel
* libX11-devel
* libXfixes-devel
* libXi-devel
* libXinerama-devel
* libXss-devel

The below command will install all of the packages in one shot for you, so that you don't have to do the guesswork.

        sudo zypper in cmake make gcc pkgconf-pkg-config clang Mesa-libEGL-devel Mesa-libEGL1 free-ttf-fonts fontconfig-devel gmp-devel libspice-server-devel libnettle-devel libX11-devel libXfixes-devel libXi-devel libXinerama-devel libXss-devel

There is also a special file that we need to create in order for Looking Glass to communicate with our VM. By default, your user does not have access to this file, and it will cause permission errors when you try to run Looking Glass. So, we are going to create it ahead of time, and give it the proper permissions. We are not going to just create a file though, we are going to create a systemd tmpfile using the `systemd-tmpfiles` command. But first, we have to create the config file that will properly create the tmpfile that we need.

        echo -e "#Type Path               Mode UID  GID Age Argument \n" | sudo tee /etc/tmpfiles.d/10-looking-glass.conf
        echo -e "f /dev/shm/looking-glass 0660 $(whoami) kvm -" | sudo tee -a /etc/tmpfiles.d/10-looking-glass.conf

This creates our needed configuration file. Next we will create the shared memory file for looking glass to use

        sudo systemd-tmpfiles --create

And we are set to move on to the next piece. You can verify that the file was created properly with `ls -l`

        ls -l /dev/shm

This will show you the proper permissions for your user and the `kvm` group on the newly created `looking-glass` file

## Building the Looking Glass Client

Once we have the dependencies installed the looking glass client can be built

### First: Download the source code for Linux

At the time of the writing the stable version was B4, and will be used through this document. The latest version can be always be downloaded from the [Looking Glass Download Page](https://looking-glass.io/downloads).

* Download the B4 version of the linux source code

        curl https://looking-glass.io/ci/host/source?id=715 --output ~/Downloads/lookingglassB4.tar.gz

  This gives you a tarball to work with in our Downloads folder.

* Extract the `tar.gz` 

        tar -xf ~/Downloads/lookingglassB4.tar.gz -C ~/

  This will create a folder in your home directory named `looking-glass-B4`

* Navigate to the source directory that was just extracted

        cd ~/looking-glass-B4

* Create the required build directory

        mkdir client/build

* Navigate in to this build directory

        cd client/build

* Configure the build for the Looking Glass client

        cmake -DENABLE_BACKTRACE=no  ../

  This step disabled the backtrace capability of the client. This causes a lot of problmes when building, and to avoid them, we are simply disabling it. I will enable them once I work out what is causing the issues and those notes will be added to this guide

* Build the Looking Glass Client

        make

The Looking Glass client is now built! There is a binary named `looking-glass-client` in the build directory. You can move this binary anywhere you want to run looking glass, and we are going to move it to the home directory now

        cp looking-glass-client ~/

We can now launch the client from home home directory in the terminal by typing:

        ./looking-glass-client

Doing that now will not give us anything useful. We now need to do the looking glass configuration to pull it all together.


## Configuring the VM for Looking Glass

At this point we have a functioning VM with GPU Passthrough working, and the Looking Glass client built. Now we can start connecting the two together, to create our ideal environment.

That start with configuring `libvirt`, our VM, with some special looking glass devices.

First we have to create a shared memory device that looking glass will use to communicate with the VM. The size of the shared memory changes based on the resolution that you wanting to run at. For a 1920x1080 resolution a 32 MB shared memory device is all we need. If you need a different memory size, the [Determining Memory](https://looking-glass.io/docs/stable/install/#client-determining-memory) section of the Looking Glass documentation has a very simple example of how to size this properly.

In order to add this device we need to edit the configuration files directly using the `virsh` command

        sudo virsh edit <vm>

Here `<vm>` corresponds to the name that we gave our VM when we created it.
This command will open up the xml configuration for us to edit.
For simplicity, we will scrolls to the bottom of the document, and look for the `</devices>` tag.
We want to make our addition directly above this, and match the indetations in the file.

        <shmem name='looking-glass'>
          <model type='ivshmem-plain'/>
          <size unit='M'>32</size>
        </shmem>

Along with the shared memory device, we want to enable the SPICE guest tools so that we get clipboard synchronization, by adding a special `channel` device.
Before creating this device, you need to make sure that the there are no other serial devices in your VM. If there are, go ahead and remove them. If you need them, they can be added back afterwards.

Add the following lines to the configuration using `sudo virsh edit <vm>` again, and place it just above the `</devices>` tag again.

        <channel type="spicevmc">
          <target type="virtio" name="com.redhat.spice.0"/>
          <address type="virtio-serial" controller="0" port="1"/>
        </channel>

With these configuration changes finished, we can do a few more small tweaks to our VM before loading it up and doing some of the final steps.

* If there is a tablet device, remove it
* Make sure that you have a mouse device
* Add a Keyboard device with the type of `virtio`
  This gives better keyboard performance inside of the VM

This will finish the configuration that we need to do from outside of our VM. We can now put the finishing touches on the VM itself!

## Configuring the Guest VM

Now that all of THAT is behind us, we can start working inside of our VM again. Fire it up and use `virt-manager` to connect to the VM.

Once we are logged in to the Windows machines there are a few things that we need to take care of. 

1. Download the IVSHMEM driver package: [IVSHMEM Windows Driver](https://fedorapeople.org/groups/virt/virtio-win/direct-downloads/upstream-virtio/virtio-win10-prewhql-0.1-161.zip)
2. Extract the zip file to a location that you can remember on the VM. Desktop or Documents are suggested.
3. Open the Device Manager and find teh `PCI Standard RAM Controller` under the `System Devices` node. 
4. Right click on the device and update the driver
5. Select "Search my computer for a driver" and navigate to where you extracted it. 
   Make sure that you have "include subfolders" selected
6. Click `OK`

This will install the IVSHMEM driver to enable looking glass

Next, we need to get the Looking Glass Windows application and install it

1. Downalod the B4 Windows Application from Looking Glass: [Looking Glass Windows Software](https://looking-glass.io/ci/host/download?id=715)
2. Run the installer as an Administrator
3. That's it. The Looking Glass agent is now running as a service on your VM

To finalize our shared clipboard configuration that we enabled earlier, you need to install the SPICE agent on the VM

1. Download the Spice Agent Installer: [Spice Agent Windows Installer](https://www.spice-space.org/download/windows/spice-guest-tools/spice-guest-tools-latest.exe)
2. Run the installer as an administrator

That is the end of the configuration for the VM. All of the hard work is now done, and we are ready for the moment of truth.

## Finalizing and testing

Now that we have done all of the configuration work, it is time for the last steps and testing.

1. If the VM is running, shut it down.
2. In `virt-manager` change your VMs `video` device from `qxl` to `none`. You will have to type `none` in to the drop down, becuase it's not a normal option.
3. Apply the change
4. Start the VM
5. In a terminal window navigate to your home directory. `cd ~/` if you already have one open
6. Launch the looking glass client with the following command

        ./looking-glass-client

If everything is configured correctly, you should see the looking glass window open up, and your VM loading inside of it. 
You can now disconnect any external monitors that you have, and enjoy your new integrated VM experience!
