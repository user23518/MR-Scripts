#!/bin/bash
#SBATCH --time=120:00:00
#SBATCH --mem=100G
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --output=/network/iss/debette/users/marine.huang/MR/logs/mr_cSVD_%j.out
#SBATCH --error=/network/iss/debette/users/marine.huang/MR/logs/mr_cSVD_%j.err
#SBATCH --job-name=MR_cSVD

set -euo pipefail

module load R/4.5.0
export R_LIBS_USER=/network/iss/home/marine.huang/rLIBS
export http_proxy=http://proxy-icm:3128
export TMPDIR=/network/iss/debette/users/marine.huang/MR/tmp
mkdir -p $TMPDIR

SCRIPT_DIR="/network/iss/debette/users/marine.huang/MR/Bidirectional_MR"
RSCRIPT="/network/iss/home/marine.huang/.conda/envs/my_r_env/bin/Rscript"
R_SCRIPT="${SCRIPT_DIR}/bidirectional_cSVD_Steigerfilter.R"  
OUTDIR="/network/iss/debette/users/marine.huang/MR/results"


mkdir -p "${OUTDIR}"

if [ ! -f "${R_SCRIPT}" ]; then
    echo "ERROR: R script not found: ${R_SCRIPT}"
    exit 1
fi

echo "=========================================="
echo "Job ID    : $SLURM_JOB_ID"
echo "Node      : $(hostname)"
echo "Start     : $(date)"
echo "R script  : ${R_SCRIPT}"
echo "Output    : ${OUTDIR}"
echo "=========================================="

"${RSCRIPT}" "${R_SCRIPT}"   

echo "=========================================="
echo "End       : $(date)"
echo "=========================================="
ENDOFFILE