#!/usr/bin/env ruby
require 'net/http'
require 'digest'
require 'fileutils'

class CacheBuilder
  def initialize
    @cachedir = './cache/'
    @workdir = "#{@cachedir}tmp/"
    @errors = []
  end

  def init_cachedir
    FileUtils.mkdir_p @cachedir
  end

  def init_workdir
    FileUtils.rm_r @workdir if File.exist? @workdir
    FileUtils.mkdir_p @workdir
  end

  def error(msg)
    puts msg
    @errors << msg
  end

  def get_spec(package, file)
    this_cache_file = "#{@cachedir}#{Digest::MD5.hexdigest(file)}.gemspec"
    return if File.exist?(this_cache_file)
    puts "Downloading #{package}..."
    init_workdir
    Kernel.system "cd #{@workdir} && dget #{package}"
    package_glob = "#{@workdir}#{package}_*.deb"
    deb = Dir.glob(package_glob).first
    if deb.nil? then
      error "E: no deb found for package #{package}"
      return
    end
    Kernel.system "dpkg-deb -x #{deb} #{@workdir}"
    real_file = "#{@workdir}#{file}"
    if not File.exist? real_file then
      error "E: gemspec #{file} not found in downloaded package for #{package}, skipping"
      return
    end
    FileUtils.cp "#{@workdir}#{file}", this_cache_file
    puts "Got #{@workdir}#{file} and wrote it to #{this_cache_file}"
  end

  def get_contents
    puts "Downloading Contents-amd64.gz"
    StringIO.open(Net::HTTP.get('ftp.at.debian.org', '/debian/dists/sid/main/Contents-amd64.gz'))
  end

  def get_package_filelist(contents)
    puts "Parsing Contents"
    re = /rubygems-integration\/.*\/specifications\/.*.gemspec$/
    reader = Zlib::GzipReader.new(contents)
    package_file = []
    reader.each_line do |l|
      file, packages = l.split(" ")
      if re.match(file) then
        packages = packages.split(",").map do |p|
          package_file << [p.split("/")[1], file]
        end
      end
    end
    package_file
  end

  def go!
    init_cachedir
    get_package_filelist(get_contents()).each do |package, file|
      get_spec(package, file)
    end
    if @errors then
      puts
      puts "List of all errors:"
      puts @errors
    end
  end
end

CacheBuilder.new.go!

