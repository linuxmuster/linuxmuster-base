require "/usr/share/linuxmuster/scripts/helper.rb"
require "etc"

# Parse dist.conf
Config = ConfigClass.new

MACHINE_PASSWORD = 12345678
HOST_PASSWORD = `pwgen -s 8 1`
#ROOM_UID = get_uid(Config.ADMINISTRATOR)
#ROOM_GID = Etc.getgrnam(Config.ADMINISTRATOR).gid
#ROOM_GID = Etc.getgrnam('root').gid
ROOM_DIRMODE = "0775"
#HOST_GID = get_gid(Config.TEACHERSGROUP)
HOST_DIRMODE = "0775"


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

# Iterate over hosts ('rows' is inherited from myadmin)
rooms_processed = Hash.new
res_groups, res_hosts, res_machines = get_hostgroups
rows.each do
  |row|
  hostname = row.HOSTNAME.downcase
  room = row.ROOM.downcase

  # Create room group if it doesn't exist
  if not rooms_processed[room]
    if not check_group(res_groups, room)
      info "  * Lege Raum an: #{room}"
      runcmd "smbldap-groupadd -a '#{room}'"
    end
    rooms_processed[room] = true
  end

  # Create workstation account if it doesn't exist
  if not hostname.empty? and not room.empty?
    if not check_host(res_hosts, hostname)
      info "  * Lege Stationskonto an: #{hostname}"
      runcmd "smbldap-useradd -a -d '#{Config.WSHOME}/#{room}/#{hostname}' -c HostAccount -g '#{room}' -m -s /bin/bash '#{hostname}'"
      runcmd "echo -e '#{HOST_PASSWORD}\n#{HOST_PASSWORD}\n' | smbldap-passwd '#{hostname}'"
      # Create workstation home if it doesn't exist
      path = "#{Config.WSHOME}/#{room}/#{hostname}"
      runcmd "mkdir -p '#{path}'" if not File.directory?(path)
      # set permissions
      begin
        #uid = get_uid(hostname)
        #runcmd "chown '#{uid}.#{HOST_GID}' '#{path}'"
        runcmd "chown '#{hostname}.#{Config.TEACHERSGROUP}' '#{path}'"
        runcmd "chmod '#{HOST_DIRMODE}' '#{path}'"
      rescue
        error "Fehler beim Setzen der Berechtigungen auf #{path}: #{$!}"
      end
      # set quota
      info "  * Setze quota: #{hostname}"
      runcmd "sophomorix-quota -u #{hostname}"
    end
  end


  # Create Samba machine trust account if it doesn't exist
  if not check_machine(res_machines, "#{hostname}$")
    info "  * Lege Samba Computerkonto an: #{hostname}$"
    runcmd "smbldap-useradd -w -g 515 -c Computer -d /dev/null -s /bin/false '#{hostname}$'"
    runcmd "smbpasswd -a -m '#{hostname}'"
    runcmd "echo -e '#{MACHINE_PASSWORD}\n#{MACHINE_PASSWORD}\n' | smbldap-passwd '#{hostname}$'"
    runcmd "smbldap-usermod -H '[WX]' '#{hostname}$'"
  end
end


# Remove non-existing workstation accounts
hostnames = Hash.new
rooms = Hash.new
rows.each { |row| hostnames[row.HOSTNAME.downcase] = true; rooms[row.ROOM.downcase] = true; }

Dir.glob("#{Config.WSHOME}/*/*").each do
  |hostpath|
  hostname = File.basename(hostpath)
  if not hostnames[hostname.downcase]
    puts "  * Entferne Stationskonto: #{hostname}"
    begin check_host(res_hosts, hostname); runcmd "smbldap-userdel '#{hostname}'" rescue nil end
    begin check_machine(res_machines, "#{hostname}$"); runcmd "smbldap-userdel '#{hostname}$'" rescue nil end
    runcmd "rm -rf '#{hostpath}'"
  end
end

Dir.glob("#{Config.WSHOME}/*").each do
  |roompath|
  room = File.basename(roompath)
  if not rooms[room.downcase]
    puts "  * Entferne Raum: #{room}"
    begin check_group(res_groups, room); runcmd "smbldap-groupdel '#{room}'" rescue nil end
    runcmd "rm -rf '#{roompath}'"

    classes = Config.CLASSROOMS
    File.open(Config.CLASSROOMS+".tmp", "w") do
      |out|
      File.readlines(Config.CLASSROOMS).each do
        |line|
        if line.chomp.strip.downcase != room.downcase
          info "#{room} aus #{Config.CLASSROOMS} entfernt."
        else
          out.puts line
        end
      end
    end
    runcmd "mv '#{Config.CLASSROOMS}.tmp' '#{Config.CLASSROOMS}'"
  end
end
