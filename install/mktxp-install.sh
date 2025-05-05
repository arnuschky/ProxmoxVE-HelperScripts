#!/usr/bin/env bash

# Copyright (c) 2021-2025 community-scripts ORG
# Author: arnuschky
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/akpw/mktxp

source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
color
verb_ip6
catch_errors
setting_up_container
network_check
update_os

msg_info "Installing Dependencies"
$STD apt-get update
$STD apt-get install -y \
  curl \
  python3 \
  python3-pip
msg_ok "Installed Dependencies"

msg_info "Installing MKTXP"
# fetch and unpack
RELEASE=$(curl -fsSL https://api.github.com/repos/akpw/mktxp/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
curl -fsSL "https://github.com/akpw/mktxp/archive/refs/tags/v${RELEASE}.tar.gz" | tar -xzf - -C /tmp
# install release via pip
cd /tmp/mktxp-${RELEASE}
pip install ./
# add user and group
addgroup -S mktxp
adduser -S mktxp -G mktxp
# create config

cat <<EOF >/etc/mktxp/mktxp.conf
# MKTXP service configuration
# documentation: https://github.com/akpw/mktxp#getting-started

[Sample-Router-1]
    # for specific configuration on the router level, overload the defaults here
    hostname = 192.168.88.1


[Sample-Router-2]
    # for specific configuration on the router level, overload the defaults here
    hostname = 192.168.88.2

[default]
    # this affects configuration of all routers, unless overloaded on their specific levels

    enabled = True          # turns metrics collection for this RouterOS device on / off
    hostname = localhost    # RouterOS IP address
    port = 8728             # RouterOS IP Port

    username = username     # RouterOS user, needs to have 'read' and 'api' permissions
    password = password

    use_ssl = False                 # enables connection via API-SSL servis
    no_ssl_certificate = False      # enables API_SSL connect without router SSL certificate
    ssl_certificate_verify = False  # turns SSL certificate verification on / off
    ssl_ca_file = ""                # path to the certificate authority file to validate against, leave empty to use system store
    plaintext_login = True          # for legacy RouterOS versions below 6.43 use False

    health = True                   # System Health metrics
    installed_packages = True       # Installed packages
    dhcp = True                     # DHCP general metrics
    dhcp_lease = True               # DHCP lease metrics

    connections = True              # IP connections metrics
    connection_stats = False        # Open IP connections metrics

    interface = True                # Interfaces traffic metrics

    route = True                    # IPv4 Routes metrics
    pool = True                     # IPv4 Pool metrics
    firewall = True                 # IPv4 Firewall rules traffic metrics
    neighbor = True                 # IPv4 Reachable Neighbors
    dns = False                     # DNS stats

    ipv6_route = False              # IPv6 Routes metrics
    ipv6_pool = False               # IPv6 Pool metrics
    ipv6_firewall = False           # IPv6 Firewall rules traffic metrics
    ipv6_neighbor = False           # IPv6 Reachable Neighbors

    poe = True                      # POE metrics
    monitor = True                  # Interface monitor metrics
    netwatch = True                 # Netwatch metrics
    public_ip = True                # Public IP metrics
    wireless = True                 # WLAN general metrics
    wireless_clients = True         # WLAN clients metrics
    capsman = True                  # CAPsMAN general metrics
    capsman_clients = True          # CAPsMAN clients metrics

    eoip = False                    # EoIP status metrics
    gre = False                     # GRE status metrics
    ipip = False                    # IPIP status metrics
    lte = False                     # LTE signal and status metrics (requires additional 'test' permission policy on RouterOS v6)
    ipsec = False                   # IPSec active peer metrics
    switch_port = False             # Switch Port metrics

    kid_control_assigned = False    # Allow Kid Control metrics for connected devices with assigned users
    kid_control_dynamic = False     # Allow Kid Control metrics for all connected devices, including those without assigned user

    user = True                     # Active Users metrics
    queue = True                    # Queues metrics

    bgp = False                     # BGP sessions metrics
    routing_stats = False           # Routing process stats
    certificate = False             # Certificates metrics

    remote_dhcp_entry = None        # An MKTXP entry to provide for remote DHCP info / resolution
    remote_capsman_entry = None     # An MKTXP entry to provide for remote capsman info

    use_comments_over_names = True  # when available, forces using comments over the interfaces names
    check_for_updates = False       # check for available ROS updates

EOF

cat <<EOF >/etc/mktxp/_mktxp.conf
# MKTXP system configuration
# documentation: https://github.com/akpw/mktxp#mktxp-system-configuration

[MKTXP]
    listen = '0.0.0.0:9090'         # Space separated list of socket addresses to listen to, both IPV4 and IPV6
    socket_timeout = 2
    
    initial_delay_on_failure = 120
    max_delay_on_failure = 900
    delay_inc_div = 5

    bandwidth = False               # Turns metrics bandwidth metrics collection on / off    
    bandwidth_test_interval = 600   # Interval for collecting bandwidth metrics
    minimal_collect_interval = 5    # Minimal metric collection interval

    verbose_mode = False            # Set it on for troubleshooting

    fetch_routers_in_parallel = False   # Fetch metrics from multiple routers in parallel / sequentially     
    max_worker_threads = 5              # Max number of worker threads that can fetch routers (parallel fetch only)
    max_scrape_duration = 10            # Max duration of individual routers' metrics collection (parallel fetch only)
    total_max_scrape_duration = 30      # Max overall duration of all metrics collection (parallel fetch only)

    compact_default_conf_values = False # Compact mktxp.conf, so only specific values are kept on the individual routers' level    

EOF
msg_ok "Installed MKTXP"

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/mktxp.service
[Unit]
Description=MKTXP Exporter
After=network-online.target

[Service]
Type=simple
WorkingDirectory=/etc/mktxp
Environment="PATH=/usr/local/bin:/usr/bin"
ExecStart=mktxp --cfg-dir /etc/mktxp export
User=mktxp
Restart=always

[Install]
WantedBy=default.target
EOF
systemctl enable -q --now mktxp
msg_ok "Created Service"

motd_ssh
customize

msg_info "Cleaning Up"
rm -rf /tmp/mktxp-${RELEASE}
msg_ok "Cleaned"

msg_ok "Installed Successfully"
