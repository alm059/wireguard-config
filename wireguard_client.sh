# Generate QR code
gen_qr() {
  local config_name="${1}"
  local output="${2}"
  local config_path="${WORKING_DIR}/client-${config_name}.conf"

  if [[ ! -f ${config_path} ]]; then
    echo -e "${RED}ERROR${NONE}: Error while generating QR code, config file ${BLUE}${config_path}${NONE} does not exist!"
    exit 1
  fi

  local options="-o ${config_path}.png"
  if [[ ${output} == "-" ]]; then
    local options="-t ANSIUTF8 -o -"
  fi

  cat ${config_path} | qrencode ${options}

  if [[ ${output} != "-" ]]; then
    chmod 600 ${config_path}.png
    echo -e "${GREEN}INFO${NONE}: QR file ${BLUE}${config_path}.png${NONE} has been generated successfully!"
  fi
}

# allow client to export pubkey to file
