exit(-1) if File.basename($0) == File.basename(__FILE__)

#def message(text)
#  text = Time.now.strftime("%Y-%m-%d %H:%M:%S ") + text
#  puts text
#end
#
#def verbose(text)
#  message "[VRB] #{text}"
#end
#
#def info(text)
#  message "[INF] #{text}"
#end
#
#def error(text)
#  message "[ERR] #{text}"
#end

# Parse dist.conf
class ConfigClass
  def initialize(file = "/usr/share/linuxmuster/config/dist.conf")
    @data = Hash.new
    File.readlines(file).each do
      |line|
      next if line !~ /^\s*([A-Z_]+)\s*=\s*"(.+)"\s*$/
      key, value = $1,$2
      # Handle variable expansion
      @data[key] = value.split(/(\$[A-Z_]+)/).map { |v| (v =~ /\$([A-Z_]+)/)?(@data[$1]):(v) }.join("")
    end
  end

  def [](key)
    @data[key]
  end

  def method_missing(name, *args)
    # Get header name
    name = name.id2name
    if name =~ /(.+)=$/
      raise ArgumentError, "Wertezuweisung nicht erlaubt" 
    else
      @data[name].to_s
    end
  end
end


def db_var(data)
  ret = `echo "#{data}" | debconf-communicate`
  return ret.split(/\s+/, 2)[1] if $?.to_i == 0
  nil
end


# Run the given command
def runcmd(cmd, show = '')
  #puts "Running: #{cmd.dump}"
  case show
    when 'nonzero'
      # Display stderr output if exit code > 0
      output = `#{cmd} 2>&1 >/dev/null`
      puts output if not output.empty? and $?.to_i > 0
    when 'nonzero-all'
      # Display all output if exit code > 0
      output = `#{cmd} 2>&1`
      puts output if not output.empty? and $?.to_i > 0
    else
      # Display stderr output if there is any
      output = `#{cmd} 2>&1 >/dev/null`
      puts output if not output.empty?
  end
  output
end

# Generate a random password of the given length (default: 8 characters)^
def random_pass(len = 8)
  chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
  (1..len).collect { chars[rand(chars.size)].chr }.to_s
end
