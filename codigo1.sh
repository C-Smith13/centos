#!/bin/bash

# Inicialización de variables
IpDestino=""
Archivo=""

# Procesamiento de argumentos
while [[ $# -gt 0 ]]; do
    case $1 in
        --ip)
            IpDestino="$2"
            shift 2
            ;;
        --archivo)
            Archivo="$2"
            shift 2
            ;;
        *)
            echo "Uso: $0 --ip <direccion_ip> --archivo <ruta_archivo>"
            exit 1
            ;;
    esac
done

#Selector de clave publica
case "$direccion_ip" in
    "192.168.1.103")
        PubKEY="C:\user\Administrator\Desktop\claves\private_key_centos1.pem"
        ;;
    "192.168.5.101")
        PubKEY="C:\user\Administrator\Desktop\claves\private_key_centos2.pem"
        ;;
    *)
        echo "Dirección IP no reconocida."
        exit 1
        ;;
esac


#clave privada
rutaPrivKey="C:\user\Administrator\Desktop\claves\private_key_W1.pem"

#RutaArchivoTemporal
rutaATemp="C:\user\Administrator\Desktop\temporal\cifrado"

#codificacion base64
echo "Codificando archivo en Base64"
base64 "${Archivo}" > "${Archivo}.b64"
echo "base64 terminado"

#cifrado openssl
echo "Cifrado archivo en openssl"
openssl rsautl -encrypt -inkey "$rutaPrivKey" -pubin -in "${Archivo}.b64" -out "${Archivo}.b64.enc"
echo "openssl terminado"

#compreseion zip
echo "Compresion zip"
zip "${archivo}.b64.enc.zip" "${archivo}.b64.enc"
echo "zip terminado"

#calculo de hash
md5_hash=$(openssl md5 "${archivo}.b64.enc" | cut -d " " -f 2)
echo "MD5 hash del archivo cifrado: ${md5_hash}"


# Enviar el archivo usando SFTP con clave privada
ruta_destino="/home/cloud-user/envios"    
sftp -i "$rutaPrivKey" "$cloud_user@$IpDestino" <<EOF
put "${archivo}.b64.enc" "$ruta_destino/"
bye
EOF

echo "Archivo enviado exitosamente a $ruta_destino."

