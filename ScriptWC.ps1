# Inicialización de variables
param (
    [string]$IpDestino,
    [string]$Archivo
)

$user = "cloud-user"  # Definir usuario para la conexión SFTP
$rutaPrivKey = "C:\Users\Administrator\Desktop\clave\private_key.pem"  # Ruta a la clave privada
$rutaPubKey = "C:\Users\Administrator\Desktop\clave\public_key.pem"   # Ruta a la clave pública
$rutaDestino = "/home/cloud-user/envios"          # Ruta en el servidor remoto

# Validación de argumentos
if (-not $IpDestino -or -not $Archivo) {
    Write-Host "Uso: .\script.ps1 --IpDestino <direccion_ip> --Archivo <ruta_archivo>"
    exit 1
}

# Verificar si el archivo existe
if (-not (Test-Path $Archivo)) {
    Write-Host "Archivo no encontrado: $Archivo"
    exit 1
}

# Obtención del directorio y nombre del archivo sin extensión
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($Archivo)
$directory = [System.IO.Path]::GetDirectoryName($Archivo)

# --- 1. Codificación en Base64 ---
$base64File = "$directory\$baseName.b64"
write-host "Codificando archivo en Base64..."
if (Test-Path $base64File) {
    Remove-Item $base64File -Force
}
certutil -encode "$Archivo" "$base64File"

# --- 2. Cifrado con OpenSSL usando claves existentes ---
$encFile = "$directory\$baseName.enc"
write-host "Cifrando archivo con la clave pública existente..."
if (Test-Path $encFile) {
    Remove-Item $encFile -Force
}

# Asegúrate de que OpenSSL esté instalado y agregado al PATH del sistema
# Si OpenSSL no está en el PATH, especifica la ruta completa a openssl.exe
$opensslPath = "C:\Program Files\OpenSSL-Win64\bin\openssl.exe"

& "$opensslPath" pkeyutl -encrypt -inkey "$rutaPubKey" -pubin -in "$Archivo" -out "$encFile"
write-host "Archivo cifrado con clave pública."

# --- 3. Hash MD5 del archivo original ---
$hashFile = "$directory\$baseName.hash"
write-host "Calculando hash MD5 del archivo original..."
if (Test-Path $hashFile) {
    Remove-Item $hashFile -Force
}
certutil -hashfile "$Archivo" MD5 > "$hashFile"
write-host "Hash MD5 calculado y guardado."

#--- 4. Comprimir el archivo como .zip ---
$zipFile = "$directory\$baseName.zip"
write-host "Comprimiendo archivo en formato ZIP..."
if ((Test-Path $encFile) -and (Test-Path $hashFile) -and (Test-Path $base64File)) {
    if (Test-Path $zipFile) {
        Remove-Item $zipFile -Force
    }
    Compress-Archive -Path "$encFile", "$hashFile", "$base64File" -DestinationPath "$zipFile"
    write-host "Archivo comprimido como ZIP."
} else {
    Write-Host "Uno o más archivos no encontrados para la compresión."
    exit 1
}

# --- 5. Enviar archivo a través de SCP ---
write-host "Enviando archivo comprimido a través de SCP..."
scp -i "$rutaPrivKey" "$zipFile" ${user}@${IpDestino}:"$rutaDestino/"
write-host "Archivo enviado con éxito."

# --- 6. Eliminar archivos temporales ---
write-host "Eliminando archivos temporales..."
Remove-Item "$base64File", "$encFile", "$hashFile", "$zipFile" -Force -ErrorAction SilentlyContinue
write-host "Archivos temporales eliminados."
