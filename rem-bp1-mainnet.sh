#!/bin/bash

#****************************************************************************************************#
#                                       REM-BP1-MAINNET-SETUP                                        #
#****************************************************************************************************#

#----------------------------------------------------------------------------------------------------#
# IF THE USER HAS NO ROOT PERMISSIONS THE SCRIPT WILL EXIT                                           #
#----------------------------------------------------------------------------------------------------#

if (($EUID!=0))
then
  echo "You must be root to run this script" 2>&1
  exit 1
fi

#----------------------------------------------------------------------------------------------------#
# CONFIGURATION VARIABLES                                                                            #
#----------------------------------------------------------------------------------------------------#

producer=remblock21bp
wallet_name=walletpass
domain=rem.remblock.io
create_ssh_dir=/root/.ssh
create_data_dir=/root/data
contact=contact@remblock.io
new_hostname=rem-bp1-mainnet
create_config_dir=/root/config
remnode_log_file=/root/remnode.log
config_file=/root/config/config.ini
create_snapshot_dir=/root/data/snapshots
bp_public_key=EOS8em2a1NeNUFtwd8ZC2VzjkUXuHf3b6wPVTFEqocvRFVvd9FFmS
bp_private_key=
ssh_public_key="ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQC5govVMkNP5HyBQ+DBWSbUe97qyKVzoI5s1lR+x1HCSdetS8dacN6e86eWaWNUQBBr6O0AttbXULqxvOBNF1GzWFw0T1jFr9lCtuz2Y06KGjJBHRHXopeSp6VHJr+BG4Q4l9fzguYO/EmQf9Y48eCXCs4eFkKE6mFlfGkNvRInpz6bbRvwYOFEEKiTyLXE6y1910dVrgLTd2P1kyh88aCwuF4GnexM4AsipzKpSCR3/s/gqxK4YpW8KsMBCdcQMYHZ2dgxoscudcp2l88hgnQJOriYOfjAnXSKttaGNRsER/hEcKGKJsRPELJZLCn+Ahv322GTsnTRMvipfXUtDqoTdpteM5lSz+GlUe6get+O501kTz9xF9aMK7fJdj264mzj8JfvxKsZFKfsDJvTkoIV8GPdzSk5fYr8W+lFzrNXKqHBeR8+WXdVYKIq8l6Y3NOCUcf6I+kYeHPKOAqkl8mSue2Q9GPGTn8z3tAg1ASuNxFQCqhcDCyF4RcZzVMfTO6tTe56Udt/mOr2QRb6C8+wI4YK9l6Un+S6MLAt1EQZyHEm/uI0Cv4SIvh2X4ksZLEgNNAcw63MxEOLnUiGacrhKG1v4qixtjaZITkc0M518J43FK8157q0DJwbMDQCOLCWyqoytRYNhfdNvTc6sefJBJOMqKbUwGxvrZue9T6BnQ== root@REMBLOCK"

#----------------------------------------------------------------------------------------------------#
# CREATE DIRECTORIES IF THEY DON'T EXIST                                                             #
#----------------------------------------------------------------------------------------------------#

if [ ! -d "$create_data_dir" -o -d "$create_config_dir" -o -d "$create_snapshot_dir" ]
then
  mkdir -p $create_ssh_dir
  mkdir -p $create_data_dir
  mkdir -p $create_config_dir
  mkdir -p $create_snapshot_dir
fi

#----------------------------------------------------------------------------------------------------#
# ADJUSTING SERVER HOSTNAME                                                                          #
#----------------------------------------------------------------------------------------------------#

old_hostname=$(hostname)
sudo hostnamectl set-hostname $new_hostname
sed -i "s/$old_hostname/$new_hostname/g" /etc/hosts

#----------------------------------------------------------------------------------------------------#
# UPDATING AND UPGRADING PACKAGE DATABASE                                                            #
#----------------------------------------------------------------------------------------------------#

sudo -S apt update -y && sudo -S apt upgrade -y
sudo apt install linux-tools-common -y
sudo apt install linux-cloud-tools-generic -y
sudo apt install linux-tools-4.15.0-115-generic -y
sudo apt install linux-cloud-tools-4.15.0-115-generic -y

#----------------------------------------------------------------------------------------------------#
# INSTALLING CANONICAL LIVEPATCH SERVICE                                                             #
#----------------------------------------------------------------------------------------------------#

sudo apt install snapd -y
sudo snap install canonical-livepatch

#----------------------------------------------------------------------------------------------------#
# INSTALLING CERTBOT                                                                                 #
#----------------------------------------------------------------------------------------------------#

sudo snap install --classic certbot

#----------------------------------------------------------------------------------------------------#
# FETCHING REM PROTOCOL GENESIS.JSON, BLOCKS AND SNAPSHOT                                            #
#----------------------------------------------------------------------------------------------------#

wget https://remchain.remme.io/genesis.json
wget https://github.com/remblock/REM-Protocol/raw/master/rem-restore-snapshot.sh

#----------------------------------------------------------------------------------------------------#
# ADJUSTING SERVER TIMEZONE TO UTC                                                                   #
#----------------------------------------------------------------------------------------------------#

sudo timedatectl set-timezone UTC

#----------------------------------------------------------------------------------------------------#
# FETCHING YES OR NO ANSWER FROM USER                                                                #
#----------------------------------------------------------------------------------------------------#

function get_user_answer_yn(){
  while :
  do
    read -p "$1 [y/n]: " answer
    answer="$(echo $answer | tr '[:upper:]' '[:lower:]')"
    case "$answer" in
      yes|y) return 0 ;;
      no|n) return 1 ;;
      *) echo  "Invalid Answer [yes/y/no/n expected]";continue;;
    esac
  done
}

#----------------------------------------------------------------------------------------------------#
# CONFIGURATION FILE (CONFIG/CONFIG.INI)                                                             #
#----------------------------------------------------------------------------------------------------#

echo -e "#------------------------------------------------------------------------------#" > $config_file
echo -e "# EOSIO PLUGINS                                                                #" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "\nplugin = eosio::net_plugin\nplugin = eosio::http_plugin\nplugin = eosio::chain_plugin\nplugin = eosio::net_api_plugin\nplugin = eosio::producer_plugin\nplugin = eosio::chain_api_plugin\n" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "# CONFIG SETTINGS                                                              #" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "\nmax-clients = 50\nchain-threads = 8\nsync-fetch-span = 200\neos-vm-oc-enable = true\npause-on-startup = false\nwasm-runtime = eos-vm-jit\nmax-transaction-time = 30\nhttp-validate-host = false\nverbose-http-errors = true\ntxn-reference-block-lag = 0\neos-vm-oc-compile-threads = 8\nconnection-cleanup-period = 30\nchain-state-db-size-mb = 100480\nenable-stale-production = false\nmax-irreversible-block-age = -1\naccess-control-allow-origin = "*"\naccess-control-allow-headers = "*"\nhttp-server-address = 0.0.0.0:8888\nhttps-server-address = 0.0.0.0:443\np2p-listen-endpoint = 0.0.0.0:9876\nreversible-blocks-db-size-mb = 10480\n" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "# PRODUCER SETTINGS                                                            #" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "\nproducer-name = $producer\nsignature-provider = $bp_public_key=KEY:$bp_private_key\n" >> $config_file
echo -e "#------------------------------------------------------------------------------#" >> $config_file
echo -e "# REM PROTOCOL P2P PEER ADDRESSES                                              #" >> $config_file
echo -e "#------------------------------------------------------------------------------#\n" >> $config_file
wget https://github.com/remblock/REM-Protocol/raw/master/rem-peer-list.ini
cat /root/rem-peer-list.ini >> $config_file
echo -e "\n#-------------------------------------------------------------------------------\n" >> $config_file

#----------------------------------------------------------------------------------------------------#
# INSTALL AND INITIALIZE SSL CERTIFCATE                                                              #
#----------------------------------------------------------------------------------------------------#

cd ~
ssl_certificate_path=$(certbot certificates | grep 'Certificate Path:' | awk '{print $3}')
ssl_private_key_path=$(certbot certificates | grep 'Private Key Path:' | awk '{print $4}')
echo ""
if [ ! -z "$ssl_certificate_path" ] && [ ! -z "$ssl_private_key_path" ]
then
  echo -e "https-private-key-file = $ssl_private_key_path" >> $config_file
  echo -e "https-certificate-chain-file = $ssl_certificate_path" >> $config_file
  echo -e "\n#-------------------------------------------------------------------------------\n" >> $config_file
fi
if [ -z "$ssl_certificate_path" ] || [ -z "$ssl_private_key_path" ]
then
  if get_user_answer_yn "CREATE A NEW SSL CERTIFCATE?"
  then
    sudo certbot certonly --standalone --agree-tos --noninteractive --preferred-challenges http --email $contact --domains $domain
    ssl_certificate_path=$(certbot certificates | grep 'Certificate Path:' | awk '{print $3}')
    ssl_private_key_path=$(certbot certificates | grep 'Private Key Path:' | awk '{print $4}')
    echo -e "https-private-key-file = $ssl_private_key_path" >> $config_file
    echo -e "https-certificate-chain-file = $ssl_certificate_path" >> $config_file
    echo -e "\n#-------------------------------------------------------------------------------\n" >> $config_file
  else
    echo ""
    if get_user_answer_yn "USE EXISTING SSL CERTIFCATE?"
    then
      echo ""
      read -p "ENTER YOUR SSL CERTIFCATE PATH: " -e ssl_certificate_path
      echo ""
      read -p "ENTER YOUR SSL PRIVATE KEY PATH: " -e ssl_private_key_path
      echo ""
      ssl_certificate_path=$(certbot certificates | grep 'Certificate Path:' | awk '{print $3}')
      ssl_private_key_path=$(certbot certificates | grep 'Private Key Path:' | awk '{print $4}')
      echo -e "https-private-key-file = $ssl_private_key_path" >> $config_file
      echo -e "https-certificate-chain-file = $ssl_certificate_path" >> $config_file
      echo -e "\n#-------------------------------------------------------------------------------\n" >> $config_file
    fi
  fi
fi

#----------------------------------------------------------------------------------------------------#
# CHANGING DEFAULT SSH PORT NUMBER                                                                   #
#----------------------------------------------------------------------------------------------------#

while [ : ]
do
         echo ""
	 read -p "PLEASE ENTER A RANDOM 5 DIGIT PORT NUMBER: " port

         if [[ ${#port} -ne 5 ]]
         then
                 printf "\nERROR: PORT NUMBER SHOULD BE EXACTLY 5 DIGITS.\n\n"
                 continue
         elif [[ ! -z "${port//[0-9]}" ]]
         then
                 printf "\nERROR: PORT NUMBER SHOULD CONTAIN NUMBERS ONLY.\n\n"
                 continue
         else
                 sudo -S sed -i "/^#Port 22/s/#Port 22/Port $port/" /etc/ssh/sshd_config && sed -i '/^PermitRootLogin/s/yes/without-password/' /etc/ssh/sshd_config && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication no/' /etc/ssh/sshd_config
		 echo ""
		 break
         fi
done

#----------------------------------------------------------------------------------------------------#
# INSTALLING APACHE WEB SERVER                                                                       #
#----------------------------------------------------------------------------------------------------#

sudo apt install apache2 -y
sudo mkdir -p /var/www/$domain
sudo chown -R $USER:$USER /var/www/$domain
sudo chmod -R 755 /var/www/$domain
echo -e "<VirtualHost *:80>
    ProxyPreserveHost On
    ProxyRequests Off
    ServerName http://$domain
    ServerAlias http://$domain
    DocumentRoot /var/www/$domain
    ProxyPass / http://localhost:8888/
    ProxyPassReverse / http://localhost:8888/
    ErrorLog ${APACHE_LOG_DIR}/error.log
</VirtualHost>" > /etc/apache2/sites-available/$domain.conf
sudo a2enmod proxy
sudo a2enmod proxy_http
sudo a2ensite $domain.conf
sudo a2dissite 000-default.conf
sudo service apache2 restart

#----------------------------------------------------------------------------------------------------#
# INSTALLING UNCOMPLICATED FIREWALL                                                                  #
#----------------------------------------------------------------------------------------------------#

sudo -S apt-get install ufw -y
sudo -S ufw allow ssh/tcp
sudo -S ufw limit ssh/tcp
sudo -S ufw allow 443/tcp
sudo -S ufw allow 8888/tcp
sudo -S ufw allow 9876/tcp
sudo -S ufw allow $port/tcp
sudo -S ufw logging on
sudo -S ufw enable

#----------------------------------------------------------------------------------------------------#
# INSTALLING FAIL2BAN                                                                                #
#----------------------------------------------------------------------------------------------------#

sudo -S apt install fail2ban -y
sudo -S systemctl enable fail2ban
sudo -S systemctl start fail2ban

#----------------------------------------------------------------------------------------------------#
# SETUP GRACEFUL SHUTDOWN                                                                            #
#----------------------------------------------------------------------------------------------------#

echo '#!/bin/sh
remnode_pid=$(pgrep remnode)
if [ ! -z "$remnode_pid" ]; then
if ps -p $remnode_pid > /dev/null; then
kill -SIGINT $remnode_pid
fi
while ps -p $remnode_pid > /dev/null; do
sleep 1
done
fi
' > /root/node_shutdown.sh
echo '[Unit]
Description=Gracefully shut down nodeos to avoid database dirty flag
DefaultDependencies=no
After=poweroff.target shutdown.target reboot.target halt.target kexec.target
Requires=network-online.target network.target
[Service]
Type=oneshot
ExecStop=/root/node_shutdown.sh
RemainAfterExit=yes
KillMode=none
[Install]
WantedBy=multi-user.target' > /etc/systemd/system/node_shutdown.service
sudo chmod +x /root/node_shutdown.sh
systemctl daemon-reload
systemctl enable node_shutdown
systemctl restart node_shutdown

#----------------------------------------------------------------------------------------------------#
# RESTART ALL PROCESSES ON REBOOT                                                                    #
#----------------------------------------------------------------------------------------------------#

echo '#!/bin/bash
data_dir=/root/data
config_dir=/root/config
remnode_log_file=/root/remnode.log
sudo resize2fs /dev/nvme1n1
cpupower frequency-set --governor performance
sudo remnode --config-dir $config_dir --data-dir $data_dir >> $remnode_log_file 2>&1 &
exit 0' > /etc/rc.local

sudo chmod +x /etc/rc.local

#----------------------------------------------------------------------------------------------------#
# INSTALLING REMCHAIN PROTOCOL BINARIES                                                              #
#----------------------------------------------------------------------------------------------------#

wget https://github.com/Remmeauth/remprotocol/releases/download/0.4.2/remprotocol_0.4.2.amd64.deb
sudo apt install ./remprotocol_0.4.2.amd64.deb -y

#----------------------------------------------------------------------------------------------------#
# RESTORING FROM REMNODE SNAPSHOT                                                                    #
#----------------------------------------------------------------------------------------------------#

sudo chmod u+x rem-restore-snapshot.sh
sudo ./rem-restore-snapshot.sh

#----------------------------------------------------------------------------------------------------#
# CREATING REM PROTOCOL WALLET                                                                       #
#----------------------------------------------------------------------------------------------------#

remcli wallet create -n $wallet_name --file $wallet_name
remcli wallet unlock -n $wallet_name --password=$walletpass > /dev/null 2>&1
remcli wallet import -n $wallet_name --private-key=$producer_private_key

#----------------------------------------------------------------------------------------------------#
# CLEANUP INSTALLATION FILES                                                                         #
#----------------------------------------------------------------------------------------------------#

rm /root/rem-peer-list.ini
rm /root/rem-bp1-mainnet.sh
rm /root/remprotocol_0.4.2.amd64.deb

#----------------------------------------------------------------------------------------------------#
# ADDING SSH PUBLIC KEY TO SERVER                                                                    #
#----------------------------------------------------------------------------------------------------#

echo $ssh_public_key > ~/.ssh/id_rsa.pub
cat ~/.ssh/id_rsa.pub > ~/.ssh/authorized_keys
sudo -S service sshd restart
echo ""
echo "==================================="
echo "REM-BP1-MAINNET SETUP HAS COMPLETED"
echo "==================================="
echo ""
