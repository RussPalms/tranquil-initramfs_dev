# Copyright (C) 2019-2024 Russell Palma <me@russellpalma.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

import argparse
import glob
import os
import shutil
import sys

import pkg.libs.Variables as var

from subprocess import call
from subprocess import check_output


class Tools:
    # Available Features
    _features = {1: "ZFS", 2: "LUKS", 3: "Basic"}

    # Checks parameters
    @classmethod
    def ProcessArguments(cls, Modules):
        parser = argparse.ArgumentParser(
            description="Builds an initramfs for booting from OpenZFS.")
        parser.add_argument(
            "-c", "--config", help="Path to the config.ini file.") 
        parser.add_argument(
            "kernel", nargs='?',
            help="The name of the kernel to build the initramfs for. "
                  "Optional, most-newly-built kernel if omitted. "
                  "(e.g.: 4.14.170-FC.01)")
        args = parser.parse_args()   

        if args.config:
          var.config_file = args.config
        if args.kernel:
          var.kernel = args.kernel
        else:
          kernels = glob.glob('/lib/modules/*')
          kernels.sort(
              key=lambda f: os.stat(f).st_mtime,
              reverse=True)
          var.kernel = os.path.basename(kernels[0])

    # Finds the path to a program on the system
    @classmethod
    def GetProgramPath(cls, vProg):
        cmd = "whereis " + vProg + ' | cut -d " " -f 2'
        results = check_output(cmd, shell=True, universal_newlines=True).strip()

        if results:
            return results
        else:
            cls.Fail("The " + vProg + " program could not be found!")

    # Returns the path to udev
    @classmethod
    def GetUdevPath(cls):
        udev_paths = [
            "/usr/lib/systemd/systemd-udevd",
            "/lib/systemd/systemd-udevd",
            "/sbin/udevd",
        ]

        for path in udev_paths:
            if os.path.exists(path) and os.path.isfile(path):
                return path

        cls.Fail("udev was not found on the system!")

    # Check to see if the temporary directory exists, if it does,
    # delete it for a fresh start
    @classmethod
    def Clean(cls):
        # Go back to the original working directory so that we are
        # completely sure that there will be no inteference cleaning up.
        os.chdir(var.home)

        # Removes the temporary directory
        if os.path.exists(var.temp):
            shutil.rmtree(var.temp)

            if os.path.exists(var.temp):
                cls.Warn("Failed to delete the " + var.temp + " directory. Exiting.")
                quit(1)

    # Clean up and exit after a successful build
    @classmethod
    def CleanAndExit(cls, vInitrd):
        cls.Clean()
        cls.Info('Please copy "' + vInitrd + '" to your ' + "/boot directory")
        quit()

    # Intelligently copies the file into the initramfs
    # Optional Args:
    #   directoryPrefix = Prefix that we should add when constructing the file path
    #   dontFail = If the file wasn't able to be copied, do not fail.
    @classmethod
    def Copy(cls, vFile, **optionalArgs):
        # NOTE: shutil.copy will dereference all symlinks before copying.

        # If a prefix was passed into the function as an optional argument
        # it will be used below.
        directoryPrefix = optionalArgs.get("directoryPrefix", None)

        # Check to see if a file with this name exists before copying,
        # if it exists, delete it, then copy. If a directory, create the directory
        # before copying.
        if directoryPrefix:
            path = var.temp + "/" + directoryPrefix + "/" + vFile
            targetFile = directoryPrefix + "/" + vFile
        else:
            path = var.temp + "/" + vFile
            targetFile = vFile

        if os.path.exists(path):
            if os.path.isfile(path):
                os.remove(path)
                shutil.copy(targetFile, path)
        else:
            if os.path.isfile(targetFile):
                # Make sure that the directory that this file wants to be in
                # exists, if not then create it.
                if os.path.isdir(os.path.dirname(path)):
                    shutil.copy(targetFile, path)
                else:
                    os.makedirs(os.path.dirname(path))
                    shutil.copy(targetFile, path)
            elif os.path.isdir(targetFile):
                os.makedirs(path)

        # Finally lets make sure that the file was copied to its destination (unless declared otherwise)
        if not os.path.isfile(path):
            message = "Unable to copy " + targetFile

            if optionalArgs.get("dontFail", False):
                cls.Warn(message)
            else:
                cls.Fail(message)

    # Copies a file to a target path and checks to see that it exists
    @classmethod
    def SafeCopy(cls, sourceFile, targetDest, *desiredName):
        if len(desiredName) == 0:
            splitResults = sourceFile.split("/")
            lastPosition = len(splitResults)
            sourceFileName = splitResults[lastPosition - 1]
        else:
            sourceFileName = desiredName[0]

        targetFile = targetDest + "/" + sourceFileName

        if os.path.exists(sourceFile):
            shutil.copy(sourceFile, targetFile)

            if not os.path.isfile(targetFile):
                Tools.Fail('Error creating the "' + sourceFileName + '" file. Exiting.')
        else:
            Tools.Fail("The source file doesn't exist: " + sourceFile)

    # Copies and verifies that a configuration file exists, and if not,
    # warns the user that the default settings will be used.
    @classmethod
    def CopyConfigOrWarn(cls, targetConfig):
        if os.path.isfile(targetConfig):
            Tools.Flag("Copying " + targetConfig + " from the current system...")
            Tools.Copy(targetConfig)
        else:
            Tools.Warn(
                targetConfig
                + " was not detected on this system. The default settings will be used."
            )

    # Runs a shell command and returns its output
    @classmethod
    def Run(cls, command):
        try:
            return (
                check_output(command, universal_newlines=True, shell=True)
                .strip()
                .split("\n")
            )
        except:
            Tools.Fail(
                "An error occured while processing the following command: " + command
            )

    ####### Message Functions #######

    # Returns the string with a color to be used in bash
    @classmethod
    def Colorize(cls, vColor, vMessage):
        if vColor == "red":
            coloredMessage = "\e[1;31m" + vMessage + "\e[0;m"
        elif vColor == "yellow":
            coloredMessage = "\e[1;33m" + vMessage + "\e[0;m"
        elif vColor == "green":
            coloredMessage = "\e[1;32m" + vMessage + "\e[0;m"
        elif vColor == "cyan":
            coloredMessage = "\e[1;36m" + vMessage + "\e[0;m"
        elif vColor == "purple":
            coloredMessage = "\e[1;34m" + vMessage + "\e[0;m"
        elif vColor == "white":
            coloredMessage = "\e[1;37m" + vMessage + "\e[0;m"
        elif vColor == "pink":
            coloredMessage = "\e[1;35m" + vMessage + "\e[0;m"
        elif vColor == "none":
            coloredMessage = vMessage

        return coloredMessage

    # Prints a message through the shell
    @classmethod
    def Print(cls, vMessage):
        call(["echo", "-e", vMessage])

    # Used for displaying information
    @classmethod
    def Info(cls, vMessage):
        call(["echo", "-e", cls.Colorize("green", "[*] ") + vMessage])

    # Used for input (questions)
    @classmethod
    def Question(cls, vQuestion):
        return input(vQuestion)

    # Used for warnings
    @classmethod
    def Warn(cls, vMessage):
        call(["echo", "-e", cls.Colorize("yellow", "[!] ") + vMessage])

    # Used for flags (aka using zfs, luks, etc)
    @classmethod
    def Flag(cls, vFlag):
        call(["echo", "-e", cls.Colorize("purple", "[+] ") + vFlag])

    # Used for options
    @classmethod
    def Option(cls, vOption):
        call(["echo", "-e", cls.Colorize("cyan", "[>] ") + vOption])

    # Used for errors
    @classmethod
    def Fail(cls, vMessage):
        cls.Print(cls.Colorize("red", "[#] ") + vMessage)
        cls.NewLine()
        cls.Clean()
        quit(1)

    # Prints empty line
    @classmethod
    def NewLine(cls):
        print("")

    # Error Function: Binary doesn't exist
    @classmethod
    def BinaryDoesntExist(cls, vMessage):
        cls.Fail("Binary: " + vMessage + " doesn't exist. Exiting.")

    # Error Function: Module doesn't exist
    @classmethod
    def ModuleDoesntExist(cls, vMessage):
        cls.Fail("Module: " + vMessage + " doesn't exist. Exiting.")
