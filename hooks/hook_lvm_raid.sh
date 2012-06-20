#!/bin/sh

# Copyright (C) 2012 Jonathan Vasquez
#
# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.

# Application Info
JV_APP_NAME="Bliss Initramfs Creator"
JV_AUTHOR="Jonathan Vasquez"
JV_EMAIL="jvasquez1011@gmail.com"
JV_CONTACT="${JV_AUTHOR} <${JV_EMAIL}>"
JV_VERSION="1.4.0"
JV_LICENSE="MPL 2.0"

# Used only for documentation purposes
JV_EXAMPLE_KERNEL="3.4.0-DESKTOP"

# Parameters and Locations
KERNEL_NAME="${1}"
ZFS_POOL_NAME="${2}"
MOD_PATH="/lib/modules/${KERNEL_NAME}/"
HOME_DIR="$(pwd)"
TMPDIR="${HOME_DIR}/tempinit/"
TYPE="LVM-RAID"
HOOK="init-lvm-raid"
INITRAMFS_FILE="${HOME_DIR}/${TYPE}-${KERNEL_NAME}.img"

JV_LOCAL_BIN="bin/"
JV_LOCAL_SBIN="sbin/"
JV_LOCAL_LIB="lib/"
JV_LOCAL_LIB64="lib64/"
JV_BIN="/bin/"
JV_SBIN="/sbin/"
JV_LIB32="/lib/"
JV_LIB64="/lib64/"
JV_USR_BIN="/usr/bin/"
JV_LOCAL_MOD="lib/modules/${KERNEL_NAME}/"

# Get CPU Architecture
JV_CARCH="$(uname -m)"

# Basically a boolean that is used to switch to the correct library path
# Defaults to 32 bit
JV_LIB_PATH=32

# Required Binaries, Modules, and other files
JV_INIT_BINS="busybox hostid lvm.static mdadm mdassemble mdmon"
JV_INIT_MODS=""
BUSYBOX_TARGETS="mount tty sh"


# Message that will be displayed at the top of the screen
headerMessage() {
    echo "##################################"
    echo "${JV_APP_NAME} ${JV_VERSION}"
    echo "Author: ${JV_CONTACT}"
    echo "Released under the ${JV_LICENSE} license "
    echo "##################################\n"
}
# Message for displaying the generating event
startMessage() {
    echo "Generating initramfs for ${KERNEL_NAME}\n"
}

# Some error functions
errorBinaryNoExist() {
    echo "Binary: ${1} doesn't exist. Quitting!" && cleanUp && exit
}

errorModuleNoExist() {
    echo "Module: ${1} doesn't exist. Quitting!" && cleanUp && exit
}

# Check to see if "${TMPDIR}" exists, if it does, delete it for a fresh start
# Utility function to return back to home dir and clean up. For exiting on errors
cleanUp() {
    cd ${HOME_DIR}

    if [ -d ${TMPDIR} ]; then
        rm -rf ${TMPDIR}
        
        if [ -d ${TMPDIR} ]; then
            echo "Failed to delete the directory. Exiting..." && exit
        fi
    fi
}

# Check to make sure that there is only 1 parameter for displaying help messages
# or that there is the required amount of parameters to trigger the build
getParameters() {
    if [ ${#} -eq 1 ]; then
        # for loop that checks all parameters matching something
        # i would be the mode, and i+1 would be the mode type
        for X in ${@}; do
            
        if [ "${1}" = "--version" ]; then
            echo "${JV_VERSION}" && exit
        elif [ "${1}" = "--author" ] || [ "${1}" = "-a" ]; then
            echo "${JV_CONTACT}" && exit
        elif [ "${1}" = "--help" ] || [ "${1}" = "-h" ]; then
            echo "${JV_APP_NAME} ${JV_VERSION}"
            echo "By ${JV_CONTACT}"
            echo ""
            echo "Usage: createInit <Kernel Name> <ZFS Pool Name>"
            echo "Example: createInit ${JV_EXAMPLE_KERNEL} rpool"
            echo ""
            echo "-h, --help    - This help screen"
            echo "-a, --author  - Author of Application" && exit
            echo "    --version - Application Version"
        elif [ "${1}" = "--lvm" ]; then
            LVM_RUN=1;
        fi
        done
    elif [ "${#}" -lt 1 ] || [ "${#}" -gt 2 ]; then
        echo "Usage: createInit <Kernel Name> <ZFS Pool Name>. Example: createInit ${JV_EXAMPLE_KERNEL} rpool" && exit
    fi

    # createInit -t zfs/btrfs/lvm/lvm-mdadm -p <zfs_pool_name> or <lvm_volume_group_name>
    # createInit --help
}

# If x86_64 then use lib64 libraries, else use 32 bit
getArchitecture() {
    case ${JV_CARCH} in
    x86_64)
        JV_LIB_PATH=64
        echo "Detected ${JV_LIB_PATH} bit platform\n"
        ;;
    i[3-6]86)
        JV_LIB_PATH=32
        echo "Detected ${JV_LIB_PATH} bit platform\n"
        ;;
    *)
        echo "Your architecture isn't supported, exiting\n" && cleanUp && exit
        ;;
    esac
}

# Check to make sure kernel modules directory exists
checkForModulesDir() {
    echo "Checking to see if modules directory exists for ${KERNEL_NAME}\n"

    if [ ! -d ${MOD_PATH} ]; then
        echo "Kernel modules directory doesn't exist for ${KERNEL_NAME}. Quitting\n" && exit
    fi
}

# Create the base directory structure for the initramfs
createDirectoryStructure() {
    echo "Creating directory structure for initramfs\n"

    mkdir ${TMPDIR} && cd ${TMPDIR}
    mkdir -p bin sbin proc sys dev etc lib mnt/root ${JV_LOCAL_MOD} 

    # If this computer is 64 bit, then make the lib64 dir as well
    if [ "${JV_LIB_PATH}" = "64" ]; then
        mkdir lib64
    fi
}

# Checks to see if the binaries exist
checkBinaries() {
    for X in ${JV_INIT_BINS}; do
        if [ ${X} = hostid ]; then
            if [ ! -f "${JV_USR_BIN}/${X}" ]; then
                errorBinaryNoExist ${X}
            fi
        elif [ ${X} = busybox ]; then
            if [ ! -f "${JV_BIN}/${X}" ]; then
                errorBinaryNoExist ${X}
            fi
        else
            if [ ! -f "${JV_SBIN}/${X}" ]; then
                errorBinaryNoExist ${X}
            fi
        fi
    done
}

# Checks to see if the spl and zfs modules exist
checkModules() {
    for X in ${JV_INIT_MODS}; do 
        if [ "${X}" = "spl" ] || [ "${X}" = "splat" ]; then
            if [ ! -f "${MOD_PATH}/addon/spl/${X}/${X}.ko" ]; then
                errorModuleNoExist ${X}
            fi
        elif [ "${X}" = "zavl" ]; then
            if [ ! -f "${MOD_PATH}/addon/zfs/avl/${X}.ko" ]; then 
                errorModuleNoExist ${X}
            fi
        elif [ "${X}" = "znvpair" ]; then
            if [ ! -f "${MOD_PATH}/addon/zfs/nvpair/${X}.ko" ]; then 
                errorModuleNoExist ${X}
            fi
        elif [ "${X}" = "zunicode" ]; then
            if [ ! -f "${MOD_PATH}/addon/zfs/unicode/${X}.ko" ]; then 
                errorModuleNoExist ${X}
            fi
        else 	
            if [ ! -f "${MOD_PATH}/addon/zfs/${X}/${X}.ko" ]; then 
                errorModuleNoExist ${X}
            fi
        fi
    done
}

# Copy the required binary files into the initramfs
copyBinaries() {
    echo "Copying binaries...\n"

    for X in ${JV_INIT_BINS}; do
	    if [ "${X}" = "hostid" ]; then
		        cp ${JV_USR_BIN}/${X} ${JV_LOCAL_BIN}
	    elif [ "${X}" = "busybox" ]; then
		        cp ${JV_BIN}/${X} ${JV_LOCAL_BIN}
        else
	            cp ${JV_SBIN}/${X} ${JV_LOCAL_SBIN}
	    fi
    done
}

# Copy the required modules to the initramfs
copyModules() {
    echo "Copying modules...\n"

    for X in ${JV_INIT_MODS}; do
        if [ "${X}" = "spl" ] || [ "${X}" = "splat" ]; then
	        cp ${MOD_PATH}/addon/spl/${X}/${X}.ko ${JV_LOCAL_MOD}
	    elif [ "${X}" = "zavl" ]; then
		    cp ${MOD_PATH}/addon/zfs/avl/${X}.ko ${JV_LOCAL_MOD} 
	    elif [ "${X}" = "znvpair" ]; then
		    cp ${MOD_PATH}/addon/zfs/nvpair/${X}.ko ${JV_LOCAL_MOD}
	    elif [ "${X}" = "zunicode" ]; then
		    cp ${MOD_PATH}/addon/zfs/unicode/${X}.ko ${JV_LOCAL_MOD}
	    else 	
		    cp ${MOD_PATH}/addon/zfs/${X}/${X}.ko ${JV_LOCAL_MOD}
	    fi 
    done
}

# Copy all the dependencies of the bianry files into the initramfs
copyDependencies() {
    echo "Copying dependencies...\n"

    for X in ${JV_INIT_BINS}; do
	    if [ "${X}" = "busybox" ] || [ "${X}" = "hostid" ]; then
            if [ "${JV_LIB_PATH}" = "32" ]; then
		        DEPS="$(ldd bin/${X} | awk ''${JV_LIB32}' {print $1}' | sed -e "s%${JV_LIB32}%%")"
            else
		        DEPS="$(ldd bin/${X} | awk ''${JV_LIB64}' {print $1}' | sed -e "s%${JV_LIB64}%%")"
            fi
	    else
            if [ "${JV_LIB_PATH}" = "32" ]; then
		        DEPS="$(ldd sbin/${X} | awk ''${JV_LIB32}' {print $1}' | sed -e "s%${JV_LIB32}%%")"
            else
		        DEPS="$(ldd sbin/${X} | awk ''${JV_LIB64}' {print $1}' | sed -e "s%${JV_LIB64}%%")"
            fi
	    fi 

	    for Y in ${DEPS}; do
            if [ "${JV_LIB_PATH}" = "32" ]; then
		        cp -Lf ${JV_LIB32}/${Y} ${JV_LOCAL_LIB}
            else
		        cp -Lf ${JV_LIB64}/${Y} ${JV_LOCAL_LIB64}
            fi
	    done
    done
}

# Create the required symlinks to busybox
createSymlinks() {
    echo "Creating symlinks to busybox...\n"

    cd ${TMPDIR}/${JV_LOCAL_BIN} 

    for BB in ${BUSYBOX_TARGETS}; do
        if [ -L "${BB}" ]; then
            echo "${BB} link exists.. removing it\n"
            rm ${BB}
        fi

	    ln -s busybox ${BB}

        if [ ! -L "${BB}" ]; then
            echo "error creating link from ${BB} to busybox\n"
        fi
    done

    cd ${TMPDIR} 
}

# Create the empty mtab file in /etc and copy the init file into the initramfs
# also sed will modify the initramfs to add the modules directory and zfs pool name
configureInit() {
    echo "Making mtab, and creating/configuring init...\n"

    touch etc/mtab

    if [ ! -f "etc/mtab" ]; then
        echo "Error created mtab file.. exiting\n" && cleanUp && exit
    fi

    # Copy the init script
    cd ${TMPDIR} && cp ${HOME_DIR}/files/${HOOK} init

    # Substitute correct values in using % as delimeter
    # to avoid the slashes in the MOD_PATH [/lib/modules...]
    #sed -i -e '18s%""%"'${ZFS_POOL_NAME}'"%' -e '19s%""%"'${MOD_PATH}'"%' init

    if [ ! -f "init" ]; then
        echo "Error created init file.. exiting\n" && cleanUp && exit
    fi

    # Move LVM from .static to normal
    mv sbin/lvm.static sbin/lvm
}

# Create and compress the initramfs
createInitramfs() {
    echo "Creating initramfs...\n"

    find . -print0 | cpio -o --null --format=newc | gzip -9 > ${INITRAMFS_FILE}

    if [ ! -f ${INITRAMFS_FILE} ]; then
        echo "Error creating initramfs file.. exiting" && cleanUp && exit
    fi
    
    echo ""
}

# Clean up and exit after a successful build
cleanComplete() {
    cleanUp

    echo "Complete :)\n"

    echo "Please copy the ${TYPE}-${KERNEL_NAME}.img to your /boot directory\n"

    exit 0
}

#######################################################################
# The main entry point starts here
#######################################################################
headerMessage

getParameters ${@}

getArchitecture

#checkForModulesDir

cleanUp

startMessage

createDirectoryStructure

checkBinaries && copyBinaries

#checkModules && copyModules

copyDependencies

createSymlinks

configureInit

createInitramfs

#cleanComplete
