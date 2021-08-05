#!/usr/bin/env bash

SERVICE_NAME_FILE=umbrella.service
SYSTEMD_SERVICE_UNIT_PATH=/etc/systemd/system/$SERVICE_NAME_FILE
UMBRELLA_PATH=/usr/local/bin/umbrella.sh

if [ ! -f "$SYSTEMD_SERVICE_UNIT_PATH" ]; then
  echo "[Unit]
Description=Propagate DNS cache with top 200k CISCO Umbrella domains
PartOf=named.service
After=named.service

[Service]
Type=simple
Restart=always
ExecStart=$UMBRELLA_PATH

[Install]
WantedBy=named.target
" | sudo tee $SYSTEMD_SERVICE_UNIT_PATH > /dev/null 2>&1
  sudo chmod 664 $SYSTEMD_SERVICE_UNIT_PATH
  sudo mkdir -p /etc/systemd/system/named.service.d/
  echo "[Unit]
Requires=umbrella.service
" | sudo tee /etc/systemd/system/named.service.d/override.conf > /dev/null 2>&1
  sudo systemctl daemon-reload
  sudo systemctl enable $SERVICE_NAME_FILE
fi

if [ ! -f "$UMBRELLA_PATH" ]; then
  sudo wget -nv -qO $UMBRELLA_PATH https://raw.githubusercontent.com/exploitfate/umbrella/main/umbrella.sh
  sudo chmod +x $UMBRELLA_PATH
fi

sudo apt update -qq
sudo apt install -qq -y dnsutils wget zip unzip parallel
