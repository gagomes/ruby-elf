# -*- coding: utf-8 -*-
# Copyright © 2009 Alex Legler <a3li@gentoo.org>
# Copyright © 2009-2010 Diego Elio Pettenò <flameeyes@flameeyes.eu>
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this generator; if not, write to the Free Software
# Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA

require 'elf'
require 'pathname'

module Elf::Utilities
  # Pool for ELF files.
  #
  # This pool is useful for tools that recurse over a tree of
  # dependencies to avoid creating multiple instances of Elf::File
  # accessing the same file.
  class FilePool
    @pool = Hash.new

    def self.[](file)
      realfile = Pathname.new(file).realpath
      
      @pool[realfile] ||= Elf::File.new(realfile)
    end
  end
end
