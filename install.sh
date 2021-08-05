#!/usr/bin/env bash

SERVICE_NAME_FILE=umbrella.service
SYSTEMD_SERVICE_UNIT_PATH=/etc/systemd/system/$SERVICE_NAME_FILE
UMBRELLA_PATH=/usr/local/bin/umbrella.sh

if [ ! -f "$SYSTEMD_SERVICE_UNIT_PATH" ]; then
  echo "[Unit]
After=named.service

[Service]
ExecStart=$UMBRELLA_PATH

[Install]
WantedBy=default.target
" | sudo tee $SYSTEMD_SERVICE_UNIT_PATH > /dev/null 2>&1
  sudo chmod 664 $SYSTEMD_SERVICE_UNIT_PATH
  sudo systemctl daemon-reload
  sudo systemctl enable $SERVICE_NAME_FILE
fi

if [ ! -f "$UMBRELLA_PATH" ]; then
  sudo wget -nv -qO https://raw.githubusercontent.com/exploitfate/umbrella/main/umbrella.sh $UMBRELLA_PATH
  sudo chmod +x $UMBRELLA_PATH
fi

sudo apt update -qq
sudo apt install -q -y dnsutils wget zip unzip parallel