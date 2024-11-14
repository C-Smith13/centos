# Inicialización de variables
param (
    [string]$IpDestino,
    [string]$Archivo
)

$user = "cloud-user"  # Definir usuario para la conexión SFTP
$rutaPrivKey = "C:\Users\Administrator\Desktop\clave\Win1"  # Ruta a la clave privada
$rutaPubKey = "C:\Users\Administrator\Desktop\clave\Win1.pem"   # Ruta a la clave pública
$rutaDestino = "/home/cloud-user/envios"          # Ruta en el servidor remoto

# Validación de argumentos
if (-not $IpDestino -or -not $Archivo) {
    Write-Host "Uso: .\script.ps1 --IpDestino <direccion_ip> --Archivo <ruta_archivo>"
    exit 1
}

# Obtención del directorio y nombre del archivo sin extensión
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($Archivo)
$directory = [System.IO.Path]::GetDirectoryName($Archivo)

# --- 1. Codificacion en Base64 ---
$base64File = "$directory\$baseName.b64"
write-host "Codificando archivo en Base64..."
certutil -encode "$Archivo" "$base64File"

# --- 2. Cifrado con OpenSSL (creando clave publica y privada) ---
write-host "Generando claves publica y privada con OpenSSL..."
openssl genpkey -algorithm RSA -out "$rutaPrivKey" -pkeyopt rsa_keygen_bits:2048
openssl rsa -pubout -in "$rutaPrivKey" -out "$directory\public_key.pem"
write-host "Claves generadas y almacenadas."

$encFile = "$directory\$baseName.enc"
write-host "Cifrando archivo con la clave publica..." 
openssl pkeyutl -encrypt -inkey "$directory\public_key.pem" -pubin -in "$Archivo" -out "$encFile"
write-host "Archivo cifrado con clave publica."

# --- 3. Hash MD5 del archivo original ---
$hashFile = "$directory\$baseName.hash"
write-host "Calculando hash MD5 del archivo original..."
certutil -hashfile "$Archivo" MD5 > "$hashFile"
write-host "Hash MD5 calculado y guardado."

#--- 4. Comprimir el archivo como .zip ---
$zipFile = "$directory\$baseName.zip"
write-host "Comprimiendo archivo en formato ZIP..."
Compress-Archive -Path "$encFile", "$hashFile", "$base64File" -DestinationPath "$zipFile"
write-host "Archivo comprimido como ZIP."

# --- 5. Enviar archivo a través de SCP ---
write-host "Enviando archivo comprimido a traves de SCP..."
scp -i "C:\Users\froja\.ssh\id_rsa" "$zipFile" $user@$IpDestino:"$rutaDestino/"
write-host "Archivo enviado con exito."
