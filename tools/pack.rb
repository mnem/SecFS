#!/usr/bin/env ruby -w
require 'optparse'

def normalise_string_arg(value, possibilities)
    value = value.downcase
    normalised = nil
    for possibility in possibilities
        if possibility.start_with? value
            if normalised == nil
                normalised = possibility
            else
                # Ambiguous
                return nil
            end
        end
    end
    return normalised
end

OPTIONS = {:root => "/"}
PARSER = OptionParser.new do |opt|
    opt.version = "1.0.0"
    opt.release = "beta"
    opt.banner = "Usage: #{opt.program_name} -o PACK_NAME <files>"

    opt.on("-o", "--out PACK_NAME", String, "The name of the packed files. Will produces a packed file and an index file for the pack.") do |value|
        OPTIONS[:pack_name] = value.strip
    end
    opt.on("-r", "--root ROOT", String, "The root path to store the pack files under.") do |value|
        OPTIONS[:root] = value.strip
    end
end
PARSER.parse!

def abort_with_message(message, show_usage: true)
    if show_usage
        puts PARSER
        puts ""
    end

    abort "ERROR: #{message}"
end

def create_index_name(file_path, full_path)
    pack_name = File.join OPTIONS[:root], file_path
    abort_with_message "Filename too long. Must be <= 1024 characters: #{pack_name}" if pack_name.length > 1024

    {:pack_name => pack_name, :file_name => full_path}
end

def create_index_names(files)
    index_names = []
    for file in files
        full_path = File.absolute_path file
        cwd = File.dirname full_path
        file_path = full_path[cwd.length + 1..-1]
        if File.directory? full_path
            cwd = full_path
            Dir.glob File.join(full_path, "**/*") do | f |
                index_names << create_index_name(f[File.dirname(cwd).length + 1..-1], f) unless File.directory? f
            end
        else
            index_names << create_index_name(file_path, full_path)
        end
    end
    return index_names
end

if not OPTIONS.has_key? :pack_name
    abort_with_message "Pack name missing."
end

if not OPTIONS.has_key?(:root)
    abort_with_message "Root missing."
end

if ARGV.length == 0
    abort_with_message "No files specified to pack."
end

if not OPTIONS[:root].start_with? "/"
    OPTIONS[:root] = "/#{OPTIONS[:root]}"
end

if not OPTIONS[:root].end_with? "/"
    OPTIONS[:root] = "#{OPTIONS[:root]}/"
end

FILES = create_index_names ARGV

puts FILES

