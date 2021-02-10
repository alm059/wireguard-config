# !/bin/sh
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

#     cat >> "/etc/wireguard/${interface_name}.conf" <<EOF
# PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${forwarding_interface} -j MASQUERADE
# PostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${forwarding_interface} -j MASQUERADE
# EOF

help=false
visualize=false
syntax=false # While false it hasn't found any command

check_run(){ # Run configuration commands
    if [ $# -gt 1 ]; then
        echo "[#]" $2
    else
        echo "[#]" $1
    fi
    if [ "$visualize" == "false" ]; then eval $1; fi
}
reminder(){
    echo "Use wg-quick up/down {<interface name>} to enable or disable an interface without deleting it"
    echo "Use wg show [<interface name>] to view the status of current interfaces"
}
new(){
    # Mandatory args
    if [ ! $# -ge 1 ] || [[ "$1" == "-"* ]] ; then
        help=true
        return
    fi
    interface_name=$1
    shift
    # Optional args
    address=10.0.0.1
    port=51820
    forwarding_interface=false
    while [ $# -gt 0 ] ; do
        case "$1" in
            -a) shift; address=$1;;
            -p) shift; port=$1;;
            -f) shift; forwarding_interface=$1;;
        esac
        shift
    done

    # Commands
    private_key=`wg genkey`
    public_key=`echo "$private_key" | wg pubkey`
    echo "Server public Key: $public_key"

    check_run "ufw allow $port/udp && sudo ufw enable"

    check_run "printf \"[Interface]\nAddress = ${address}\nListenPort = ${port}\nPrivateKey = ${private_key}\n\" > /etc/wireguard/${interface_name}.conf" "printf \"[Interface]\"... > /etc/wireguard/${interface_name}.conf"
    unset -v private_key

    if [ "$forwarding_interface" != "false" ]; then
        check_run "sysctl -w net.ipv4.ip_forward=1"
        check_run "printf \"PostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${forwarding_interface} -j MASQUERADE\nPostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${forwarding_interface} -j MASQUERADE\n\" >> /etc/wireguard/${interface_name}.conf" "printf \"PostUp\"... >> /etc/wireguard/${interface_name}.conf"
    fi

    check_run "wg-quick up ${interface_name}"
}
enable-forwarding(){
    # Mandatory args
    if [ ! $# -ge 2 ] || [[ "$1" == "-"* ]] || [[ "$2" == "-"* ]] ; then
        help=true
        return
    fi
    interface_name=$1
    forwarding_interface=$2

    file=""
    forwarded=false

    while read line; do
        if [ "$line" != "" ]; then
            if [[ "$line" != "[Interface]"* ]]; then
                file="${file}${line}\n"
            fi
            if [[ "$line" == *"PostUp"* ]] || [[ "$line" == *"PostDown"* ]]; then
                forwarded=true
            fi
        fi
    done < /etc/wireguard/${interface_name}.conf;

    if [ $forwarded == "true" ]; then
        echo "Traffic forwarding could already be enabled (PostUp/Down exists)"
        return
    fi

    file="[Interface]\nPostUp = iptables -A FORWARD -i %i -j ACCEPT; iptables -A FORWARD -o %i -j ACCEPT; iptables -t nat -A POSTROUTING -o ${forwarding_interface} -j MASQUERADE\nPostDown = iptables -D FORWARD -i %i -j ACCEPT; iptables -D FORWARD -o %i -j ACCEPT; iptables -t nat -D POSTROUTING -o ${forwarding_interface} -j MASQUERADE\n"${file}
    echo "Adding PostUp and Post down rules to ${interface_name}.config"
    printf "$file" > /etc/wireguard/${interface_name}.conf
    echo "Allowing traffic forwarding at system level"
    sysctl -w net.ipv4.ip_forward=1
}
disable-forwarding(){
    # Mandatory args
    if [ ! $# -ge 1 ] || [[ "$1" == "-"* ]] ; then
        help=true
        return
    fi
    interface_name=$1

    file=""
    forwarded=false

    while read line; do
        if [ "$line" != "" ]; then
            if [[ "$line" == *"PostUp"* ]] || [[ "$line" == *"PostDown"* ]]; then
                forwarded=true
            else
                file="${file}${line}\n"
            fi
        fi
    done < /etc/wireguard/${interface_name}.conf;

    if [ $forwarded == "true" ]; then
        printf "$file" > /etc/wireguard/${interface_name}.conf
        echo "Removed PostUp and Post down rules from ${interface_name}.config"
    else
        echo "Could not find redirection rules in the config file"
    fi
    echo "If you wish to disable traffic forwarding at system level (for all interfaces) execute: sudo sysctl -w net.ipv4.ip_forward=0"
}
remove(){
    # Mandatory args
    if [ ! $# -ge 1 ] || [[ "$1" == "-"* ]] ; then
        help=true
        return
    fi
    interface_name=$1
    read -p "Confirm by retyping the interface name: " confirmation
    if [ "$confirmation" != "$interface_name" ]; then echo "Aborted." && return; fi

    check_run "wg-quick down ${interface_name}"
    check_run "rm /etc/wireguard/${interface_name}.conf"
    echo "To completely remove the VPN configuration please close the port by removing the UFW rule: 'ufw status' && 'ufw delete RULE'"
}
peer-new(){
    echo "Not implemented"
}
peer-enable(){
    echo "Not implemented"
}
peer-disable(){
    echo "Not implemented"
}
peer-remove(){
    echo "Not implemented"
}


while [ $# -gt 0 ] && [ "$syntax" == "false" ] ; do
    case "$1" in
        # OPTIONS
        -h|--help) help=true ;;
        -v|--visualize) visualize=true; echo "~Visualize mode~" ;;
        # COMMANDS
        reminder)
            syntax="reminder"
            if [ $help != "true" ]; then shift; reminder $*; fi
        ;;
        show)
            syntax="show [<interface-name>]"
            if [ $help != "true" ]; then shift; show $*; fi
        ;;
        new)
            syntax="new {<interface-name>} [-a <address>] [-p <port>] [-f <forwarding-interface>]"
            if [ "$help" != "true" ] ; then shift; new $*; fi # if help needed, don't execute
        ;;
        enable-forwarding)
            syntax="enable-forwarding {<interface-name>} {<forwarding-interface>}"
            if [ $help != "true" ]; then shift; enable-forwarding $*; fi
        ;;
        disable-forwarding)
            syntax="disable-forwarding {<interface-name>}"
            if [ $help != "true" ]; then shift; disable-forwarding $*; fi
        ;;
        remove)
            syntax="remove {<interface-name>}"
            if [ $help != "true" ]; then shift; remove $*; fi
        ;;
        peer-new)
            syntax="peer-new {<interface-name>} {-f <public key file> | -k <public key>} {-i <peer-ip>} [-n <name or identifier>]"
            if [ $help != "true" ]; then shift; peer-new $*; fi
        ;;
        peer-enable)
            syntax="peer-enable {<interface-name>} {-i <peer-ip> | -n <name or identifier>}"
            if [ $help != "true" ]; then shift; peer-enable $*; fi
        ;;
        peer-disable)
            syntax="peer-disable {<interface-name>} {-i <peer-ip> | -n <name or identifier>}"
            if [ $help != "true" ]; then shift; peer-disable $*; fi
        ;;
        peer-remove)
            syntax="peer-remove {<interface-name>} {-i <peer-ip> | -n <name or identifier>}"
            if [ $help != "true" ]; then shift; peer-remove $*; fi
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
    echo "Syntax: bash wireguard_server.sh [options] <command> <arguments> [optional arguments]";

fi
