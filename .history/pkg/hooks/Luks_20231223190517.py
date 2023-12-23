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


class Luks(Hook):
    _use_keyfile = 0
    _keyfile_path = "/crypto_keyfile.bin"
    _use_detached_header = 0
    _detached_header_path = "/crypto_header.bin"

    # Required Files
    _files = [
        "/sbin/cryptsetup",
        "/usr/bin/gpg",
        "/usr/bin/gpg-agent",
        # Used for udev cookie release when cryptsetup announces udev support
        # and attempts to decrypt the drive. Without this, the cryptsetup will lock up
        # and stay at "waiting for zero"
        "/sbin/dmsetup",
    ]

    # Is embedding the keyfile enabled?
    @classmethod
    def IsKeyfileEnabled(cls):
        return cls._use_keyfile

    # Return the keyfile path
    @classmethod
    def GetKeyfilePath(cls):
        return cls._keyfile_path

    # Is embedding the LUKS header enabled?
    @classmethod
    def IsDetachedHeaderEnabled(cls):
        return cls._use_detached_header

    # Return the LUKS header path
    @classmethod
    def GetDetachedHeaderPath(cls):
        return cls._detached_header_path

    @classmethod
    def LoadConfig(cls, config):
      c = config['Luks']
      cls._use_keyfile = c.getboolean('use_keyfile', False)
      cls._keyfile_path = c.get('keyfile_path', '')
      cls._use_detached_header = c.getboolean('use_detached_header', False)
      cls._detached_header_path = c.get('detached_header_path', '')
