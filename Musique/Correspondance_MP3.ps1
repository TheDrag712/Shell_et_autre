# Définir le chemin du fichier de sortie pour le LOG des renommages (facultatif mais recommandé)
$LogFile = Join-Path (Split-Path $MyInvocation.MyCommand.Path) "log_renommage_mp3.txt"

# Demander à l'utilisateur le chemin du dossier MP3
$MP3Folder = Read-Host "Veuillez entrer le chemin complet du dossier contenant vos fichiers MP3"

# Vérifier si le dossier existe
If (-not (Test-Path $MP3Folder -PathType Container)) {
    Write-Error "Le dossier spécifié n'existe pas ou n'est pas un dossier valide."
    Break
}

# Initialiser le tableau pour stocker les informations de renommage (pour le log)
$renamedFilesLog = @()

# Obtenir tous les fichiers MP3 dans le dossier
$mp3Files = Get-ChildItem -Path $MP3Folder -Filter "*.mp3" -File

If ($mp3Files.Count -eq 0) {
    Write-Host "Aucun fichier MP3 trouvé dans le dossier spécifié."
    Exit
}

Write-Host "Traitement de $($mp3Files.Count) fichiers MP3 pour renommage..."

# Créer un objet Shell.Application pour accéder aux propriétés des fichiers
$shell = New-Object -ComObject Shell.Application
$folder = $shell.NameSpace($MP3Folder)

# Initialiser les variables pour la barre de progression
$i = 0
$totalFiles = $mp3Files.Count
$skippedCount = 0 # Compteur pour les fichiers ignorés
$renamedCount = 0 # Compteur pour les fichiers renommés

# Parcourir chaque fichier MP3 avec une barre de progression
ForEach ($file in $mp3Files) {
    $i++
    $progressPercentage = ($i / $totalFiles) * 100

    # Mettre à jour la barre de progression
    Write-Progress -Activity "Renommage des fichiers MP3" `
                   -Status "Traitement de $($file.Name)" `
                   -CurrentOperation "Fichiers traités: $i sur $totalFiles (Renommés: $renamedCount, Ignorés: $skippedCount)" `
                   -PercentComplete $progressPercentage

    $fileItem = $folder.ParseName($file.Name)

    # Indices des propriétés : 20 pour l'artiste, 21 pour le titre
    # Attention : Ces indices peuvent varier légèrement selon la version de Windows
    $artist = $folder.GetDetailsOf($fileItem, 20) # Artiste
    $title = $folder.GetDetailsOf($fileItem, 21)  # Titre de la chanson

    If ([string]::IsNullOrEmpty($artist) -or [string]::IsNullOrEmpty($title)) {
        Write-Host "   Fichier ignoré (métadonnées manquantes) : $($file.Name)" -ForegroundColor Yellow
        $skippedCount++
        # Ajouter au log si nécessaire
        $renamedFilesLog += [PSCustomObject]@{
            OriginalFileName = $file.Name
            Status           = "Ignoré - Métadonnées manquantes"
            NewFileName      = ""
            Timestamp        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        Continue # Passe au fichier suivant dans la boucle
    }

    # Nettoyer les noms pour éviter les caractères invalides dans les noms de fichiers
    $cleanedArtist = $artist -replace '[\\/:*?"<>|]', '_'
    $cleanedTitle = $title -replace '[\\/:*?"<>|]', '_'

    # Construire le nouveau nom de fichier
    $newFileName = "$cleanedArtist - $cleanedTitle.mp3"

    # --- MODIFICATION PRINCIPALE : Renommer le fichier ---
    Try {
        # Vérifier si le nouveau nom de fichier est différent de l'ancien
        If ($file.Name -ne $newFileName) {
            # Construire le chemin complet pour le nouveau nom
            $newFilePath = Join-Path -Path $file.DirectoryName -ChildPath $newFileName

            # Vérifier si un fichier avec le nouveau nom existe déjà pour éviter les erreurs
            If (Test-Path $newFilePath) {
                Write-Warning "   ATTENTION: Un fichier nommé '$newFileName' existe déjà. Fichier '$($file.Name)' non renommé pour éviter l'écrasement."
                $renamedFilesLog += [PSCustomObject]@{
                    OriginalFileName = $file.Name
                    Status           = "Ignoré - Conflit de nom (le nouveau nom existe déjà)"
                    NewFileName      = $newFileName
                    Timestamp        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
                $skippedCount++ # Compter comme ignoré pour cette raison
            } Else {
                Rename-Item -Path $file.FullName -NewName $newFileName -ErrorAction Stop
                Write-Host "   Fichier renommé : '$($file.Name)' -> '$newFileName'" -ForegroundColor Green
                $renamedCount++
                $renamedFilesLog += [PSCustomObject]@{
                    OriginalFileName = $file.Name
                    Status           = "Renommé"
                    NewFileName      = $newFileName
                    Timestamp        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
                }
            }
        } Else {
            Write-Host "   Fichier '$($file.Name)' a déjà le bon nom, pas de renommage nécessaire." -ForegroundColor Cyan
            $renamedFilesLog += [PSCustomObject]@{
                OriginalFileName = $file.Name
                Status           = "Aucun changement nécessaire"
                NewFileName      = $file.Name # ou $newFileName, c'est le même
                Timestamp        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            }
        }
    } Catch {
        Write-Error "   ERREUR lors du renommage de $($file.Name): $($_.Exception.Message)"
        $renamedFilesLog += [PSCustomObject]@{
            OriginalFileName = $file.Name
            Status           = "Erreur de renommage: $($_.Exception.Message)"
            NewFileName      = $newFileName
            Timestamp        = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $skippedCount++ # Compter comme ignoré en cas d'erreur
    }
    # --- FIN DE LA MODIFICATION ---
}

# Nettoyer la barre de progression une fois terminé
Write-Progress -Activity "Renommage des fichiers MP3" -Completed

# Écrire les informations de renommage dans le fichier log
If ($renamedFilesLog.Count -gt 0) {
    $renamedFilesLog | Format-Table -AutoSize | Out-File -FilePath $LogFile -Encoding UTF8
    Write-Host "Un log détaillé des opérations a été enregistré dans : $LogFile"
} Else {
    Write-Host "Aucune opération de renommage n'a été tentée (probablement aucun fichier MP3 trouvé ou tous ignorés)."
}

Write-Host "-----------------------------------------------------"
Write-Host "Résumé du traitement :"
Write-Host "Total des fichiers analysés : $totalFiles"
Write-Host "Fichiers renommés avec succès : $renamedCount"
Write-Host "Fichiers ignorés (métadonnées manquantes, conflit de nom, ou erreur) : $skippedCount"
Write-Host "Fichiers déjà correctement nommés : $($totalFiles - $renamedCount - $skippedCount)"
Write-Host "Le script a terminé son exécution."