# !/bin/sh

# DEFAULTS
dns="1.1.1.1, 8.8.8.8"
allowed_ips="0.0.0.0/0"
keepalive="-1"

##

help=false
syntax=false


new(){
    echo hi
}
new-push(){
    echo hi
}


while [ $# -gt 0 ] && [ "$syntax" == "false" ] ; do
    case "$1" in
        # OPTIONS
        -h|--help) help=true ;;
        # COMMANDS
        new)
            syntax="new {<client-ip-address>} {<server endpoint>} {-f <server-pubkey-file> | -k <server-pubkey>} {-z <zip-conf> | -q <qr-conf> | -c <conf-file>} [-d <dns>] [-a <allowed-ips>] [-s <save-pubkey>] [-p <keepalive-seconds>]"
            if [ $help != "true" ]; then shift; new $*; fi
        ;;
        new-push)
            syntax="new-push {<interface-name>} {<client-ip-address>} {<server endpoint>} {-z <conf-zip> | -q <qr-conf> | -c <file-conf>} [-d <dns>] [-a <allowed-ips>] [-s <save-pubkey>] [-p <keepalive-seconds>] "
            if [ $help != "true" ]; then shift; show $*; fi
        ;;
        *)
            if [ ! -z $1 ] ; then # Avoid flagging stopping on empty arguments
                help=true
                syntax="Unknown command: '$1'"
            fi
        ;;
    esac
    shift
done

if [ "$help" == "true" ] && [ "$syntax" == "false" ] ; then # Full help
    echo "Check readme for full help"
elif [ "$help" == "true" ] && [ "$syntax" != "false" ] ; then # Command explanation or wrong args
    echo $syntax
elif [ "$help" == "false" ] && [ "$syntax" == "false" ] ; then # Running without command or help
    echo "Syntax: bash client_wg-config.sh [options] <command> <arguments> [optional arguments] ";

fi

# Generate QR code
# gen_qr() {
#   local config_name="${1}"
#   local output="${2}"
#   local config_path="${WORKING_DIR}/client-${config_name}.conf"
#
#   if [[ ! -f ${config_path} ]]; then
#     echo -e "${RED}ERROR${NONE}: Error while generating QR code, config file ${BLUE}${config_path}${NONE} does not exist!"
#     exit 1
#   fi
#
#   local options="-o ${config_path}.png"
#   if [[ ${output} == "-" ]]; then
#     local options="-t ANSIUTF8 -o -"
#   fi
#
#   cat ${config_path} | qrencode ${options}
#
#   if [[ ${output} != "-" ]]; then
#     chmod 600 ${config_path}.png
#     echo -e "${GREEN}INFO${NONE}: QR file ${BLUE}${config_path}.png${NONE} has been generated successfully!"
#   fi
# }

# allow client to export pubkey to file
# cat > ${client_config} <<EOF && chmod 600 ${client_config}
# [Interface]
# Address = ${client_wg_ip}/${cidr}
# PrivateKey = $(head -1 ${client_private_key})
# DNS = $(echo ${client_dns_ips} | sed -E 's/ +/, /g')
# [Peer]
# PublicKey = $(head -1 ${server_public_key})
# PresharedKey = $(head -1 ${preshared_key})
# AllowedIPs = $(echo ${client_allowed_ips} | sed -E 's/ +/, /g')
# Endpoint = ${server_public_ip}:${server_port}
# PersistentKeepalive = 25
# EOF
