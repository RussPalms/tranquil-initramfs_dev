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

from pkg.hooks.Hook import Hook


class Firmware(Hook):
    # Copy firmware?
    _use = 0
    # If enabled, all the firmware in /lib/firmware will be copied into the initramfs.
    # If you know exactly what firmware files you want, definitely leave this at 0 so
    # to reduce the initramfs size.
    _copy_all = 0
    # A list of firmware files to include in the initramfs
    _files = []

    # Gets the flag_all_firmware value
    @classmethod
    def IsCopyAllEnabled(cls):
        return cls._copy_all

    @classmethod
    def LoadConfig(cls, config):
      c = config['Firmware']
      cls._use = c.getboolean('use', False)
      cls._copy_all = c.getboolean('copy_all', False)
      cls._files.extend(config['FirmwareFiles'].keys())
