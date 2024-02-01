#!/usr/bin/env ruby
################################################################################
##  File:  configure-xcode-simulators.rb
##  Desc:  List all simulators, find duplicate type and delete them.
##  Maintainer: @vlas-voloshin
##              script was taken from https://gist.github.com/vlas-voloshin/f9982128200345cd3fb7
################################################################################

require 'json'

class SimDevice

  attr_accessor :runtime
  attr_accessor :name
  attr_accessor :deviceType
  attr_accessor :identifier
  attr_accessor :timestamp

  def initialize(runtime, name, deviceType, identifier, timestamp)
    @runtime = runtime
    @name = name
    @identifier = identifier
    @deviceType = deviceType
    @timestamp = timestamp
  end

  def to_s
    clean_runtime = @runtime.gsub("com.apple.CoreSimulator.SimRuntime.", "") rescue "[unknown runtime]"
    clean_type = @deviceType.gsub("com.apple.CoreSimulator.SimDeviceType.", "") rescue "[unknown device type]"
    return "#{@name} (#{clean_runtime}) – #{clean_type} #{@identifier} [#{@timestamp}]"
  end

  def equivalent_to_device(device)
    return @runtime != nil && @deviceType != nil && @runtime == device.runtime && @deviceType == device.deviceType
  end

end

# Executes a shell command and returns the result from stdout
def execute_simctl_command(command)
  return %x[xcrun simctl #{command}]
end

# Retrieves the creation date/time of simulator with specified identifier
def simulator_creation_date(identifier)
  directory = Dir.home() + "/Library/Developer/CoreSimulator/Devices/" + identifier
  if (Dir.exists?(directory))
    if (File::Stat.method_defined?(:birthtime))
      return File.stat(directory).birthtime
    else
      return File.stat(directory).ctime
    end
  else
    # Simulator directory is not yet created - treat it as if it was created right now (happens with newer sims)
    return Time.now
  end
end

# Deletes specified simulator
def delete_device(device)
  execute_simctl_command("delete #{device.identifier}")
end

puts("Searching for simulators...")

# Retrieve the list of existing simulators and sort by their creation timestamp, ascending
json = JSON.parse(execute_simctl_command("list -j devices"))
devices = json["devices"].flat_map { |runtime, devices|
  devices.map { |device|
    identifier = device["udid"]
    timestamp = simulator_creation_date(identifier)
    SimDevice.new(runtime, device["name"], device["deviceTypeIdentifier"], identifier, timestamp)
  }
}.sort { |a, b| a.timestamp <=> b.timestamp }

duplicates = {}
# Enumerate all devices except for the last one
for i in 0..devices.count-2
  device = devices[i]
  # Enumerate all devices *after* this one (created *later*)
  for j in i+1..devices.count-1
    potential_duplicate = devices[j]
    if potential_duplicate.equivalent_to_device(device)
      duplicates[potential_duplicate] = device
      # Break out of the inner loop if a duplicate is found - if another duplicate exists,
      # it will be found when this one is reached in the outer loop
      break
    end
  end
end

if duplicates.count == 0
  puts("You don't have duplicate simulators!")
  exit()
end

puts("Looks like you have #{duplicates.count} duplicate simulator#{duplicates.count > 1 ? "s" : ""}:")
duplicates.each_pair do |duplicate, original|
  puts
  puts("#{duplicate}")
  puts("--- duplicate of ---")
  puts("#{original}")
end
puts

puts("Each duplicate was determined as the one created later than the 'original'.")

puts("Deleting...")
duplicates.each_key do |duplicate|
  delete_device(duplicate)
end

puts("Done!")

=begin
MIT License

Copyright (c) 2015-2021 Vlas Voloshin

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
=end
