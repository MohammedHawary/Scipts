#! /usr/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
pip install -r "requerd.txt"
chmod 777 *
mv setg /bin
mv interactive_shell /bin

echo "All done "