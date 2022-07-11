#!/bin/bash

source /etc/bash.bashrc

instance_type="p"
read -p "Are you installing on a Server or Personal Computer? (s for server| p for personal computer): " instance_type

if [[ -z $instance_type ]]; then
  echo "Please enter an instance type"
  exit 0
fi

if [[ "$instance_type" == "s" ]]; then
  read -p "Please enter a valid email FROM which the antivirus reports will be sent: " antivirus_from_email
  read -p "Please enter a valid email TO which the antivirus reports will be sent: " antivirus_to_email
fi

# CHKROOTKIT
echo "Installing and Configuring CHKROOT..."
read -p "Do you want to install CHKROOTKIT? (yes|no): " install_chkrootkit

if [[ "$install_chkrootkit" == "yes" ]]; then
  sudo apt install chkrootkit -y
  if [[ "$instance_type" == "p" ]]; then
    sudo bash -c 'cat << EOF > /etc/cron.daily/chkrootkit
#!/bin/bash

set -e

CHKROOTKIT=/usr/sbin/chkrootkit
CF=/etc/chkrootkit.conf
LOG_DIR=/var/log/chkrootkit
LOG_FILE="\$LOG_DIR/chkrootkit-\$(date +'%Y-%m-%d')-scan.log"
IGNORE_FILE=/dev/null

if [ ! -x \$CHKROOTKIT ]; then
  exit 0
fi

if [ -f \$CF ]; then
    . \$CF
fi

if [ "\$RUN_DAILY" = "true" ]; then
    eval \$CHKROOTKIT \$RUN_DAILY_OPTS > \$LOG_FILE 2>&1
    
    # get the value of "Infected lines"
    ROOTKIT=\$(cat "\$LOG_FILE"|grep INFECTED);
    
fi

EOF'

  else
    sudo bash -c 'cat << EOF > /etc/cron.daily/chkrootkit
#!/bin/bash

set -e

FROM_EMAIL=antivirus_from_email
TO_EMAIL=antivirus_to_email
CHKROOTKIT=/usr/sbin/chkrootkit
CF=/etc/chkrootkit.conf
LOG_DIR=/var/log/chkrootkit
LOG_FILE="\$LOG_DIR/chkrootkit-\$(date +'%Y-%m-%d')-scan.log"
IGNORE_FILE=/dev/null

if [ ! -x \$CHKROOTKIT ]; then
  exit 0
fi

if [ -f \$CF ]; then
    . \$CF
fi

if [ "\$RUN_DAILY" = "true" ]; then
    eval \$CHKROOTKIT \$RUN_DAILY_OPTS > \$LOG_FILE 2>&1
    
    # get the value of "Infected lines"
    ROOTKIT=\$(cat "\$LOG_FILE"|grep INFECTED);
    
    # if the value is not equal to zero, send an email with the log file attached
    if ! [[ -z "\$ROOTKIT" ]]; then
        echo "Rootkit found. Please find the details in file. <br/> \$ROOTKIT" | mail -A \$LOG_FILE -s "CHKROOTKIT - RootKit Found: \$( hostname -I)" -a "FROM:\$(hostname)  <\$FROM_EMAIL>" "\$TO_EMAIL";
    fi
    
fi

EOF'
  sudo sed -i -e "s/^FROM_EMAIL=antivirus_from_email/FROM_EMAIL=\"$antivirus_from_email\"/" /etc/cron.daily/chkrootkit
  sudo sed -i -e "s/^TO_EMAIL=antivirus_to_email/TO_EMAIL=\"$antivirus_to_email\"/" /etc/cron.daily/chkrootkit
  fi

  sudo bash -c 'cat << EOF > /etc/chkrootkit.conf
RUN_DAILY="true"
RUN_DAILY_OPTS=""
DIFF_MODE="false"

EOF'

  sudo chmod +x /etc/cron.daily/chkrootkit

  echo "CHKROOT Installation Complete!"
  echo ""
else
  echo "Skipping CHKROOTKIT installation..."
fi

# CLAMAV
echo "Installing and Configuring ClamAV..."
read -p "Do you want to install ClamAV? (yes|no): " install_clamav

if [[ "$install_clamav" == "yes" ]]; then
  sudo apt install clamav -y
  if [[ "$instance_type" == "p" ]]; then
    sudo bash -c 'cat << EOF > /etc/cron.daily/clamscan
#!/bin/bash

LOG_FILE="/var/log/clamav/clamav-\$(date +'%Y-%m-%d')-scan.log";
DIRTOSCAN="/";

for S in \${DIRTOSCAN}; do
 echo "Starting a daily scan of \"\$S\" directory"

 clamscan -ri "\$S" >> "\$LOG_FILE";

 # get the value of "Infected lines"
 MALWARE=\$(tail "\$LOG_FILE"|grep Infected|cut -d" " -f3);

done

exit 0

EOF'

  else

    sudo bash -c 'cat << EOF > /etc/cron.daily/clamscan
#!/bin/bash

FROM_EMAIL=antivirus_from_email
TO_EMAIL=antivirus_to_email
LOG_FILE="/var/log/clamav/clamav-\$(date +'%Y-%m-%d')-scan.log";
DIRTOSCAN="/";

for S in \${DIRTOSCAN}; do
 echo "Starting a daily scan of \"\$S\" directory"

 clamscan -ri "\$S" >> "\$LOG_FILE";

 # get the value of "Infected lines"
 MALWARE=\$(tail "\$LOG_FILE"|grep Infected|cut -d" " -f3);
 
 # if the value is not equal to zero, send an email with the log file attached
 if [ "\$MALWARE" -ne "0" ]; then
    echo "Malware found. Please find the details in file. <br/> \$MALWARE" | mail -A \$LOG_FILE -s "ClamAV - Malware Found: \$( hostname -I)" -a "FROM:\$(hostname)  <\$FROM_EMAIL>" "\$TO_EMAIL";
 fi 

done

exit 0

EOF'
  sudo sed -i -e "s/^FROM_EMAIL=antivirus_from_email/FROM_EMAIL=\"$antivirus_from_email\"/" /etc/cron.daily/clamscan
  sudo sed -i -e "s/^TO_EMAIL=antivirus_to_email/TO_EMAIL=\"$antivirus_to_email\"/" /etc/cron.daily/clamscan
  fi

  sudo chmod +x /etc/cron.daily/clamscan
  echo "ClamAV Installation Complete!"
  echo ""

else
  echo "Skipping ClamAV installation..."

fi
