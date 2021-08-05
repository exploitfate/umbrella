#!/usr/bin/env bash

SERVICE_NAME_FILE=umbrella.service
SYSTEMD_SERVICE_UNIT_PATH=/etc/systemd/system/$SERVICE_NAME_FILE
UMBRELLA_PATH=/usr/local/bin/umbrella.sh

if [ ! -f $SYSTEMD_SERVICE_UNIT_PATH ]; then
  echo '[Unit]
After=named.service

[Service]
ExecStart=$UMBRELLA_PATH

[Install]
WantedBy=default.target
' | sudo tee $SYSTEMD_SERVICE_UNIT_PATH
  sudo chmod 664 $SYSTEMD_SERVICE_UNIT_PATH
  sudo systemctl daemon-reload
  sudo systemctl enable $SERVICE_NAME_FILE
fi

if [ ! -f $UMBRELLA_PATH ]; then
  sudo wget https://raw.githubusercontent.com/exploitfate/umbrella/main/umbrella.sh -O $UMBRELLA_PATH
  sudo chmod +x $UMBRELLA_PATH
fi

sudo apt update -qq
sudo apt install -y dnsutils wget zip unzip parallel