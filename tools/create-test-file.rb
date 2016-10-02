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

OPTIONS = {:bits => 32, :endianess => :little}
PARSER = OptionParser.new do |opt|
    opt.version = "1.0.0"
    opt.release = "beta"
    opt.banner = "Usage: #{opt.program_name} [OPTIONS]"

    opt.on("-s", "--size SIZE_IN_BYTES", Integer, "Size, in bytes, of the file to create.") do |value|
        OPTIONS[:bytesize] = value >= 0 ? value : 0
    end

    opt.on("-t", "--type TYPE", String, "Type of data to generate. One of: CHARACTER, STRING, INTEGER") do |value|
        case normalise_string_arg(value, %w{character string integer})
        when "character"
            OPTIONS[:type] = :character
        when "string"
            OPTIONS[:type] = :string
        when "integer"
            OPTIONS[:type] = :integer
        else
            raise "#{value} is an unrecognised type. Must be one of: CHARACTER, STRING, INTEGER"
        end
    end

    opt.on("-b", "--bits BITS", Integer, "Bits for each datum in pattern. May be one of: 8, 16, 32. Only relevant for INTEGER patterns. Defaults to #{OPTIONS[:bits]}") do |value|
        case value
        when 8, 16, 32
            OPTIONS[:bits] = value
        else
            raise "#{value} is unsupported as a bit size. Must be one of: 8, 16, 32"
        end
    end

    opt.on("-e", "--endianess ENDIANESS", String, "Endianess of each datum in pattern. May be one of: BIG, LITTLE. Only relevant for INTEGER patterns. Defaults to #{OPTIONS[:endianess]}") do |value|
        case normalise_string_arg(value, %w{big little})
        when "big"
            OPTIONS[:endianess] = :big
        when "little"
            OPTIONS[:endianess] = :little
        else
            raise "#{value} is an unrecognised endianess. Must be one of: BIG, LITTLE"
        end
    end

    opt.on("-p", "--pattern PATTERN", String, "Pattern to repeat in the data of the file. If INTEGER pattern, items may be comma separated. Will be truncated or repeated as appropriate.") do |value|
        OPTIONS[:pattern] = value
    end

    opt.on("-o", "--out FILENAME", String, "File to overwrite with the created bytes. If omitted, will output to stdout") do |value|
        OPTIONS[:out] = value
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

def create_character_data(pattern, size)
    if not pattern or pattern.length == 0
        pattern = [0]
    else
        pattern = pattern.bytes
    end

    pattern *= (size.to_f/pattern.length).ceil
    pattern[0...size]
end

def create_string_data(pattern, size)
    pattern = create_character_data(pattern, size)
    pattern[size - 1] = 0 if size > 0
    return pattern
end

def string_to_integer(string)
    string = string.strip.downcase
    if string.start_with?("0x")
        return string[2..-1].to_i(16)
     elsif string.start_with?("#")
        return string[1..-1].to_i(16)
    elsif string.start_with? "o"
        return string[1..-1].to_i(8)
    elsif string.start_with? "b"
        return string[1..-1].to_i(2)
    else
        return string.to_i
    end
end

def int_to_bytes(i, bits, endianess)
    i = [i]
    packed = nil
    if bits == 8
        packed = i.pack "C"
    elsif bits == 16
        if endianess == :little
            packed = i.pack "v"
        elsif endianess == :big
            packed = i.pack "n"
        else
          raise "Unsupported endianess: #{endianess}"
        end
    elsif bits == 32
        if endianess == :little
            packed = i.pack "V"
        elsif endianess == :big
            packed = i.pack "N"
        else
          raise "Unsupported endianess: #{endianess}"
        end
    else
        raise "Unsupported bit size: #{bits}"
    end

    return packed.unpack "C"
end

def create_integer_data(pattern, size)
    if not pattern or pattern.length == 0
        pattern = [0]
    else
        if pattern.include? ","
            pattern = pattern.split ","
            pattern.map! { |s| string_to_integer(s) }
        else
            pattern = [string_to_integer(pattern)]
        end
    end

    out = []
    pattern.each { |i| out << int_to_bytes(i, OPTIONS[:bits], OPTIONS[:endianess]) }
    out.flatten!

    require 'pp'
    pp out

    out *= (size.to_f/out.length).ceil
    out[0...size]
end

def create_data(type, pattern, size)
    case type
    when :character
        return create_character_data(pattern, size)
    when :string
        return create_string_data(pattern, size)
    when :integer
        return create_integer_data(pattern, size)
    else
        raise "Unrecognised data type"
    end
end

if not OPTIONS.has_key? :bytesize
    abort_with_message "Bytesize missing."
end

if not OPTIONS.has_key? :type
    abort_with_message "Type missing."
end

data = create_data(OPTIONS[:type], OPTIONS[:pattern], OPTIONS[:bytesize])
binstring = data.pack("C*")

if OPTIONS.has_key? :out
    File.open(OPTIONS[:out], "wb"){ |f| f.write binstring }
else
    $stdout.write binstring
end
