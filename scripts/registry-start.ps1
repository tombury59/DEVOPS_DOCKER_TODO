# Script PowerShell pour démarrer/créer le container `registry`
# Usage: powershell -ExecutionPolicy Bypass -File .\scripts\registry-start.ps1

# Vérifier si un container nommé 'registry' est en cours d'exécution
$running = docker ps --filter "name=registry" -q 2>$null
if ($running -and $running.Trim() -ne "") {
    Write-Output "Registry déjà en cours d'exécution (container id: $running)."
    exit 0
}

# Vérifier si un container nommé 'registry' existe mais est arrêté
$exists = docker ps -a --filter "name=registry" -q 2>$null
if ($exists -and $exists.Trim() -ne "") {
    Write-Output "Registry présent mais arrêté (container id: $exists) — démarrage..."
    docker start registry | Write-Output
    exit $LASTEXITCODE
}

# Sinon, créer le service via docker compose
Write-Output "Aucun container registry trouvé — création via 'docker compose up -d registry'..."
# Exécuter docker compose up -d registry dans le répertoire courant
docker compose up -d registry | Write-Output
exit $LASTEXITCODE
