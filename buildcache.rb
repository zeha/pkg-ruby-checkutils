#!/usr/bin/env ruby
require 'net/http'
require 'digest'
require 'fileutils'

MIRROR = 'ftp.at.debian.org'

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
    File.write("#{@workdir}/#{package}.deb", Net::HTTP.get(MIRROR, "/pool/
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
    Zlib::GzipReader.new(StringIO.open(Net::HTTP.get(MIRROR, '/debian/dists/sid/main/Contents-amd64.gz')))
  end

  def get_packages
    ["amd64", "all"].map do |arch|
      url = "/debian/dists/sid/main/binary-#{arch}/Packages.gz"
      puts "Downloading #{url}"
      Zlib::GzipReader.new(StringIO.open(Net::HTTP.get(MIRROR, url)))
    end
  end

  def get_package_filelist(contents, packages_archs)
    re = /Filename: pool/
    package_deb_index = {}
    packages_archs.each do |packages_arch|
      puts "Parsing a packages-arch file"
      packages_arch.each_line do |l|
        if re.match(l) then
          filename = l.split(" ")[1]
          package_deb_index[filename.split("/")[3]] = filename
        end
      end
    end

    puts "Parsing Contents"
    re = /rubygems-integration\/.*\/specifications\/.*.gemspec$/
    package_file = []
    contents.each_line do |l|
      file, packages = l.split(" ")
      if re.match(file) then
        packages = packages.split(",").map do |p|
          packagename = p.split("/")[1]
          package_file << [packagename, file, package_deb_index[packagename]]
        end
      end
    end

    package_file
  end

  def go!
    init_cachedir
    get_package_filelist(get_contents(), get_packages()).each do |package, file, poolurl|
      get_spec(package, file, poolurl)
    end
    if @errors then
      puts
      puts "List of all errors:"
      puts @errors
    end
  end
end

CacheBuilder.new.go!

