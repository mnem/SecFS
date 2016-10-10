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

def write_pack(pack_filename, files, alignment, file_bytesize_lambda, file_store_lambda)
    File.open pack_filename, 'wb' do |f|
        # Write the number of records the file will contain
        record_count = [files.length].pack('Q')
        f.write record_count

        # Write the lengths of each record
        record_lengths = []    

        # Initial offset is record_count + (num record lengths) + (num record offsets) in bytes
        current_offset = 0
        offsets = []
        files.each do |r|
            record_size = file_bytesize_lambda.(r)
            record_lengths << record_size

            offsets << current_offset

            # Update the offset based on the record
            # size + padding to maintain the specified
            # alignment.
            current_offset += record_size

            if alignment > 1
                padding = alignment - (current_offset % alignment)
                current_offset += padding if padding != alignment
            end
        end

        # Lengths
        f.write record_lengths.pack('Q*')

        # Offsets
        f.write offsets.pack('Q*')

        # Now write all the data
        current_index = 0
        data_start = f.pos
        files.each do |r|
            # Check that the offset is what we expect
            raise "Unexpected offset when writing #{r[:pack_name]}. Found #{f.pos - data_start}, expected #{offsets[current_index]}" if (f.pos - data_start) != offsets[current_index]

            file_store_lambda.(f, r)

            if alignment > 1
                padding = alignment - (f.pos % alignment)
                if padding != alignment
                    f.write ([0] * padding).pack('C*')
                end
            end

            # Next
            current_index += 1
        end
    end
end

# Write the filename index
PACK_INDEX_NAME = "#{OPTIONS[:pack_name]}.sfsi"
write_pack PACK_INDEX_NAME, FILES, 1, -> r { r[:pack_name].bytesize }, -> f, r { f.write r[:pack_name].bytes.pack("C*") }

# Write the data pack
PACK_DATA_NAME = "#{OPTIONS[:pack_name]}.sfsd"
write_pack PACK_DATA_NAME, FILES, 8, -> r { File.size r[:file_name] }, -> f, r { in_f = File.open(r[:file_name], 'rb'); File.copy_stream(in_f, f); in_f.close() }
