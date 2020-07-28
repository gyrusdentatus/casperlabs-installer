#!/bin/bash

## Colours variables for the installation script
RED='\033[1;91m' # WARNINGS
YELLOW='\033[1;93m' # HIGHLIGHTS
WHITE='\033[1;97m' # LARGER FONT
LBLUE='\033[1;96m' # HIGHLIGHTS / NUMBERS ...
LGREEN='\033[1;92m' # SUCCESS
NOCOLOR='\033[0m' # DEFAULT FONT
#set -x
## Get server ipv4
ip_addr=`curl -sS v4.icanhazip.com`

data_dir=$HOME/.casperlabs/casperlabs

function casper_ufw {


# Check if ufw is enabled or not
ufw status | grep -i in && inactive="1" || is_active="1"


if [ "${inactive}" == 1 ]
then
    printf '\n\n\n'
    printf "%b\n\n\n" "${YELLOW} ufw ${WHITE} (Firewall) is ${RED} inactive"
    sleep 1
    printf "%b\n\n\n" "${LGREEN} Enable it ${WHITE} and ${LGREEN} allow rules ${WHITE}for  casperlabs-ode?\n"
    while true ; do
        read -p  $'\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;37m] Do you want to continue \e[1;92mYes - (Yy) \e[1;37m or  \e[1;91mNo - (Nn)  ?? :  \e[0m' yn
        printf '\n\n\n'
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit;;
        esac
    done
    ufw allow 40400:40404/tcp > /dev/null 2>&1 && printf "%b\n\n\n" "${YELLOW} ports ${LBLUE} 40400, 40401, 40403, 40404 ${WHITE} were ${LGREEN} allowed ${WHITE} in ufw settings"
   # Allow ssh just in case
    # To avoid locking the user from the server
    ufw allow 22/tcp && ufw limit 22/tcp
    ufw enable
    ufw status
else [ "$is_active" == 1 ]

    printf '\n\n\n'
    printf "%b\n\n\n" "${YELLOW} ufw ${WHITE} (Firewall) is ${LGREEN} active"
    sleep 1
    printf "%b\n\n\n" "${LGREEN} allow rules ${WHITE}for  casperlabs-node?\n"
    while true ; do
        read -p  $'\e[1;92m[\e[0m\e[1;77m*\e[0m\e[1;37m] Do you want to continue \e[1;92mYes - (Yy) \e[1;37m or  \e[1;91mNo - (Nn)  ?? :  \e[0m' yn
        printf '\n\n\n'
        case $yn in
            [Yy]* ) break;;
            [Nn]* ) exit;;
        esac
    done
    ufw allow 40400:40404/tcp > /dev/null 2>&1 && printf "%b\n\n\n" "${YELLOW} ports ${LBLUE} 40400, 40401, 40403, 40404 ${WHITE} were ${LGREEN} allowed ${WHITE} in ufw settings"
    ufw status


fi
}



function get_chainspec () {
mkdir -p ~/.casperlabs/chainspec/genesis

cd ~/.casperlabs/chainspec/genesis

curl -O https://raw.githubusercontent.com/CasperLabs/CasperLabs/dev/testnet/accounts.csv
curl -O https://raw.githubusercontent.com/CasperLabs/CasperLabs/dev/testnet/manifest.toml

}
function start_exec_engine() {
casperlabs-engine-grpc-server ~/.casperlabs/.casper-node.sock
}


function add_repos() {
 if [ ! -e /etc/apt/sources.list.d/casperlabs.list ]
   then
     printf "%b\n\n\n" "${WHITE} Adding casperlabs sources.list to /etc/apt/sources.list.d/ ..."
     echo "deb https://dl.bintray.com/casperlabs/debian /" | sudo tee -a /etc/apt/sources.list.d/casperlabs.list
     printf "%b\n\n\n" "${WHITE} Fetching casperlabs public key ..."
     curl -o casperlabs-public.key.asc https://bintray.com/user/downloadSubjectPublicKey?username=casperlabs ## // for da sake of develepoment // > /dev/null 2>&1
     printf "%b\n\n\n" "${WHITE} Adding casperlabs public key to apt ..."
     apt-key add casperlabs-public.key.asc
     printf "%b\n\n\n" "${WHITE} Updating apt sources ..."
     apt update > /dev/null 2>&1
     printf "%b\n\n\n" "${WHITE} Installing casperlabs and casperlabs-client ..."
     apt install casperlabs casperlabs-client -y > /dev/null 2>&1 && printf "%b\n\n\n" "${WHITE} Casperlabs successfully downloaded and installed ..." 
   else
     printf "%b\n\n\n" "${WHITE} Casperlabs are already in your apt sources.list.d/ directory ..."
     printf "%b\n\n\n" "${WHITE} Skipping ..."
 fi
}
function create_config() {
 if [ ! -e /etc/casperlabs/config.toml ]
    then
        mkdir /etc/casperlabs/
        printf '%s\n' " [server] " > /etc/casperlabs/config.toml
        printf '%s\n' " host=${ip_addr} " >> /etc/casperlabs/config.toml
        cat config.toml >> /etc/casperlabs/config.toml
    else    
        printf "%b\n\n\n" "${WHITE} config.toml already exists in ${YELLOW} /etc/casperlabs/ ${WHITE} skipping ..." 
 fi 
}

function systemd_print_node() {
  printingpath=/etc/systemd/system/casperlabs-node.service
  if [ ! -e /etc/systemd/system/casperlabs-node.service ]
    then
        printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
        printf "%b\n\n\n" "${YELLOW} Creating ${WHITE} a systemd service file to run casperlabs-node in the background: "
        printf "%b\n\n\n"

                printf '%s\n' "[Unit]" > $printingpath
                printf '%s\n' "Description=CasperLabs Node" >> $printingpath
                printf '%s\n' "After=network.target casperlabs-engine-grpc-server.service" >> $printingpath
                printf '%s\n' "BindsTo=casperlabs-engine-grpc-server.service" >> $printingpath
                printf '%s\n' "" >> $printingpath
                printf '%s\n' "[Service]" >> $printingpath
                printf '%s\n' "ENVIRONMENT=\"_JAVA_OPTIONS=-XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=$HOME/.casperlabs"\" >> $printingpath
                printf '%s\n' "ExecStart=/usr/bin/casperlabs-node --config-file=/etc/casperlabs/config.toml run --server-data-dir=$HOME/.casperlabs" >> $printingpath
                printf '%s\n' "User=casperlabs" >> $printingpath
                printf '%s\n' "Restart=no" >> $printingpath
                printf '%s\n' "" >> $printingpath
                printf '%s\n' "[Install]" >> $printingpath
                printf '%s\n' "WantedBy=multi-user.target" >> $printingpath
  fi
  if [ -e /etc/systemd/system/casperlabs-node.service ]
    then
      printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
      printf "%b\n\n\n" "${WHITE} Your node with was ${LGREEN} successfully written ${WHITE} to the systemd.service file \n\n\n"
      printf "%b\n\n\n" " ${LGREEN} Enabling ${WHITE} it for you"
      systemctl enable casperlabs-node
      printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
      printf "%b\n\n\n" "${WHITE}   casperlabs-node.service ${LGREEN} enabled!"
    else
      printf "%b\n\n\n" "${WHITE} something went wrong"
      exit 2
  fi
}
function systemd_print_engine () {
  if [ ! -e /etc/systemd/system/casperlabs-engine-grpc-server.service ]
    then
        printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
        printf "%b\n\n\n" "${YELLOW} Creating ${WHITE} a systemd service file to run casperlabs-engine-grpc-server.service in the background: "
        printf "%b\n\n\n"
    
    
        printf '%s\n' "[Unit]" > /etc/systemd/system/casperlabs-engine-grpc-server.service
        printf '%s\n' "Description=CasperLabs Engine GRPC Server" >> /etc/systemd/system/casperlabs-engine-grpc-server.service
        printf '%s\n' "After=network.target" >> /etc/systemd/system/casperlabs-engine-grpc-server.service
        printf '%s\n' "Before=casperlabs-node.service" >> /etc/systemd/system/casperlabs-engine-grpc-server.service
        printf '%s\n' "BindsTo=casperlabs-node.service" >> /etc/systemd/system/casperlabs-engine-grpc-server.service
        printf '%s\n' "" >> /etc/systemd/system/casperlabs-engine-grpc-server.service
        printf '%s\n' "[Service]" >> /etc/systemd/system/casperlabs-engine-grpc-server.service
        printf '%s\n' "ExecStart=/usr/bin/casperlabs-engine-grpc-server -d $HOME/.casperlabs/ $HOME/.casperlabs/.casper-node.sock" >> /etc/systemd/system/casperlabs-engine-grpc-server.service
        printf '%s\n' "User=casperlabs" >> /etc/systemd/system/casperlabs-engine-grpc-server.service
        printf '%s\n' "Restart=no" >> /etc/systemd/system/casperlabs-engine-grpc-server.service
        printf '%s\n' "" >> /etc/systemd/system/casperlabs-engine-grpc-server.service
        printf '%s\n' "[Install]" >> /etc/systemd/system/casperlabs-engine-grpc-server.service
        printf '%s\n' "WantedBy=multi-user.target" >> /etc/systemd/system/casperlabs-engine-grpc-server.service
    fi
    if [ -e /etc/systemd/system/casperlabs-engine-grpc-server.service ]
    then
      printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
      printf "%b\n\n\n" "${WHITE} casperlabs-engine-grpc-server was ${LGREEN} successfully written ${WHITE} to the systemd.service file \n\n\n"
      printf "%b\n\n\n" " ${LGREEN} Enabling ${WHITE} it for you"
      systemctl enable casperlabs-engine-grpc-server.service
      printf "%b\n\n\n" "${WHITE} --------------------------------------------------------------------------------"
      printf "%b\n\n\n" "${WHITE}   casperlabs-engine-grpc-server ${LGREEN} enabled! ${WHITE}"
    else
      printf "%b\n\n\n" "${WHITE} something went wrong"
      exit 2
  fi
}


function create_keys () {
  keys_directory=$HOME/.casperlabs/casperlabs/keys
  if [ -d ${keys_directory} ]
    then
      echo "keys already exist"
    else
      printf "%b\n\n\n" "${WHITE}no keys, creating a folder keys in ${keys_directory}"
      mkdir -p ${keys_directory}
  fi
  if [ -n "$(find "${keys_directory}" -maxdepth 0 -type d -empty 2>/dev/null)" ]
     then
  casperlabs-client keygen ${keys_directory}
     else
  printf "%b\n\n\n" "${WHITE} Keys exist. Remove them with your own responsibility and run the script again."
  fi
}

function full_setup () {
add_repos
casper_ufw
systemd_print_node
systemd_print_engine
get_chainspec
create_keys
cd $HOME/casperlabs-installer
create_config
chown -R casperlabs:casperlabs $HOME/.casperlabs/
chown casperlabs:casperlabs /etc/casperlabs/config.toml
systemctl start casperlabs-node.service && systemctl start casperlabs-engine-grpc-server.service
} 
full_setup
