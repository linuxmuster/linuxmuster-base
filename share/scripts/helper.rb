exit(-1) if File.basename($0) == File.basename(__FILE__)

# use postgres lib
require "postgres"

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


# postgres queries

# get groups, hostaccounts and machine accounts
def get_hostgroups()
  conn = PGconn.connect("localhost", 5432, "", "", "ldap", "postgres", "")
  query = "SELECT gid FROM groups;"
  res_groups = conn.exec(query)
  if (res_groups.status != PGresult::TUPLES_OK)
    raise PGerror,"Query for groups failed!"
  end
  query = "SELECT uid FROM posix_account WHERE gecos='HostAccount';"
  res_hosts = conn.exec(query)
  if (res_hosts.status != PGresult::TUPLES_OK)
    raise PGerror,"Query for host accounts failed!"
  end
  query = "SELECT uid FROM posix_account WHERE gecos='Computer';"
  res_machines = conn.exec(query)
  if (res_machines.status != PGresult::TUPLES_OK)
    raise PGerror,"Query for machine accounts fails!"
  end
  conn.close
  return res_groups, res_hosts, res_machines
end

# check if group exists
def check_group(res_groups, group)
  nResult = res_groups.num_tuples
  if nResult > 10
    for i in 11...nResult
      tgroup = res_groups.getvalue(i, 0)
      if group == tgroup
        return TRUE
      end
    end
  end
  return FALSE
end

# check if hostaccount exists
def check_host(res_hosts, hostname)
  nResult = res_hosts.num_tuples
  if nResult > 0
    for i in 0...nResult
      thostname = res_hosts.getvalue(i, 0)
      if hostname == thostname
        return TRUE
      end
    end
  end
  return FALSE
end

# check if machine account exists
def check_machine(res_machines, machine)
  nResult = res_machines.num_tuples
  if nResult > 0
    for i in 0...nResult
      tmachine = res_machines.getvalue(i, 0)
      if machine == tmachine
        return TRUE
      end
    end
  end
  return FALSE
end

# get group id
def get_gid(groupname)
  query = "SELECT gidnumber FROM groups WHERE gid='#{groupname}';"
  conn = PGconn.connect("localhost", 5432, "", "", "ldap", "postgres", "")
  res = conn.exec(query)
  if (res.status != PGresult::TUPLES_OK)
    raise PGerror,"Query for #{groupname} fails!"
  end
  conn.close
  nResult = res.num_tuples
  if nResult > 0
    vResult = res.getvalue(0, 0)
    return vResult
  else
    return FALSE
  end
end

# get user id
def get_uid(username)
  query = "SELECT uidnumber FROM posix_account WHERE uid='#{username}';"
  conn = PGconn.connect("localhost", 5432, "", "", "ldap", "postgres", "")
  res = conn.exec(query)
  if (res.status != PGresult::TUPLES_OK)
    raise PGerror,"Query for #{username} fails!"
  end
  conn.close
  nResult = res.num_tuples
  if nResult > 0
    vResult = res.getvalue(0, 0)
    return vResult
  else
    return FALSE
  end
end
