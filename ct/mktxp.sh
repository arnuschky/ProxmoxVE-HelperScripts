#!/usr/bin/env bash
set -x
source <(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/misc/build.func)
# Copyright (c) 2021-2025 community-scripts ORG
# Author: arnuschky
# License: MIT | https://github.com/community-scripts/ProxmoxVE/raw/main/LICENSE
# Source: https://github.com/akpw/mktxp

APP="MKTXP"
var_tags="${var_tags:-monitoring}"
var_cpu="${var_cpu:-1}"
var_ram="${var_ram:-256}"
var_disk="${var_disk:-1}"
var_os="${var_os:-debian}"
var_version="${var_version:-12}"
var_unprivileged="${var_unprivileged:-1}"

header_info "$APP"
variables
color
catch_errors

function update_script() {
  header_info
  check_container_storage
  check_container_resources
  if [[ ! -d /etc/mktxp ]]; then
      msg_error "No ${APP} Installation Found!"
      exit
  fi
  msg_info "Updating $APP LXC"
  $STD apt-get update
  $STD apt-get -y upgrade
  # fetch and unpack
  RELEASE=$(curl -fsSL https://api.github.com/repos/akpw/mktxp/releases/latest | grep "tag_name" | awk '{print substr($2, 3, length($2)-4) }')
  curl -fsSL "https://github.com/akpw/mktxp/archive/refs/tags/v${RELEASE}.tar.gz" | tar -xzf - -C /tmp
  # install release via pip
  cd /tmp/mktxp-${RELEASE}
  pip install ./
  rm -rf /tmp/mktxp-${RELEASE}
  msg_ok "Updated $APP LXC"
  exit
}

start
build_container
description

msg_ok "Completed Successfully!\n"
echo -e "${CREATING}${GN}${APP} setup has been successfully initialized!${CL}"
echo -e "${INFO}${YW} Access it using the following URL:${CL}"
echo -e "${TAB}${GATEWAY}${BGN}http://${IP}:9090${CL}"
