#!/usr/bin/env bash
cat > ${client_config} <<EOF && chmod 600 ${client_config}
[Interface]
Address = ${client_wg_ip}/${cidr}
PrivateKey = $(head -1 ${client_private_key})
DNS = $(echo ${client_dns_ips} | sed -E 's/ +/, /g')
[Peer]
PublicKey = $(head -1 ${server_public_key})
PresharedKey = $(head -1 ${preshared_key})
AllowedIPs = $(echo ${client_allowed_ips} | sed -E 's/ +/, /g')
Endpoint = ${server_public_ip}:${server_port}
PersistentKeepalive = 25
EOF

  cat >> ${server_config} <<EOF
### ${client_name} - START
[Peer]
# friendly_name = ${client_name}
PublicKey = $(head -1 ${client_public_key})
PresharedKey = $(head -1 ${preshared_key})
AllowedIPs = ${client_wg_ip}/32
### ${client_name} - END
EOF
