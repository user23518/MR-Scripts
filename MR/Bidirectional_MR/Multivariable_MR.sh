#!/bin/bash
#SBATCH --time=48:00:00
#SBATCH --mem=80G
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --output=/network/iss/debette/users/marine.huang/MR/logs/mvmr_cSVD_%j.out
#SBATCH --error=/network/iss/debette/users/marine.huang/MR/logs/mvmr_cSVD_%j.err
#SBATCH --job-name=MVMR_cSVD

set -euo pipefail

# ── Fonction : ajoute horodatage à chaque ligne ───────────────────────────────
timestamp() {
  awk '{ print strftime("[%Y-%m-%d %H:%M:%S]", systime()), $0; fflush() }'
}

module load R/4.5.0
export R_LIBS_USER=/network/iss/home/marine.huang/rLIBS
export http_proxy=http://proxy-icm:3128
export https_proxy=http://proxy-icm:3128
export TMPDIR=/network/iss/debette/users/marine.huang/MR/tmp
mkdir -p $TMPDIR

SCRIPT_DIR="/network/iss/debette/users/marine.huang/MR/Bidirectional_MR"
RSCRIPT="/network/iss/home/marine.huang/.conda/envs/my_r_env/bin/Rscript"
R_SCRIPT="${SCRIPT_DIR}/Multivariable_MR.R"
OUTDIR="/network/iss/debette/users/marine.huang/MR/results/MVMR_HTN_adjusted"

mkdir -p "${OUTDIR}"

if [ ! -f "${R_SCRIPT}" ]; then
    echo "ERROR: R script not found: ${R_SCRIPT}" | timestamp
    exit 1
fi

if [ ! -f "${RSCRIPT}" ]; then
    echo "ERROR: Rscript binary not found: ${RSCRIPT}" | timestamp
    exit 1
fi

{
  echo "=========================================="
  echo "Job ID    : $SLURM_JOB_ID"
  echo "Node      : $(hostname)"
  echo "Start     : $(date)"
  echo "R script  : ${R_SCRIPT}"
  echo "Output    : ${OUTDIR}"
  echo "Rscript   : ${RSCRIPT}"
  echo "Analysis  : Multivariable MR (MVMR)"
  echo "=========================================="
} | timestamp

# ── Lancer R avec horodatage sur stdout ET stderr ─────────────────────────────
"${RSCRIPT}" "${R_SCRIPT}" 2>&1 | timestamp

EXIT_CODE=${PIPESTATUS[0]}

{
  echo "=========================================="
  echo "End       : $(date)"
  echo "Exit code : ${EXIT_CODE}"
  echo "=========================================="
} | timestamp

# ── Lister les fichiers produits ──────────────────────────────────────────────
if [ ${EXIT_CODE} -eq 0 ]; then
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] Fichiers produits dans ${OUTDIR} :"
  ls -lh "${OUTDIR}"/*.tsv "${OUTDIR}"/*.xlsx 2>/dev/null \
    | awk '{ print strftime("[%Y-%m-%d %H:%M:%S]", systime()), $0; fflush() }' \
    || echo "[$(date '+%Y-%m-%d %H:%M:%S')] (aucun fichier .tsv/.xlsx trouvé)"
else
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERREUR : exit code ${EXIT_CODE}"
fi

exit ${EXIT_CODE}