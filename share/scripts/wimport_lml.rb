require "/usr/share/linuxmuster/scripts/helper.rb"
require "etc"

# Parse dist.conf
Config = ConfigClass.new

MACHINE_PASSWORD = 12345678
HOST_PASSWORD = `pwgen -s 8 1`
ROOM_DIRMODE = "0775"
HOST_DIRMODE = "0775"

# Iterate over hostnames to find double entries ('rows' is inherited from myadmin)
hostnames_processed = Hash.new
rows.each do
  |row|
  hostname = row.HOSTNAME.downcase

  if hostname.empty?
    next
  end

  # compare hostnames
  if not hostnames_processed[hostname]
    hostnames_processed[hostname] = true
  else
    info "  * Doppelten Hostnamen gefunden: #{hostname}"
    info "  * Breche Verarbeitung ab!"
    exit 1
  end
end

# Iterate over ips to find double entries ('rows' is inherited from myadmin)
ips_processed = Hash.new
rows.each do
  |row|
  ip = row.IPADDRESS

  if ip.empty?
    next
  end

  # compare ips
  if not ips_processed[ip]
    ips_processed[ip] = true
  else
    info "  * Doppelte IP-Adresse gefunden: #{ip}"
    info "  * Breche Verarbeitung ab!"
    exit 1
  end
end

# Iterate over macs to find double entries ('rows' is inherited from myadmin)
macs_processed = Hash.new
rows.each do
  |row|
  mac = row.MACADDRESS.downcase

  if mac.empty?
    next
  end

  # compare macs
  if not macs_processed[mac]
    macs_processed[mac] = true
  else
    info "  * Doppelte MAC-Adresse gefunden: #{mac}"
    info "  * Breche Verarbeitung ab!"
    exit 1
  end
end

# Create mySHN group directory and config file
default_config = "#{Config.MYSHNDIR}/default/config"
default_config = "#{Config.MYSHNDIR}/config" if not File.readable?(default_config)
default_config = "" if not File.readable?(default_config)
if not default_config.empty?
  # Create groups directory if it doesn't already exist (though it should)
  runcmd "mkdir -p '#{Config.MYSHNDIR}/groups'" if not File.exists?("#{Config.MYSHNDIR}/groups")
  begin
    # Get list of all group directores in lower case
    dirs = (Dir.entries("#{Config.MYSHNDIR}/groups") - [".", ".."]).map { |dir| dir.downcase }
    groups = []
    # Get list of all groups defined in wimport_data
    rows.each_rembo_host { |row| groups << row.IMAGEGROUP if not row.IMAGEGROUP.empty? }
    # Iterate over groups
    groups.sort.uniq.each do
      |group|
      # If group directory does not exist, create it and copy in the default config
      if not dirs.index(group.downcase)
        info "  * Lege mySHN Gruppenkonfiguration an: #{group}"
        runcmd "mkdir '#{Config.MYSHNDIR}/groups/#{group}'"
        runcmd "cp '#{default_config}' '#{Config.MYSHNDIR}/groups/#{group}'"
      end
    end
  rescue
    error $1
  end
end

# Set permissions
runcmd "chmod 640 /var/lib/myshn/hostgroup.conf"
runcmd "chmod 600 /etc/rembo/rembo.conf"

# Force reload of affected services
info "  * Reload betroffener Dienste (kann bei vielen Workstations etwas dauern)"
info "     - Firewall"
runcmd("/etc/init.d/linuxmuster-base reload", "nonzero-all")
info "     - DHCP-Server"
runcmd("/etc/init.d/dhcp3-server force-reload", "nonzero-all")
info "     - Rembo-Server"
runcmd("/etc/init.d/rembo reload", "nonzero-all")

# get groups and accounts from database
res_groups, res_roomgroups, res_hosts, res_machines = get_hostgroups

# Iterate over hosts ('rows' is inherited from myadmin)
rows.each do
  |row|
  hostname = row.HOSTNAME.downcase
  room = row.ROOM.downcase

  # Create workstation account if it doesn't exist
  if not hostname.empty? and not room.empty?
    if not check_host(res_hosts, hostname)
      res = create_account(hostname, room, Config.WSHOME, HOST_PASSWORD, MACHINE_PASSWORD, Config.TEACHERSGROUP, HOST_DIRMODE)
    else
      # check if room for hostname has changed
      pgroup = get_pgroup(hostname)
      if room != pgroup.downcase
        info "  * Arbeitsstation #{hostname} ist umgezogen von Raum #{pgroup} nach Raum #{room}!"
        res = remove_account(hostname, res_hosts, res_machines)
        res = create_account(hostname, room, Config.WSHOME, HOST_PASSWORD, MACHINE_PASSWORD, Config.TEACHERSGROUP, HOST_DIRMODE)
      end
    end
  end
end


# Remove non-existing workstation accounts and room groups
hostnames = Hash.new
rooms = Hash.new
rows.each { |row| hostnames[row.HOSTNAME.downcase] = true; rooms[row.ROOM.downcase] = true; }

Dir.glob("#{Config.WSHOME}/*/*").each do
  |hostpath|
  hostname = File.basename(hostpath)
  if not hostnames[hostname.downcase]
    res = remove_account(hostname, res_hosts, res_machines)
  end
end

res_roomgroups.each do |tupl|
  tupl.each do |room|
    if not rooms[room.downcase]
      puts "  * Entferne Raum: #{room}"
      begin check_group(res_groups, room); runcmd "sophomorix-groupdel --room '#{room}'" rescue nil end

      classes = Config.CLASSROOMS
      File.open(Config.CLASSROOMS+".tmp", "w") do
        |out|
        File.readlines(Config.CLASSROOMS).each do
          |line|
          if line.chomp.strip.downcase != room.downcase
            out.puts line
          else
            info "  * #{room} aus #{Config.CLASSROOMS} entfernt."
          end
        end
      end
      runcmd "mv '#{Config.CLASSROOMS}.tmp' '#{Config.CLASSROOMS}'"
    end
  end
end
