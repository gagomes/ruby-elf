# -*- coding: utf-8 -*-
# Copyright © 2008-2010 Diego E. "Flameeyes" Pettenò <flameeyes@gmail.com>
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

require 'getoptlong'
require 'thread'
require 'elf'

# This file allows to wrap aroudn the most common features of
# Ruby-Elf based tools, that follow a series of common traits.
#
# The tools using this file are tools that inspect a series of ELF
# files, passed through command line, stdin, or through a file
# parameter; they accept a series of arguments that may or might not
# require arguments (in that latter case they are considered on/off
# switches), and so on.

# Gets the name of the tool
def self.to_s
  File.basename($0)
end

# Output an error message, prefixed with the tool name.
def self.puterror(string)
  return if @quiet

  @output_mutex.synchronize {
    $stderr.puts "#{to_s}: #{string}"
  }
end

# Parse the arguments for the tool; it does not parse the @file
# options, since they are only expected to contain file names,
# rather than options.
def self.parse_arguments
  opts = Options + [
                    ["--help", "-?", GetoptLong::NO_ARGUMENT],
                    ["--quiet", "-q", GetoptLong::NO_ARGUMENT],
                    ["--recursive", "-R", GetoptLong::NO_ARGUMENT],
                   ]

  opts = GetoptLong.new(*opts)
  opts.each do |opt, arg|
    if opt == "--help"
      # check if we're executing from a tarball or the git repository,
      # if so we can't use the system man page.
      require 'pathname'
      filepath = Pathname.new($0)
      localman = filepath.dirname + "../manpages" + filepath.basename.sub(".rb", ".1")
      if localman.exist?
        exec("man #{localman.to_s}")
      else
        exec("man #{to_s}")
      end
    end

    attrname = opt.gsub(/^--/, "").gsub("-", "_")
    attrval = arg.size == 0 ? true : arg

    # If there is a function with the same name of the parameter
    # defined (with a _cb suffix), call that, otherwise set the
    # attribute with the same name to the given value.
    if respond_to?(attrname + "_cb")
      method(attrname + "_cb").call(attrval)
    else
      instance_variable_set("@#{attrname}", attrval)
    end
  end
end

# Try to execute the analysis function on a given filename argument.
def self.try_execute(filename)
  begin
    # if the file name starts with '@', it is not a target, but a file
    # with a list of targets, so load it with execute_on_file.
    if filename[0..0] == "@"
      execute_on_file(filename[1..-1])
      # if the path references a directory, and we're going to run
      # recursively, descend into that.
    elsif @recursive and File.directory?(filename)
      Dir.foreach(filename) do |children|
        next if children == "." or children == ".."
        try_execute(File.join(filename, children))
      end
    else
      @execution_threads.add(Thread.new {
                               analysis(filename)
                             })
    end
  rescue Errno::ENOENT, Errno::EACCES, Errno::EISDIR, Elf::File::NotAnELF => e
    # The Errno exceptions have their message ending in " - FILENAME",
    # so we take the FILENAME out and just use the one we know
    # already.  We also take out the final dot on the phrase so that
    # we follow the output messages from other tools, like cat.
    puterror "#{filename}: #{e.message.gsub(/\.? - .*/, '')}"
  rescue Exception => e
    puterror "#{filename}: #{e.message} (#{e.class})\n\t#{e.backtrace.join("\n\t")}"
    exit -1
  end
end

# Execute the analysis function on all the elements of an array.
def self.execute_on_array(array)
  array.each do |filename|
    try_execute(filename)
  end
end

# Execute the analysis function on all the lines of a file
def self.execute_on_file(file)
  file = $stdin if file == "-"
  file = File.new(file) if file.class == String

  file.each_line do |line|
    try_execute(line.chomp("\n"))
  end
end

def self.main
  begin
    @output_mutex = Mutex.new
    @execution_threads = ThreadGroup.new

    before_options if respond_to? :before_options
    parse_arguments
    after_options if respond_to? :after_options
    
    if ARGV.size == 0
      execute_on_file($stdin)
    else
      execute_on_array(ARGV)
    end

    @execution_threads.list.each do |thread|
      thread.join
    end

    results if respond_to? :results
  rescue Interrupt
    puterror "Interrupted"
    exit 1
  end
end

at_exit do
  unless $!
    main
  end
end
