<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Rename Musique</title>
</head>
<body>
<?php

function renameFilesInDirectory($directory) {
    // Vérifier si le dossier existe
    if (!is_dir($directory)) {
        echo "Erreur : Le dossier spécifié n'existe pas.\n";
        return;
    }

    // Ouvrir le dossier
    if ($handle = opendir($directory)) {
        echo "Fichiers trouvés dans le dossier '$directory' :\n";
        $filesToRename = [];

        // Parcourir les fichiers du dossier
        while (false !== ($file = readdir($handle))) {
            if ($file != "." && $file != "..") {
                $filePath = $directory . DIRECTORY_SEPARATOR . $file;
                // Ne traiter que les fichiers (pas les sous-dossiers)
                if (is_file($filePath)) {
                    $filesToRename[] = $file;
                    echo "- " . $file . "\n";
                }
            }
        }
        closedir($handle);

        if (empty($filesToRename)) {
            echo "Aucun fichier à renommer dans le dossier.\n";
            return;
        }

        echo "\n--- Processus de renommage ---\n";

        foreach ($filesToRename as $oldFileName) {
            $oldFilePath = $directory . DIRECTORY_SEPARATOR . $oldFileName;

            // Demander confirmation
            echo "\nVoulez-vous renommer le fichier '" . $oldFileName . "' ? (oui/non) : ";
            $confirmation = trim(fgets(STDIN));

            if (strtolower($confirmation) === 'oui') {
                echo "Entrez le nouveau nom pour '" . $oldFileName . "' : ";
                $newFileName = trim(fgets(STDIN));

                if (!empty($newFileName)) {
                    $newFilePath = $directory . DIRECTORY_SEPARATOR . $newFileName;

                    // Renommer le fichier
                    if (rename($oldFilePath, $newFilePath)) {
                        echo "Succès : '" . $oldFileName . "' a été renommé en '" . $newFileName . "'.\n";
                    } else {
                        echo "Échec : Impossible de renommer '" . $oldFileName . "'.\n";
                    }
                } else {
                    echo "Annulé : Aucun nouveau nom fourni pour '" . $oldFileName . "'.\n";
                }
            } else {
                echo "Ignoré : Le fichier '" . $oldFileName . "' n'a pas été renommé.\n";
            }
        }
    } else {
        echo "Erreur : Impossible d'ouvrir le dossier '$directory'.\n";
    }
}

// --- Utilisation du script ---
// Définissez le chemin de votre dossier ici
$targetDirectory = __DIR__ . DIRECTORY_SEPARATOR . "Test_son"; // Exemple : un dossier nommé "mon_dossier" dans le même répertoire que le script

// Créez le dossier si il n'existe pas pour l'exemple
if (!is_dir($targetDirectory)) {
    mkdir($targetDirectory, 0777, true);
    echo "Dossier '$targetDirectory' créé pour l'exemple.\n";
    // Créez quelques fichiers pour l'exemple
    file_put_contents($targetDirectory . DIRECTORY_SEPARATOR . "fichier1.txt", "Contenu du fichier 1");
    file_put_contents($targetDirectory . DIRECTORY_SEPARATOR . "image.jpg", "Contenu de l'image");
    file_put_contents($targetDirectory . DIRECTORY_SEPARATOR . "document.pdf", "Contenu du document");
    echo "Fichiers d'exemple créés dans '$targetDirectory'.\n";
}


renameFilesInDirectory($targetDirectory);

?>

</body>
</html>