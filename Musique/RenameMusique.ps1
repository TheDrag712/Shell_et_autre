# Chemin du répertoire
$repertoire = Read-Host "Veuillez entrer le chemin complet du répertoire contenant les fichiers musicaux à renommer : "

# Remplacements
$remplacements = @{
    "_" = " ";
    "(clip officiel)" = "";
    "[Clip Officiel]" = "";
    "(album version)" = "";
    "[album version]" = "";
    "(Instrumental)" = "";
    "[Instrumental]" = "";
    "(Radio Edit)" = "";
    "[Radio Edit]" = "";
    "(live)" = "";
    "[live]" = "";
    "(Acoustic)" = "";
    "[Acoustic]" = "";
    "(Original Version)" = "";
    "[Original Version]" = "";
    "(Inédit)" = "";
    "[Inédit]" = "";
    "(lyrics video)" = "";
    "[lyrics video]" = "";
    "(audio)" = "";
    "[audio]" = "";
    "(explicit)" = "";
    "[explicit]" = "";
    "(Version Longue)" = "";
    "[Version Longue]" = "";
    "(complete album)" = "";
    "(Lyric Video)" = "";
    "(feat." = "(feat."; # Exemple: garder "(feat." mais s'assurer qu'il n'est pas supprimé si une règle plus générique existe
    ")" = ")"; # S'assurer que les parenthèses fermantes ne sont pas supprimées accidentellement
    "(" = "(";
    "[" = "[";
    "]" = "]"
}

# Ajouter des remplacements
$ajouterRemplacements = Read-Host "Souhaitez-vous ajouter d'autres valeurs à remplacer (oui/non) ? "

while ($ajouterRemplacements -ceq "oui") {
    $valeurARemplacer = Read-Host "Veuillez entrer la valeur à remplacer (ex: 'remastered', 'version longue', 'prise alternative', ou 'feat. Artiste') : "
    $valeurDeRemplacement = Read-Host "Veuillez entrer la valeur de remplacement (laisser vide pour supprimer la valeur) : "
    $remplacements[$valeurARemplacer] = $valeurDeRemplacement
    $ajouterRemplacements = Read-Host "Souhaitez-vous ajouter d'autres valeurs à remplacer (oui/non) ? "
}

# Afficher les remplacements
Write-Host "Les remplacements suivants seront effectués : "
$remplacements.GetEnumerator() | ForEach-Object {
    Write-Host "`"$($_.Key)`" sera remplacé par `"$($_.Value)`""
}

# Renommer les fichiers
$fichiers = Get-ChildItem -Path $repertoire -File
$totalFichiers = $fichiers.Count
$i = 0

foreach ($fichier in $fichiers) {
    $i++
    $nouveauNom = $fichier.BaseName

    foreach ($cle in $remplacements.Keys) {
        $valeur = $remplacements[$cle]
        # Utilisation de -replace avec l'option insensible à la casse (?i) et l'échappement des caractères spéciaux
        $nouveauNom = $nouveauNom -replace "(?i)$([regex]::Escape($cle))", $valeur
    }

    # Supprimer les espaces multiples consécutifs et les espaces en début/fin de chaîne
    $nouveauNom = ($nouveauNom.Split(' ') | Where-Object { $_ }) -join ' '
    $nouveauNomComplet = "$nouveauNom$($fichier.Extension)"

    # --- DÉBUT DE LA LOGIQUE DE GESTION DES DOUBLONS AMÉLIORÉE ---
    $compteur = 1
    $nomBaseSansExtension = $nouveauNom # Conserve le nom de base sans extension pour ajouter le suffixe
    $cheminCiblePropose = Join-Path -Path $repertoire -ChildPath $nouveauNomComplet

    # Boucle tant que le chemin cible proposé existe ET qu'il ne s'agit PAS du fichier original
    while (Test-Path -Path $cheminCiblePropose -PathType Leaf) {
        # Vérifie si le fichier existant à ce chemin est le même que le fichier en cours de traitement
        if ((Get-Item -Path $cheminCiblePropose).FullName -eq $fichier.FullName) {
            # Si c'est le même fichier, cela signifie qu'il est déjà dans l'état désiré ou qu'il se renommerait lui-même.
            # Pas besoin d'ajouter de suffixe, on sort de la boucle.
            break
        }
        # Si c'est un fichier différent avec le même nom proposé, ajoute un suffixe numérique
        $nouveauNomComplet = "$nomBaseSansExtension ($compteur)$($fichier.Extension)"
        $cheminCiblePropose = Join-Path -Path $repertoire -ChildPath $nouveauNomComplet
        $compteur++
    }
    # --- FIN DE LA LOGIQUE DE GESTION DES DOUBLONS AMÉLIORÉE ---

    if ($nouveauNomComplet -ne $fichier.Name) {
        try {
            Rename-Item -Path $fichier.FullName -NewName $nouveauNomComplet -ErrorAction Stop # Utilise -ErrorAction Stop pour mieux gérer les erreurs
            Write-Progress -Activity "Renommage des fichiers" -Status "Traitement du fichier : '$($fichier.Name)' vers '$nouveauNomComplet' ($i/$totalFichiers)" -PercentComplete (($i / $totalFichiers) * 100)
        } catch {
            Write-Error "Erreur lors du renommage du fichier '$($fichier.Name)': $($_.Exception.Message). Le fichier n'a pas été renommé et reste sous son nom d'origine."
        }
    } else {
        Write-Progress -Activity "Renommage des fichiers" -Status "Le nom du fichier '$($fichier.Name)' est déjà conforme ou inchangé ($i/$totalFichiers)" -PercentComplete (($i / $totalFichiers) * 100)
    }
}

Write-Host "Opération de renommage terminée.  $totalFichiers fichiers ont été traités."

# Sauvegarder les remplacements
$sauvegarderRemplacements = Read-Host "Souhaitez-vous sauvegarder les valeurs de remplacement définies dans le script pour une utilisation ultérieure (oui/non) ? "

if ($sauvegarderRemplacements -ceq "oui") {
    $scriptPath = $MyInvocation.MyCommand.Path
    $remplacementsString = ""
    # Génère la chaîne de remplacement pour la sauvegarde
    $remplacements.GetEnumerator() | ForEach-Object {
        $remplacementsString += "`"`$($_.Key)`" = `"$($_.Value)`";`n"
    }
    # Lit le contenu du script, trouve la section des remplacements et la met à jour
    $nouveauContenu = Get-Content $scriptPath | ForEach-Object {
        if ($_ -like '$remplacements = @{*') { # Détecte le début de la table de hachage des remplacements
            '$remplacements = @{' # Réécrit l'ouverture de la table
            $remplacementsString # Insère les nouvelles règles
            '}' # Réécrit la fermeture de la table
        } else {
            $_ # Conserve les autres lignes du script inchangées
        }
    }
    $nouveauContenu | Set-Content $scriptPath # Écrit le nouveau contenu dans le fichier script
    Write-Host "Les valeurs de remplacement ont été sauvegardées dans le script à l'emplacement : $scriptPath. Vous pourrez les réutiliser lors de la prochaine exécution du script."
} else {
    Write-Host "Les valeurs de remplacement n'ont pas été sauvegardées. Elles seront réinitialisées à la prochaine exécution."
}