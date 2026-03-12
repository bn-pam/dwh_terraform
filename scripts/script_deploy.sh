#!/bin/bash

# 1. On récupère le chemin absolu du dossier où se trouve ce script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

# 2. On pointe vers la racine (un dossier au-dessus du script)
# Si ton script est dans ./scripts, alors $SCRIPT_DIR/.. est la racine
ROOT_DIR="$SCRIPT_DIR/.."

# 3. On charge le .env depuis la racine
if [ -f "$ROOT_DIR/.env" ]; then
    export $(grep -v '^#' "$ROOT_DIR/.env" | xargs)
    echo "✅ Variables du .env chargées depuis la racine."
else
    echo "❌ Erreur : Fichier .env introuvable à l'adresse $ROOT_DIR/.env"
    exit 1
fi

# 4. On ajuste le chemin des SQL pour qu'ils soient aussi relatifs à la racine
SCRIPTS_DIR="$ROOT_DIR/schema_vues_procedures"

SERVER="sql-server-${USER_NAME}.database.windows.net"

echo "-------------------------------------------------------"
echo "🚀 Démarrage du déploiement SQL"
echo "Serveur : $SERVER"
echo "Utilisateur : $DB_USER"
echo "-------------------------------------------------------"

# 2. Liste des scripts à exécuter dans l'ordre
SCRIPTS_DIR="scripts" # Dossier où sont les scripts
FILES=(
    "dwh_schema_init.sql"
    "procedures_stockees/sp_clean_data_quarantine.sql"
    "procedures_stockees/sp_PurgeRGPD_daily.sql"
    "procedures_stockees/sp_PurgeCustomerDataRGPD.sql"
    "procedures_stockees/sp_quarantine_status.sql"
    "procedures_stockees/trg_SCD2_Seller.sql"
    "procedures_stockees/trg_LinkSellerKey.sql"
    "sp_GenerateAllSellerViews.sql"
    "dashboard_sql_kpi_mco.sql"
    "demo_exec.sql"
    "rattrapage_seller_key.sql"
    "policy_access/user_creation.sql"
)

# 3. Boucle d'exécution
for FILE in "${FILES[@]}"
do
    echo "📄 Exécution de : $FILE ..."

    # Utilisation de sqlcmd (outil standard Azure/SQL)
    # -S (Server), -d (Database), -U (User), -P (Password), -i (Input file)
    sqlcmd -S "$SERVER" -d "$DB_NAME" -U "$DB_USER" -P "$DB_PASSWORD" -i "$SCRIPTS_DIR/$FILE"

    if [ $? -eq 0 ]; then
        echo "✅ Succès."
    else
        echo "❌ Erreur lors de l'exécution de $FILE"
        exit 1
    fi
done

echo "-------------------------------------------------------"
echo "🎉 Tous les scripts ont été déployés avec succès !"
echo "-------------------------------------------------------"