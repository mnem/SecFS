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

    abort_with_message "Cannot read file: #{full_path}" if not File.readable? full_path

    {:pack_name => pack_name.encode(Encoding::UTF_8), :file_name => full_path}
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

if FILES.length == 0 
    abort_with_message "No files found to pack."
end

# Write the filename index
PACK_INDEX_NAME = "#{OPTIONS[:pack_name]}.sfsi"
File.open PACK_INDEX_NAME, 'wb' do |f|
    # Write the number of records the file will contain
    record_count = [FILES.length].pack('Q')
    f.write record_count

    # Write the lengths of each record
    record_lengths = []    

    # Initial offset is record_count + (num record lengths) + (num record offsets) in bytes
    current_offset = 8 + (FILES.length * 8) + (FILES.length * 8)
    offsets = []
    FILES.each do |r|
        record_size = r[:pack_name].bytesize
        record_lengths << record_size

        offsets << current_offset

        # Update the offset based on the record
        # size + padding to maintain the specified
        # alignment. In this case, we don't
        # care about alignment for strings
        current_offset += record_size
    end

    # Lengths
    f.write record_lengths.pack('Q*')

    # Offsets
    f.write offsets.pack('Q*')

    # Now write all the data
    current_index = 0
    FILES.each do |r|
        # Check that the offset is what we expect
        raise "Unexpected offset when writing #{r[:pack_name]}. Found #{f.pos}, expected #{offsets[current_index]}" if f.pos != offsets[current_index]

        f.write r[:pack_name].bytes.pack("C*")

        # Next
        current_index += 1


        # in_f = File.open r[:file_name], 'rb'
        # current_offset += File.copy_stream in_f, f
        # File.close in_f

        # # Check that the offset is what we expect
        # raise "Unexpected offset when writing #{file_name}. Found #{current_offset}, expected #{offset_after_record[current_index]}" if current_offset != offset_after_record[current_index]

        # current_index += 1
    end
end

# Write the data pack
PACK_DATA_NAME = "#{OPTIONS[:pack_name]}.sfsd"
File.open PACK_DATA_NAME, 'wb' do |f|
    # Write the number of records the file will contain
    record_count = [FILES.length].pack('Q')
    f.write record_count

    # Write the lengths of each record
    record_lengths = []    

    # Initial offset is record_count + (num record lengths) + (num record offsets) in bytes
    current_offset = 8 + (FILES.length * 8) + (FILES.length * 8)
    offsets = []
    FILES.each do |r|
        record_size = File.size r[:file_name]
        record_lengths << record_size

        offsets << current_offset

        # Update the offset based on the record
        # size + padding to maintain the specified
        # alignment. Hardcoding 8 byte alignment
        current_offset += record_size
        while current_offset % 8 != 0
            current_offset += 1
        end
    end

    # Lengths
    f.write record_lengths.pack('Q*')

    # Offsets
    f.write offsets.pack('Q*')

    # Now write all the data
    current_index = 0
    FILES.each do |r|
        # Check that the offset is what we expect
        raise "Unexpected offset when writing #{r[:pack_name]}. Found #{f.pos}, expected #{offsets[current_index]}" if f.pos != offsets[current_index]

        in_f = File.open r[:file_name], 'rb'
        File.copy_stream in_f, f
        in_f.close

        while f.pos % 8 != 0
            f.write [0].pack('C')
        end

        # Next
        current_index += 1
    end
end
