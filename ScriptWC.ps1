
Windows a Centos
# Inicialización de variables
param (
    [string]$IpDestino,
    [string]$Archivo
)

$cloud_user = "usuario"  # Definir usuario para la conexión SFTP
$rutaPrivKey = "C:\ruta\a\tu\clave_privada.ppk"  # Ruta a la clave privada
$rutaPubKey = "C:\ruta\a\tu\clave_publica.pem"   # Ruta a la clave pública
$rutaDestino = "/home/cloud-user/envios"          # Ruta en el servidor remoto

# Validación de argumentos
if (-not $IpDestino -or -not $Archivo) {
    Write-Host "Uso: .\script.ps1 --IpDestino <direccion_ip> --Archivo <ruta_archivo>"
    exit 1
}

# Codificación Base64
Write-Host "Codificando archivo en Base64..."
$base64File = "${Archivo}.b64"
[System.Convert]::ToBase64String([System.IO.File]::ReadAllBytes($Archivo)) | Out-File -Encoding ASCII $base64File
Write-Host "Base64 terminado: $base64File"

# Cifrado OpenSSL (requiere OpenSSL instalado)
Write-Host "Cifrando archivo con OpenSSL..."
$encFile = "${Archivo}.enc"
& openssl pkeyutl -encrypt -inkey $rutaPubKey -pubin -in $Archivo -out $encFile
Write-Host "OpenSSL terminado: $encFile"

# Cálculo de hash MD5
$md5_hash = Get-FileHash -Path $Archivo -Algorithm MD5 | Select-Object -ExpandProperty Hash
Write-Host "MD5 hash del archivo cifrado: $md5_hash"
$hashFile = "${Archivo}.hash"
Set-Content -Path $hashFile -Value $md5_hash

# Compresión ZIP
Write-Host "Compresión ZIP..."
$zipFile = "${Archivo}.zip"
Compress-Archive -Path @($base64File, $Archivo, $hashFile, $encFile) -DestinationPath $zipFile
Write-Host "ZIP terminado: $zipFile"

# Enviar el archivo usando SFTP con clave privada (requiere WinSCP)
Add-Type -AssemblyName WinSCPnet

$sessionOptions = New-Object WinSCP.SessionOptions -Property @{
    Protocol = [WinSCP.Protocol]::Sftp
    HostName = $IpDestino
    UserName = $cloud_user
    SshPrivateKeyPath = $rutaPrivKey
}

$session = New-Object WinSCP.Session
try {
    Write-Host "Conectando al servidor SFTP..."
    $session.Open($sessionOptions)

    Write-Host "Enviando archivo a: $rutaDestino"
    $transferOptions = New-Object WinSCP.TransferOptions
    $transferOptions.TransferMode = [WinSCP.TransferMode]::Binary

    $transferOperationResult = $session.PutFiles($zipFile, "$rutaDestino/", $False, $transferOptions)

    if ($transferOperationResult.IsSuccess) {
        Write-Host "Archivo enviado exitosamente a: $rutaDestino."
    } else {
        Write-Host "Error al enviar el archivo."
        foreach ($error in $transferOperationResult.Failures) {
            Write-Host "Error: $($error.Message)"
        }
    }
} catch {
    Write-Host "Se produjo un error: $_"
} finally {
    # Cerrar sesión
    $session.Dispose()
}