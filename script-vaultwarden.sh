#!/usr/bin/bash

# USO: bash ssh-vaultwarden.ssh <archivo-input>.csv
#
# Este script recibe un archivo csv como parámetro y
# retorna otro archivo csv de fortmato vaultwarden
#
# El archivo-input debe estar en el formato:
# ip-host,descripcion-corta,usuario,contraseña
#
# Intenta la conexión uno por uno a la lista de direcciones
# IP del archivo input y toma en cuenta los siguientes casos
#
# - OK:
#       ssh te pide la contraseña y logra la conexión,
#       añadiendo esta máquina al output.
# - No route to host:
#       ssh no encuentra ruta a la máquina destino,
#       se asume apagada y se omite del output
# - timed out:
#       La conexión tarda mucho y ssh la cierra, se añade
#       al output con una nota.
# - refused:
#       la máquina destino rechaza la conexión por algun motivo,
#       se asume encendida y se añade al output con la nota
# - *:
#       en caso de obtener otro error se pide ingresar un mensaeje
#       por stdin, se añade la máquina al output con el mensaje
#       ingresado.

RED='\033[0;31m'
GRN='\033[0;32m'
YLW='\033[1;33m'
NC='\033[0m'

file="$1"

count=0

echo "collections,type,name,notes,fields,reprompt,login_uri,login_username,login_password,login_totp" > output.csv

while read -r line; do
    count=$((count + 1))

    host=$(echo $line | cut -d ',' -f 1)
    dominio=$(echo $line | cut -d ',' -f 2)
    user=$(echo $line | cut -d ',' -f 3)
    pass=$(echo $line | cut -d ',' -f 4)

    if [[ $user = "" ]]; then
        user="root"
    fi

    echo "-[$count]-----------------------------------------------"
    echo -e "Intentando Conexión a ${GRN}$host${NC}"

    resul=""
    resul=$(ssh -n -o ConnectTimeout=5 $user@$host echo "OK" 2> >(tee /dev/stderr))

    case "$resul" in
        *OK*)
            echo "$user@$host: ok"
            echo ",login,$host $dominio,,,0,,$user,$pass," >> output.csv
            continue
            ;;
        *No\ route\ to\ host*)
            echo -e "${RED}$host: Fallida${NC}"
            continue
            ;;
        *timed\ out*)
            echo -e "${YWL}$user@$host: ok (timed out)${NC}"
            echo ",login,$host $dominio (timed out),,,0,,$user,$pass," >> output.csv

            continue
            ;;
        *refused*)
            echo "$user@$host: ok (refused)"
            echo ",login,$host $dominio (refused),,,0,,$user,$pass," >> output.csv

            continue
            ;;
        *)
            echo "$user@$host: ok (otro error)"
            read -r -p "Causa del Error: " input_error < /dev/tty
            echo ",login,$host $dominio ($input_error),,,0,,$user,$pass," >> output.csv

            continue
            ;;
    esac
done < "$file"

echo ""
echo -e "Generado Archivo: ${GRN}output.csv${NC}"
echo ""
