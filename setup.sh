#! /usr/bin/bash
if [ "$EUID" -ne 0 ]
  then echo "Please run as root"
  exit
fi
pip install -r "requirements.txt"
chmod 777 *
for i in `ls |grep -v setup.sh`
do
  mv $i /bin
done

echo "All done "
