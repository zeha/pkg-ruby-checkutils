#!/usr/bin/env ruby
require 'rubygems'
require 'net/http'
require 'json'
require 'optparse'

SPEC_CACHE = './cache/'

def load_all_specs(spec_dir)
  all_specs = Dir.glob("#{spec_dir}*.gemspec").map do |f|
    begin
      Gem::Specification.load(f)
    rescue
      puts "E: error while loading spec #{f}", $!
      nil
    end
  end
  all_specs = all_specs.reject do |s| s.nil? end
  puts "Loaded #{all_specs.length} specs from #{spec_dir}"
  all_specs
end

def all_compat(all_specs, root_name, old_version, new_version, verbose=false)
  error = false
  all_specs.each do |spec|
    next if spec.name() == root_name
    spec.dependencies().each do |dep|
      next unless dep.name == root_name
      puts "#{spec.name} checking #{dep} against #{old_version} and #{new_version}" if verbose
      if not dep.match? root_name, old_version then
        puts "#{spec.name} depends #{dep} but current version #{old_version} doesn't match"
        error = true
      end
      if not new_version.nil? and not dep.match? root_name, new_version then
        puts "#{spec.name} depends #{dep} but NEWER version #{new_version} doesn't match"
        error = true
      end
    end
  end
  !error
end

def load_sourcedir(name)
  filename = "#{name}/metadata.yml"
  puts "Reading gem metadata from #{filename} ..."
  root_spec = Gem::Specification.from_yaml(File.read(filename))
  root_name = root_spec.name()
  old_version = root_spec.version.to_s
  return root_name, old_version
end

def get_current_version(name)
  puts "Checking version of #{name} on rubygems.org..."
  versions = JSON.parse(Net::HTTP.get('rubygems.org', "/api/v1/versions/#{name}.json"))
  return versions[0]["number"].to_s
rescue nil
  puts "E: Failed checking current version on rubugems.org", $!
  nil
end

class ArgParser
  @@options = {}
  @@parser = OptionParser.new do |opts|
    opts.banner = 'Usage: check.rb [options]'
    opts.on("-v", "Run verbosely") do |v| @@options[:verbose] = v end
    opts.on("-p WHAT", "Treat WHAT as a source package name") do |v| @@options[:type] = :package; @@options[:what] = v end
    opts.on("-s WHAT", "Treat WHAT as a source directory name (which contains metadata.yml)") do |v| @@options[:type] = :sourcedir; @@options[:what] = v end
    opts.on("-g WHAT", "Treat WHAT as a gem name (has to be in all specs cache)") do |v| @@options[:type] = :gem; @@options[:what] = v end
    opts.on("-r WHAT", "Treat WHAT as a gem name from rubygems.org") do |v| @@options[:type] = :remotegem; @@options[:what] = v end
    opts.on("-a", "Check all local specs against each other") do |v| @@options[:type] = :all end
  end
  
  def self.usage!
    puts @@parser.help
    exit 2
  end
  
  def self.parse!
    @@parser.parse!
    return @@options
  rescue
    puts $!
    usage!
  end
end

def check_single(name, old_version)
  all_specs = load_all_specs(SPEC_CACHE)

  puts "Current version of #{name} is #{old_version}"
  new_version = get_current_version(name)
  if new_version != old_version then
    puts "Newer version #{name} #{new_version} available"
  else
    new_version = nil
  end

  exit 1 unless all_compat(all_specs, name, old_version, new_version)
end

def check_all
  all_specs = load_all_specs(SPEC_CACHE)
  all_specs.each do |spec|
    unless all_compat(all_specs, spec.name(), spec.version, nil) then
      puts
    end
  end
end

options = ArgParser.parse!

case options[:type]
when :sourcedir
  check_single(*load_sourcedir(options[:what]))
when :package
  puts "TODO"
  exit 1
when :gem
  puts "TODO"
  exit 1
when :remotegem
  check_single(options[:what], get_current_version(options[:what]))
when :all
  check_all
else
  ArgParser.usage!
end

