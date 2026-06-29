# =============================================================================
# MVMR HTN-ADJUSTED 
# Lit les résultats univariables, charge les mêmes GWAS, fait uniquement MVMR
# =============================================================================

library(TwoSampleMR)
library(data.table)
library(dplyr)
library(ggplot2)

HAS_XLSX <- requireNamespace("openxlsx", quietly = TRUE)

proxy_url <- "http://proxy-icm:3128"
Sys.setenv(https_proxy = proxy_url)
httr::set_config(httr::use_proxy(url = proxy_url))
cat("Testing raw connection...\n")
resp <- httr::GET(
  "https://api.opengwas.io/api/status",
  httr::use_proxy(url = proxy_url),
  httr::timeout(120)
)
cat("Status code:", httr::status_code(resp), "\n")

Sys.setenv(OPENGWAS_JWT = "eyJhbGciOiJSUzI1NiIsImtpZCI6ImFwaS1qd3QiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJhcGkub3Blbmd3YXMuaW8iLCJhdWQiOiJhcGkub3Blbmd3YXMuaW8iLCJzdWIiOiJtYXJpbmUyODA2MDVAZ21haWwuY29tIiwiaWF0IjoxNzgxODcwNDY2LCJleHAiOjE3ODMwODAwNjZ9.EcIOvENBnWvBij9bz2N9SixPZq2vFaZ5tzW1S3nfnLiADlbZYeClStlT6G_Y_0M3dfPOK4Yy3RdJKNOjocUa_qt5CM25O2E0NVpXihdcyRJWZUWR0sm-62icQFls-FUkT1Ver28IHtPY0neuLiQT93_d_3WbPCpUlOBgKqRj4iKvaAp0X8sg_jU6nUP4JoDN_dFoCIXq3m_LsQfeMAfxHMy0Mis7fx7XPxFpzhL4uQVdj8V0tFeYH6u8xqcUCzU1X7VNUDFhfMUPt9XWp8Lsk-fHL4uWbb-iGtVK0XwD108i_hwSv0PF_v_i4Xv-zgKOPQJ9GQaBAQX2RgffHdfBXA")
ieugwasr::get_opengwas_jwt()
ieugwasr::user()


# ── Paths ─────────────────────────────────────────────────────────────────────
OUTDIR      <- "/network/iss/debette/users/marine.huang/MR/results"
OUTDIR_MVMR <- file.path(OUTDIR, "MVMR_HTN_adjusted")
dir.create(OUTDIR_MVMR, recursive = TRUE, showWarnings = FALSE)


# ── Traits cSVD ───────────────────────────────────────────────────────────────
csvd_traits <- list(
  list(name = "WMH Shiva",
       file = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/UKBiobank/sumstats_shiva_total_wmh_ball_dint.tsv",
       binary = FALSE, prev = NULL, n_manual = NULL),
  list(name = "WMH Bianca",
       file = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/UKBiobank/sumstats_bianca_total_wmh_ball_dint.tsv",
       binary = FALSE, prev = NULL, n_manual = NULL),
  list(name = "cerebral microbleeds",
       file = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/UKBiobank/sumstats_shiva_total_cmb_ball_bin.tsv",
       binary = TRUE, prev = 0.07, n_cases_manual = NULL, n_controls_manual = NULL),
  list(name = "Perivascular spaces",
       file = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/UKBiobank/sumstats_shiva_total_pvs_ball_iint.tsv",
       binary = FALSE, prev = NULL, n_manual = NULL)
)


# ── Expositions ───────────────────────────────────────────────────────────────
exposures <- list(
  list(name = "Alzheimer's disease (Nicolas 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/AD_nicolas2025/ad_nicolas2025_hg38.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.05, n_cases_manual = NULL, n_controls_manual = NULL, primary_role = "outcome"),
  list(name = "Parkinson's disease (Leonard 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/PD_leonard2025/GP2_euro_ancestry_meta_analysis_2024/pd_leonard2025_hg38.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.001, primary_role = "outcome", n_cases_manual = 34933, n_controls_manual = 3100),
  list(name = "Major depressive disorder (Adams 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/MDD_adams2025/mdd_adams2025_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.05, n_manual = NULL, primary_role = "outcome"),
  list(name = "Migraine (Hautakangas 2022)",
       file = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/NON_UKBiobank/migraine_hautakangas2022/without_ukb/migraine_without_ukb_hautakangas2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.14, n_cases_manual = 38094, n_controls_manual = 210211, primary_role = "exposure"),
  list(name = "Cardioembolic stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/CEstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.002, n_cases_manual = 10804, n_controls_manual = 865389, primary_role = "outcome"),
  list(name = "Large artery stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/LAAstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.002, n_cases_manual = 6399, n_controls_manual = 865389, primary_role = "outcome"),
  list(name = "Small vessel stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/SVstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.0025, n_cases_manual = 6811, n_controls_manual = 865389, primary_role = "outcome"),
  list(name = "Ischaemic stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/ISCHAEMICstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.01, n_cases_manual = 59890, n_controls_manual = 865389, primary_role = "outcome"),
  list(name = "Any stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/ANYstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.015, n_cases_manual = 70720, n_controls_manual = 865389, primary_role = "outcome"),
  list(name = "Atrial fibrillation (Yuan 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/AF_yuan2025/af_yuan2025_hg38.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.01, n_manual = NULL, primary_role = "exposure"),
  list(name = "Heart failure (Shah 2020)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/HF_shah2020/hf_shah2020_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.02, n_cases_manual = NULL, n_controls_manual = NULL, primary_role = "exposure"),
  list(name = "HTN (Verma 2024)",
       file = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/NON_UKBiobank/htn_verma2024/htn_verma2024_hg38.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.3, n_cases_manual = 320429, n_controls_manual = 107275, primary_role = "exposure"),
  list(name = "Carotid atherosclerosis / IMT (Gummesson 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/ATHERO_gummesson2025/carotid_gummesson2025_hg38.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = 26807, primary_role = "exposure"),
  list(name = "Coronary plaq (Gummesson 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/ATHERO_gummesson2025/sis_gummesson2025_hg38.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = 24811, primary_role = "exposure"),
  list(name = "Coronary artery calcification (Kavousi 2023)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/CAC_kavousi2023/cac_kavousi2023_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure"),
  list(name = "Venous thromboembolism (Thibord 2022)",
       file = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/NON_UKBiobank/VTE_thibord2022/VTE_thibord2022_hg38.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.16, n_manual = NULL, primary_role = "exposure"),
  list(name = "BMI (Locke 2015)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/BODY_giant/bmi_locke2015_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure"),
  list(name = "WHRadjBMI (Shungin 2015)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/BODY_giant/whradjBMI_shungin2015_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure"),
  list(name = "Type 2 diabetes (Mahajan 2018)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/T2DM_mahajan2018/t2dm_mahajan2018_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.10, n_cases_manual = 72209, n_controls_manual = 400308, primary_role = "exposure"),
  list(name = "Chronic kidney disease (Wuttke 2019)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/CKD_wuttke2019/CKD_wuttke2019_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.14, n_manual = NULL, primary_role = "exposure"),
  list(name = "Kidney function / eGFR (Wuttke 2019)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/CKD_wuttke2019/eGFR_wuttke2019_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure"),
  list(name = "Smoking (Liu 2019)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/HABITS_liu2019/cigpday_liu2019_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure"),
  list(name = "Alcohol consumption (Liu 2019)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/HABITS_liu2019/drinkspweek_liu2019_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure"),
  list(name = "HDL cholesterol (Graham 2021)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/LIPIDS_graham2021/hdl_graham2021_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure"),
  list(name = "LDL cholesterol (Graham 2021)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/LIPIDS_graham2021/ldl_graham2021_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure"),
  list(name = "Non-HDL cholesterol (Graham 2021)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/LIPIDS_graham2021/nonhdl_graham2021_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure"),
  list(name = "Total cholesterol (Graham 2021)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/LIPIDS_graham2021/tc_graham2021_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure"),
  list(name = "Triglycerides (Graham 2021)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/LIPIDS_graham2021/tg_graham2021_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure")
)


# ── Parameters ────────────────────────────────────────────────────────────────
PVAL_IV  <- 5e-8; CLUMP_R2 <- 0.001; CLUMP_KB <- 10000
MIN_IVS  <- 1;    MIN_EAF  <- 0.01
HTN_NAME <- "HTN (Verma 2024)"

dir.create(OUTDIR, recursive = TRUE, showWarnings = FALSE)
ts <- function(...) message(format(Sys.time(), "[%H:%M:%S] "), ...)
clean_name <- function(s) gsub("[^A-Za-z0-9]", "_", s)

fmt_p <- function(p) {
  if (is.null(p) || length(p) == 0) return(NA_character_)
  p <- suppressWarnings(as.numeric(p[1]))
  if (is.na(p))  return(NA_character_)
  if (p < 0.001) formatC(p, format = "e", digits = 2)
  else           as.character(round(p, 3))
}

check_palindromic <- function(EA, NEA) {
  (EA == "T" & NEA == "A") | (EA == "A" & NEA == "T") |
  (EA == "G" & NEA == "C") | (EA == "C" & NEA == "G")
}

build_col_map <- function(dat) {
  list(
    rsid     = if ("rsID"      %in% names(dat)) "rsID"      else NULL,
    beta     = "BETA", se = "SE", ea = "EA", oa = "NEA",
    eaf      = if ("EAF"       %in% names(dat)) "EAF"       else NULL,
    pval     = "P",
    n        = if ("N"         %in% names(dat)) "N"         else NULL,
    ncase    = if ("N_CASE"    %in% names(dat)) "N_CASE"    else NULL,
    ncontrol = if ("N_CONTROL" %in% names(dat)) "N_CONTROL" else NULL,
    chr      = if ("CHR"       %in% names(dat)) "CHR"       else NULL,
    pos      = if ("POS"       %in% names(dat)) "POS"       else NULL
  )
}

inject_n <- function(dat, cfg) {
  if (isTRUE(cfg$binary)) {
    if (!"N_CASE" %in% names(dat) || all(is.na(dat$N_CASE)))
      if (!is.null(cfg$n_cases_manual)) {
        dat$N_CASE <- cfg$n_cases_manual
        ts(sprintf("    N_CASE    (manuel) : %s", format(cfg$n_cases_manual, big.mark = ",")))
      }
    if (!"N_CONTROL" %in% names(dat) || all(is.na(dat$N_CONTROL)))
      if (!is.null(cfg$n_controls_manual)) {
        dat$N_CONTROL <- cfg$n_controls_manual
        ts(sprintf("    N_CONTROL (manuel) : %s", format(cfg$n_controls_manual, big.mark = ",")))
      }
    if ((!"N" %in% names(dat) || all(is.na(dat$N))) &&
        "N_CASE" %in% names(dat) && "N_CONTROL" %in% names(dat) &&
        !all(is.na(dat$N_CASE)) && !all(is.na(dat$N_CONTROL))) {
      dat$N <- dat$N_CASE + dat$N_CONTROL
      ts(sprintf("    N total reconstruit : %s", format(dat$N[1], big.mark = ",")))
    }
  } else {
    n_val <- if (!is.null(cfg$n_total_manual)) cfg$n_total_manual else cfg$n_manual
    if (!"N" %in% names(dat) || all(is.na(dat$N)))
      if (!is.null(n_val)) {
        dat$N <- n_val
        ts(sprintf("    N total   (manuel) : %s", format(n_val, big.mark = ",")))
      }
  }
  dat
}

read_gwaslab <- function(path, min_eaf = NULL, verbose = TRUE) {
  if (!file.exists(path)) stop("File not found: ", path)
  ts(sprintf("  Reading: %s", basename(path)))
  dt <- data.table::fread(path, data.table = FALSE)
  ts(sprintf("  Loaded  : %s variants  |  %d columns", format(nrow(dt), big.mark = ","), ncol(dt)))
  required <- c("SNPID", "CHR", "POS", "NEA", "EA", "BETA", "SE", "P")
  missing  <- setdiff(required, names(dt))
  if (length(missing) > 0) stop("Missing columns: ", paste(missing, collapse = ", "))
  if ("rsID" %in% names(dt))
    dt <- dt[!is.na(dt$rsID) & dt$rsID != "" & dt$rsID != ".", ]
  if (!is.null(min_eaf) && "EAF" %in% names(dt))
    dt <- dt[!is.na(dt$EAF) & dt$EAF >= min_eaf & dt$EAF <= (1 - min_eaf), ]
  ts(sprintf("  Final : %s variants ready", format(nrow(dt), big.mark = ",")))
  dt
}


# =============================================================================
# 0. LIRE LES RÉSULTATS UNIVARIABLES
# =============================================================================

ts("═══ Reading univariable results ═══")

uni_file <- file.path(OUTDIR, "2SMR", "FINAL_bidirectional_MR_all_exposures.tsv")
# Chemin du fichier résultat du script 1 (univariable bidirectionnel)


if (!file.exists(uni_file)) stop("Univariable results not found: ", uni_file)
# Si le fichier n'existe pas → arrête (ce script DÉPEND du script 1)

uni_tbl <- fread(uni_file, data.table = FALSE)
# Lit le tableau des résultats univariables



ts(sprintf("  %d directions from univariable analysis", nrow(uni_tbl)))


# =============================================================================
# CHARGEMENT DES GWAS 
# =============================================================================

ts("Loading all cSVD GWAS ...")

gwas_list <- list()

for (trait in csvd_traits) {
  ts(sprintf("  Loading %s ...", trait$name))
  dat <- read_gwaslab(trait$file, min_eaf = MIN_EAF)
  if (!"N" %in% names(dat)) {
    if ("N_CASE" %in% names(dat) && "N_CONTROL" %in% names(dat)) {
      dat$N <- dat$N_CASE + dat$N_CONTROL
    } else if (!is.null(trait$n_manual)) {
      dat$N <- trait$n_manual
    }
  }
  gwas_list[[trait$name]] <- list(gwas = dat, cfg = trait)
  ts(sprintf("    %d SNPs ✓", nrow(dat)))
}

csvd_loaded <- gwas_list

ts("Loading exposure GWAS ...")

exp_loaded <- list()

for (exp in exposures) {
  ts(sprintf("  Chargement : %s", exp$name))
  dat <- tryCatch({
    d <- read_gwaslab(exp$file, min_eaf = MIN_EAF)
    d <- inject_n(d, exp)
    d
  }, error = function(e) {
    ts(sprintf("  ✗ Échec chargement %s : %s", exp$name, conditionMessage(e)))
    NULL
  })
  if (!is.null(dat)) {
    exp_loaded[[exp$name]] <- list(gwas = dat, cfg = exp)
    ts(sprintf("    %s SNPs ✓", format(nrow(dat), big.mark = ",")))
  }
}
ts(sprintf("  %d / %d expositions chargées", length(exp_loaded), length(exposures)))

# ── Vérifier que HTN est chargé ──────────────────────────────────────────────
if (!HTN_NAME %in% names(exp_loaded)) stop("HTN GWAS not loaded — cannot proceed")
# Si HTN n'est pas chargé → impossible de faire MVMR ajusté HTN

htn_gwas <- exp_loaded[[HTN_NAME]]$gwas
htn_cm   <- build_col_map(htn_gwas)
# Carte des colonnes de HTN (rsid, beta, se, ea, oa, eaf, pval, n, etc.)

# =============================================================================
# BOUCLE MVMR : [Exposure + HTN] → Outcome pour chaque direction
# =============================================================================

ts("═══════════════════════════════════════════════════════════════")
ts("  MVMR : [Exposure + HTN] → Outcome — toutes les directions")
ts("═══════════════════════════════════════════════════════════════")

# Construire les directions PRIMAIRES uniquement
directions <- uni_tbl[uni_tbl$Analysis_type == "primary",
                      c("Exposure", "Outcome")]
directions <- directions[directions$Exposure != HTN_NAME, ]
# Retire la direction HTN → outcome (sinon on aurait HTN + HTN → outcome)
# Car HTN est TOUJOURS co-exposition, jamais exposition principale ici


ts(sprintf("  %d directions à tester", nrow(directions)))

mvmr_results <- list()

# ── Fichier incrémental ──────────────────────────────────────────────────
incremental_tsv <- file.path(OUTDIR_MVMR, "MVMR_HTN_adjusted_incremental.tsv")
header_written  <- FALSE


# Helper : sélectionner les instruments (mêmes filtres que run_direction)
select_ivs <- function(gwas, cm, name, out_gwas, ocm) {
    
  pv  <- gwas[[cm$pval]]
  ivs <- gwas[!is.na(pv) & pv < PVAL_IV, ]   # 1. GW-sig : p < 5e-8
  if (nrow(ivs) < MIN_IVS) ivs <- gwas[!is.na(pv) & pv < 5e-6, ]   # 2. Relaxed : si 0 instrument → essaie p < 5e-6
  if (nrow(ivs) < MIN_IVS) return(NULL) 
  if (!is.null(cm$rsid))
    ivs <- ivs[!is.na(ivs[[cm$rsid]]) & ivs[[cm$rsid]] != "" & ivs[[cm$rsid]] != ".", ]  # Filtre rsID valides


  ivs <- ivs[ivs[[cm$rsid]] %in% out_gwas[[ocm$rsid]], ] # Availability filter
  if (nrow(ivs) < MIN_IVS) return(NULL)
   ivs$is_palindromic <- check_palindromic(EA = ivs[[cm$ea]], NEA = ivs[[cm$oa]])    # 4. Palindromic removal : retire A/T et G/C
  ivs <- ivs[!is.na(ivs$is_palindromic) & !ivs$is_palindromic, ]
  if (nrow(ivs) < MIN_IVS) return(NULL)
  # EAF filter
  if (!is.null(cm$eaf) && cm$eaf %in% names(ivs))
    ivs <- ivs[!is.na(ivs[[cm$eaf]]) & ivs[[cm$eaf]] >= MIN_EAF & ivs[[cm$eaf]] <= (1 - MIN_EAF), ]   # 5. EAF filter : 0.01–0.99
  if (nrow(ivs) < MIN_IVS) return(NULL)
  unique(ivs[[cm$rsid]])
}

# Helper : format_data pour une exposition
fmt_exposure <- function(gwas, cm, name, pooled_snps, id_num) {
    # Cherche TOUS les SNPs poolés dans le GWAS complet d'une exposition
  # puis formate pour TwoSampleMR

  sub <- gwas[gwas[[cm$rsid]] %in% pooled_snps, ]
    # Cherche les SNPs poolés dans le GWAS complet
  # Ex: rs123 est instrument pour TG → on cherche AUSSI son effet dans HTN

  if (nrow(sub) < 3) return(NULL)

  # Prépare les arguments pour format_data()
  eargs <- list(sub, type = "exposure", snp_col = cm$rsid, beta_col = cm$beta,
                se_col = cm$se, effect_allele_col = cm$ea, other_allele_col = cm$oa, pval_col = cm$pval)
 

  if (!is.null(cm$eaf) && cm$eaf %in% names(sub)) eargs$eaf_col <- cm$eaf     
  if (!is.null(cm$n) && cm$n %in% names(sub)) eargs$samplesize_col <- cm$n    
  if (!is.null(cm$ncase) && cm$ncase %in% names(sub)) eargs$ncase_col <- cm$ncase   
  if (!is.null(cm$ncontrol) && cm$ncontrol %in% names(sub)) eargs$ncontrol_col <- cm$ncontrol


  ef <- do.call(format_data, eargs)   # Appelle format_data() → convertit en format TwoSampleMR
  ef$id.exposure <- paste0("mvmr_", id_num)   # id unique par exposure
  ef$exposure    <- name   # Label lisible ("Triglycerides (Graham 2021)" ou "HTN (Verma 2024)")
  ef

}
#boucle MVMR 

for (i in seq_len(nrow(directions))) {

  exp_name <- directions$Exposure[i]
  out_name <- directions$Outcome[i]

  ts(sprintf("══ MVMR [%d/%d] : [%s + HTN] → %s ══", i, nrow(directions), exp_name, out_name))



  # ── Retrouver les GWAS ──────────────────────────────────────────
  exp_src <- if (exp_name %in% names(exp_loaded))  exp_loaded[[exp_name]]
             else if (exp_name %in% names(csvd_loaded)) csvd_loaded[[exp_name]]
             else NULL
               # Cherche l'exposition dans exp_loaded (27 traits)
                 # ou dans csvd_loaded (4 traits cSVD, car WMH peut être exposition)

  out_src <- if (out_name %in% names(csvd_loaded)) csvd_loaded[[out_name]]
             else if (out_name %in% names(exp_loaded))  exp_loaded[[out_name]]
             else NULL
  # Pareil pour l'outcome


  if (is.null(exp_src) || is.null(out_src)) {
    ts("    ✗ GWAS not found — skipping"); next
  }

  tryCatch({

    exp_gwas <- exp_src$gwas;  
    exp_cm <- build_col_map(exp_gwas)
    out_gwas <- out_src$gwas;  
    out_cm <- build_col_map(out_gwas)

    # ── 1. Instruments (mêmes filtres que run_direction) ──────────────────
    rsids_exp <- select_ivs(exp_gwas, exp_cm, exp_name, out_gwas, out_cm) 
    rsids_htn <- select_ivs(htn_gwas, htn_cm, HTN_NAME, out_gwas, out_cm)

    if (is.null(rsids_exp)) { ts(sprintf("    ✗ 0 instruments for %s — skipping", exp_name)); next }
    if (is.null(rsids_htn)) { ts("    ✗ 0 instruments for HTN — skipping"); next }

    ts(sprintf("    %s : %d instruments | HTN : %d instruments", exp_name, length(rsids_exp), length(rsids_htn)))

    # ── 2. Pool ──────────────────────────────────────────────────────────
    pooled_snps <- unique(c(rsids_exp, rsids_htn)) #Combine les instruments des deux expositions en un seul vecteur sans doublons.
    ts(sprintf("    Pool : %d unique SNPs", length(pooled_snps))) 

    # ── 3. Lookup + format_data ──────────────────────────────────────────
    d1 <- fmt_exposure(exp_gwas, exp_cm, exp_name, pooled_snps, 1) #Cherche tous les SNPs poolés dans le GWAS complet de TG, puis formate pour TwoSampleMR. 
    #: rs4 est instrument pour HTN mais on a aussi besoin de son effet sur TG → on le cherche dans le GWAS complet de TG (pas juste ses propres instruments).
    d2 <- fmt_exposure(htn_gwas, htn_cm, HTN_NAME, pooled_snps, 2)
    if (is.null(d1) || is.null(d2)) { ts("    ✗ format_data failed — skipping"); next }

    # Align columns before rbind, on ajoute les colonnes manquantes avec NA
    all_cols <- unique(c(names(d1), names(d2)))
    for (col in setdiff(all_cols, names(d1))) d1[[col]] <- NA
    for (col in setdiff(all_cols, names(d2))) d2[[col]] <- NA
    combined_exp <- rbind(d1[, all_cols], d2[, all_cols])

    ts(sprintf("    Combined : %d rows | %d SNPs", nrow(combined_exp), length(unique(combined_exp$SNP))))

    # ── 4. Clump ─────────────────────────────────────────────────────────
    clump_input <- combined_exp %>%
      group_by(SNP) %>%
      slice_min(pval.exposure, n = 1, with_ties = FALSE) %>%
      ungroup() %>% as.data.frame() # Pour chaque SNP (qui apparaît 2 fois : TG et HTN), garde la ligne avec la p-value la plus petite.

    exp_c <- tryCatch(
      clump_data(clump_input, clump_r2 = CLUMP_R2, clump_kb = CLUMP_KB, pop = "EUR"),
      error = function(e) { ts("    ⚠ Clumping failed — using unclumped"); clump_input }
    )#Envoie les SNPs à l'API OpenGWAS pour retirer ceux en LD (corrélés).

    clumped_snps <- unique(exp_c$SNP) # Besoin d'au moins 3 SNPs pour une régression à 2 expositions (sinon sous-identifié).
    ts(sprintf("    Clumping : %d → %d independent SNPs", length(pooled_snps), length(clumped_snps)))
    if (length(clumped_snps) < 3) { ts("    ✗ Too few — skipping"); next } 

    combined_exp <- combined_exp[combined_exp$SNP %in% clumped_snps, ] #Filtre combined_exp pour ne garder que les SNPs qui ont survécu au clumping.

    # ── 5. Format outcome ────────────────────────────────────────────────
    out_sub <- out_gwas[out_gwas[[out_cm$rsid]] %in% clumped_snps, ] #Cherche les SNPs clumpés dans le GWAS de l'outcome (ex: WMH Shiva).
    ts(sprintf("    Outcome match : %d / %d by rsID", nrow(out_sub), length(clumped_snps)))
    if (nrow(out_sub) < 3) { ts("    ✗ Too few outcome SNPs — skipping"); next }

#Formate l'outcome pour TwoSampleMR et lui donne un label + id unique.
    oargs <- list(out_sub, type = "outcome", snp_col = out_cm$rsid, beta_col = out_cm$beta,
                  se_col = out_cm$se, effect_allele_col = out_cm$ea, other_allele_col = out_cm$oa, pval_col = out_cm$pval)
    if (!is.null(out_cm$eaf) && out_cm$eaf %in% names(out_sub)) oargs$eaf_col <- out_cm$eaf
    if (!is.null(out_cm$n) && out_cm$n %in% names(out_sub)) oargs$samplesize_col <- out_cm$n
    if (!is.null(out_cm$ncase) && out_cm$ncase %in% names(out_sub)) oargs$ncase_col <- out_cm$ncase
    if (!is.null(out_cm$ncontrol) && out_cm$ncontrol %in% names(out_sub)) oargs$ncontrol_col <- out_cm$ncontrol

    out_fmt <- do.call(format_data, oargs)
    out_fmt$outcome    <- out_name
    out_fmt$id.outcome <- "mvmr_outcome"

    # ── 6. mv_harmonise_data ─────────────────────────────────────────────
    ts("    Harmonising ...")
     mvdat <- mv_harmonise_data(combined_exp, out_fmt, harmonise_strictness = 3)    # Aligne les allèles entre les 2 expositions et l'outcome pour chaque SNP.

    n_snps <- nrow(mvdat$exposure_beta)
    n_exp  <- ncol(mvdat$exposure_beta)
    ts(sprintf("    Harmonised : %d SNPs × %d exposures", n_snps, n_exp))
    if (n_snps < n_exp + 1) { ts("    ✗ Under-identified — skipping"); next }

    # ── 7. mv_multiple ───────────────────────────────────────────────────
    ts("    Running mv_multiple ...")
    mvmr_res <- mv_multiple(mvdat, intercept = FALSE, instrument_specific = FALSE,
                            pval_threshold = 5e-08, plots = FALSE)

#Enrichit le résultat avec le nom de l'outcome, le nombre de SNPs, et un identifiant unique de la paire.
    r <- mvmr_res$result
    r$outcome <- out_name
    r$n_snps  <- n_snps
    r$pair_id <- sprintf("%s_HTN_to_%s", clean_name(exp_name), clean_name(out_name))  # Sert plus tard à matcher la ligne HTN avec la bonne ligne exposition dans le tableau de comparaison

    # Ajouter univariable pour comparaison, cherche le résultat univariable correspondant (TG → WMH) et ajoute sa p-value au résultat MVMR.
    uni_row <- uni_tbl[uni_tbl$Exposure == exp_name & uni_tbl$Outcome == out_name, ]
    r$univariable_IVW_pval <- if (nrow(uni_row) > 0) uni_row$IVW_p_raw[1] else NA_real_

    ts("    ✓ Results:")
    print(r[, intersect(c("exposure", "outcome", "b", "se", "pval", "nsnp"), names(r))])

    # enregistre progressivmeent dans un fichier TSV. 
  fwrite(r, incremental_tsv,
           sep = "\t", append = header_written, col.names = !header_written)
    header_written <- TRUE
    ts(sprintf("    ✓ Appended to %s (%d lines total)",
               basename(incremental_tsv),
               length(mvmr_results) * 2 + nrow(r)))

    key <- sprintf("%s_HTN_to_%s", clean_name(exp_name), clean_name(out_name))
    mvmr_results[[key]] <- r #Stocke le résultat dans la liste mvmr_results sous une clé unique.

  }, error = function(e) ts(sprintf("    ✗ Error : %s", conditionMessage(e))))
}

# =============================================================================
# TABLEAU FINAL MVMR
# =============================================================================

if (length(mvmr_results) > 0) {

  mvmr_tbl <- do.call(rbind, mvmr_results) # Empile tous les résultats en un seul dataframe.
  rownames(mvmr_tbl) <- NULL
  mvmr_tbl <- mvmr_tbl[order(mvmr_tbl$pval, na.last = TRUE), ] #Trie par p-value croissante, NA à la fin.

  N_TESTS_MVMR   <- nrow(mvmr_tbl[mvmr_tbl$exposure != HTN_NAME, ])
    bonf_threshold  <- 0.05 / max(N_TESTS_MVMR, 1)
  mvmr_tbl$sig_nominal    <- mvmr_tbl$pval < 0.05 
  mvmr_tbl$sig_bonferroni <- mvmr_tbl$pval < bonf_threshold
  mvmr_tbl$bonf_threshold <- fmt_p(bonf_threshold)

  # ── Séparer expositions d'intérêt vs HTN ────────────────────────────────
  mvmr_expo <- mvmr_tbl[mvmr_tbl$exposure != HTN_NAME, ] #Garde uniquement les lignes des expositions d'intérêt (TG, LDL, etc.).
  mvmr_htn  <- mvmr_tbl[mvmr_tbl$exposure == HTN_NAME, ] #Garde uniquement les lignes HTN
  mvmr_tbl$role <- ifelse(mvmr_tbl$exposure == HTN_NAME,
                          "adjustment", "primary_exposure") #Ajoute une colonne role pour marquer chaque ligne

  # ── Créer le tableau de comparaison univariable vs MVMR ─────────────────
  comparison <- data.frame(stringsAsFactors = FALSE)

# Boucle sur chaque ligne de mvmr_expo 
  for (j in seq_len(nrow(mvmr_expo))) { # Récupère le nom de l'exposition et de l'outcome pour cette ligne.
    exp_j <- mvmr_expo$exposure[j] 
    out_j <- mvmr_expo$outcome[j]

    # Résultat MVMR,  Récupère le β, SE et p-value MVMR pour cette exposition.
    mvmr_b    <- mvmr_expo$b[j]
    mvmr_se   <- mvmr_expo$se[j]
    mvmr_pval <- mvmr_expo$pval[j]
    mvmr_nsnp <- if ("nsnp" %in% names(mvmr_expo)) mvmr_expo$nsnp[j] else NA
    mvmr_nsnps_total <- if ("n_snps" %in% names(mvmr_expo)) mvmr_expo$n_snps[j] else NA

    # Résultat HTN pour la même direction
    pair_key  <- sprintf("%s_HTN_to_%s", clean_name(exp_j), clean_name(out_j)) # Cherche la ligne HTN correspondant à cette même paire (ex: [TG + HTN] → WMH).
    htn_match <- mvmr_htn[mvmr_htn$pair_id == pair_key, ] #On veut le β de HTN dans ce modèle précis (ajusté pour TG, pas pour LDL)
    htn_b    <- if (nrow(htn_match) > 0) htn_match$b[1]    else NA_real_ #Extrait le β et p-value de HTN dans ce modèle. NA si pas trouvé.
    htn_pval <- if (nrow(htn_match) > 0) htn_match$pval[1] else NA_real_

    # Résultat univariable correspondant (dans uni_tbl, extrait la p-value, le nombre de SNPs, et le string "Beta (SE)")
    uni_row <- uni_tbl[uni_tbl$Exposure == exp_j & uni_tbl$Outcome == out_j, ] 
    uni_b    <- NA_real_
    uni_pval <- NA_real_
    uni_nsnp <- NA_integer_
    if (nrow(uni_row) > 0) {
      uni_pval <- uni_row$IVW_p_raw[1]
      uni_nsnp <- uni_row$N_SNPs[1]
      bse <- uni_row$IVW_Beta_SE[1]
      if (!is.na(bse)) {
        parts <- regmatches(bse, regexpr("^[-0-9.]+", bse))
        if (length(parts) > 0) uni_b <- as.numeric(parts)
      }
    }

    # Interprétation automatique
    interpretation <- if (is.na(uni_pval) || is.na(mvmr_pval)) {
      "Comparison not possible"
    } else if (uni_pval < 0.05 & mvmr_pval < 0.05) {
      "Direct effect confirmed (independent of HTN)" #significatif en univariable ET en MVMR
    } else if (uni_pval < 0.05 & mvmr_pval >= 0.05) {
      "Effect attenuated (may be mediated by HTN)" #Significatif en univariable mais PAS en MVMR → l'effet disparaît quand on ajuste pour HTN → probablement médié par HTN.
    } else if (uni_pval >= 0.05 & mvmr_pval < 0.05) {
      "Effect unmasked (HTN was negative confounder)" #"Effect unmasked (HTN was negative confounder)"
    } else {
      "No effect in either analysis"
    }

# Crée une ligne avec toutes les infos et l'ajoute au tableau de comparaison.
    row <- data.frame(
      Exposure                = exp_j,
      Outcome                 = out_j,
      Univariable_IVW_b       = uni_b,
      Univariable_IVW_p       = fmt_p(uni_pval),
      Univariable_IVW_p_raw   = uni_pval,
      Univariable_N_SNPs      = uni_nsnp,
      MVMR_b_adjusted_HTN     = round(mvmr_b, 4),
      MVMR_se_adjusted_HTN    = round(mvmr_se, 4),
      MVMR_p_adjusted_HTN     = fmt_p(mvmr_pval),
      MVMR_p_adjusted_HTN_raw = mvmr_pval,
      MVMR_N_SNPs_total       = mvmr_nsnps_total,
      HTN_direct_b            = round(htn_b, 4),
      HTN_direct_p            = fmt_p(htn_pval),
      Interpretation          = interpretation,
      stringsAsFactors = FALSE
    )
    comparison <- rbind(comparison, row)
  }
  
  #Trie par p-value MVMR croissante.
  comparison <- comparison[order(comparison$MVMR_p_adjusted_HTN_raw, na.last = TRUE), ]
  rownames(comparison) <- NULL

  # ── Export TSV ──────────────────────────────────────────────────────────────
  out_tsv <- file.path(OUTDIR_MVMR, "FINAL_MVMR_HTN_adjusted.tsv")
  fwrite(mvmr_tbl, out_tsv, sep = "\t")
  ts(sprintf("  TSV : %d lignes → %s", nrow(mvmr_tbl), basename(out_tsv)))
# Sauvegarde le tableau complet (expo + HTN) en TSV.
  

  comp_tsv <- file.path(OUTDIR_MVMR, "MVMR_vs_univariable_comparison.tsv")
  fwrite(comparison, comp_tsv, sep = "\t")
  ts(sprintf("  Comparaison TSV → %s", basename(comp_tsv)))
  #Sauvegarde le tableau de comparaison en TSV.

  # ── Export XLSX ─────────────────────────────────────────────────────────────
  if (HAS_XLSX) {

    wb <- openxlsx::createWorkbook()

    header_style <- openxlsx::createStyle(
      fontColour = "#FFFFFF", fgFill = "#2F5597",
      halign = "CENTER", textDecoration = "Bold", wrapText = TRUE
    )
    sig_style  <- openxlsx::createStyle(fgFill = "#E2EFDA")
    bonf_style <- openxlsx::createStyle(fgFill = "#FFD966")
#vert clair pour p < 0.05, jaune pour p < Bonferroni.

#Fonction réutilisable pour créer un onglet Excel formaté.
#
    write_mvmr_sheet <- function(wb, sheet_name, data, p_col = "pval") {
      if (nrow(data) == 0) {
        ts(sprintf("  ⚠ Feuille '%s' vide — non créée", sheet_name))
        return(invisible(NULL))
      }

      openxlsx::addWorksheet(wb, sheet_name)  #Ajoute un onglet et écrit les données avec les en-têtes stylisés.
      openxlsx::writeData(wb, sheet_name, data, headerStyle = header_style)

      if (p_col %in% names(data)) {
        sig_rows  <- which(!is.na(data[[p_col]]) & data[[p_col]] < 0.05) #Identifie les lignes significatives (nominales et Bonferroni).
        bonf_rows <- which(!is.na(data[[p_col]]) & data[[p_col]] < bonf_threshold)
      } else {
        sig_rows  <- integer(0)
        bonf_rows <- integer(0)
      }

      if (length(sig_rows) > 0)
        openxlsx::addStyle(wb, sheet_name, style = sig_style,
                           rows = sig_rows + 1, cols = seq_len(ncol(data)),
                           gridExpand = TRUE) # Colorie les lignes significatives en vert. +1 car la ligne 1 est l'en-tête.
      if (length(bonf_rows) > 0)
        openxlsx::addStyle(wb, sheet_name, style = bonf_style,
                           rows = bonf_rows + 1, cols = seq_len(ncol(data)),
                           gridExpand = TRUE)

      openxlsx::setColWidths(wb, sheet_name, cols = seq_len(ncol(data)), widths = "auto")
      openxlsx::freezePane(wb, sheet_name, firstRow = TRUE) #Ajuste la largeur des colonnes et fige la première ligne (en-têtes visibles quand on scrolle).

      ts(sprintf("  Feuille '%s' : %d lignes | %d sig (p<0.05) | %d Bonferroni (p<%.2e)",
                 sheet_name, nrow(data), length(sig_rows), length(bonf_rows), bonf_threshold))
    }

    # ── Onglet 1 : Tous les résultats MVMR ────────────────────────────────
    write_mvmr_sheet(wb, "MVMR all results", mvmr_tbl, p_col = "pval")

    # ── Onglet 2 : Expositions d'intérêt seulement (sans HTN) ─────────────
    write_mvmr_sheet(wb, "MVMR exposures only", mvmr_expo, p_col = "pval")

    # ── Onglet 3 : HTN seulement ──────────────────────────────────────────
    write_mvmr_sheet(wb, "MVMR HTN adjustment", mvmr_htn, p_col = "pval")

    # ── Onglet 4 : Comparaison univariable vs MVMR ────────────────────────
    openxlsx::addWorksheet(wb, "MVMR vs Univariable")
    openxlsx::writeData(wb, "MVMR vs Univariable", comparison, headerStyle = header_style) 

    # Colorer par p-value MVMR
    sig_rows  <- which(!is.na(comparison$MVMR_p_adjusted_HTN_raw) &
                         comparison$MVMR_p_adjusted_HTN_raw < 0.05)
    bonf_rows <- which(!is.na(comparison$MVMR_p_adjusted_HTN_raw) &
                         comparison$MVMR_p_adjusted_HTN_raw < bonf_threshold)

    if (length(sig_rows) > 0)
      openxlsx::addStyle(wb, "MVMR vs Univariable", style = sig_style,
                         rows = sig_rows + 1, cols = seq_len(ncol(comparison)),
                         gridExpand = TRUE)
    if (length(bonf_rows) > 0)
      openxlsx::addStyle(wb, "MVMR vs Univariable", style = bonf_style,
                         rows = bonf_rows + 1, cols = seq_len(ncol(comparison)),
                         gridExpand = TRUE)

    # Colorer les interprétations
    confirmed_style  <- openxlsx::createStyle(fontColour = "#006100", fgFill = "#C6EFCE")
    attenuated_style <- openxlsx::createStyle(fontColour = "#9C5700", fgFill = "#FFEB9C")
    unmasked_style   <- openxlsx::createStyle(fontColour = "#003399", fgFill = "#D6E4F0")

    interp_col <- which(names(comparison) == "Interpretation")

    confirmed_rows  <- which(comparison$Interpretation == "Direct effect confirmed (independent of HTN)")
    attenuated_rows <- which(comparison$Interpretation == "Effect attenuated (may be mediated by HTN)")
    unmasked_rows   <- which(comparison$Interpretation == "Effect unmasked (HTN was negative confounder)")

    if (length(confirmed_rows) > 0)
      openxlsx::addStyle(wb, "MVMR vs Univariable", style = confirmed_style, #Colorie la cellule "Interpretation" en vert pour les effets confirmés.
                         rows = confirmed_rows + 1, cols = interp_col, gridExpand = TRUE)
    if (length(attenuated_rows) > 0)
      openxlsx::addStyle(wb, "MVMR vs Univariable", style = attenuated_style,
                         rows = attenuated_rows + 1, cols = interp_col, gridExpand = TRUE)
    if (length(unmasked_rows) > 0)
      openxlsx::addStyle(wb, "MVMR vs Univariable", style = unmasked_style,
                         rows = unmasked_rows + 1, cols = interp_col, gridExpand = TRUE)

    openxlsx::setColWidths(wb, "MVMR vs Univariable",
                           cols = seq_len(ncol(comparison)), widths = "auto")
    openxlsx::freezePane(wb, "MVMR vs Univariable", firstRow = TRUE)

    ts(sprintf("  Feuille 'MVMR vs Univariable' : %d lignes | %d confirmed | %d attenuated | %d unmasked",
               nrow(comparison),
               length(confirmed_rows), length(attenuated_rows), length(unmasked_rows)))

    out_xlsx <- file.path(OUTDIR_MVMR, "FINAL_MVMR_HTN_adjusted.xlsx")
    openxlsx::saveWorkbook(wb, out_xlsx, overwrite = TRUE)
    ts(sprintf("  XLSX sauvegardé → %s", basename(out_xlsx)))

  } else {
    ts("  ⚠ openxlsx non disponible")
  }
# ── Forest plots ────────────────────────────────────────────────────────
  ts("═══ Generating forest plots ═══")

  # ── A. Forest plot : toutes les expositions (effet MVMR ajusté HTN) ────

  expo_data <- mvmr_tbl[mvmr_tbl$exposure != HTN_NAME, ] # Ne garde que les expositions d'intérêt (pas les lignes HTN).

  if (nrow(expo_data) > 0) {

    expo_data$ci_lo <- expo_data$b - 1.96 * expo_data$se #Calcule les bornes de l'intervalle de confiance à 95%.
    expo_data$ci_hi <- expo_data$b + 1.96 * expo_data$se
    expo_data$label <- paste0(expo_data$exposure, " → ", expo_data$outcome) #Crée un label lisible pour l'axe Y.
    expo_data <- expo_data[order(expo_data$outcome, expo_data$pval), ] #Trie par outcome puis par p-value. 
    expo_data$label <- factor(expo_data$label, levels = rev(expo_data$label)) #fait que le résultat le plus significatif est en haut du plot.

    p1 <- ggplot(expo_data, aes(x = b, y = label)) +
      geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") + #Ligne verticale en pointillés à x = 0 (pas d'effet).
      geom_point(aes(color = pval < 0.05), size = 3) +
      geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi, color = pval < 0.05),
                     height = 0.2) + #Points + barres d'erreur horizontales, colorés selon la significativité.
      #Rouge si p < 0.05, noir sinon
      scale_color_manual(
        values = c("TRUE" = "#D62728", "FALSE" = "#1F77B4"),
        labels = c("TRUE" = "p < 0.05", "FALSE" = "p >= 0.05"),
        name   = ""
      ) +
      facet_wrap(~ outcome, scales = "free_y", ncol = 1) +
      labs(
        title    = "MVMR: Direct effects adjusted for HTN",
        subtitle = "Each exposure paired with HTN (Verma 2024) as co-exposure",
        x = "Beta (95% CI)",
        y = NULL
      ) +
      theme_bw(base_size = 11) +
      theme(
        plot.title    = element_text(face = "bold", size = 14),
        plot.subtitle = element_text(size = 10, color = "grey40"),
        legend.position = "bottom",
        strip.background = element_rect(fill = "#2F5597"),
        strip.text = element_text(color = "white", face = "bold")
      )

    ht1 <- max(6, nrow(expo_data) * 0.5 + 4)
    ggsave(
      file.path(OUTDIR_MVMR, "forest_MVMR_all_exposures_HTN_adjusted.pdf"),
      p1, width = 12, height = ht1, limitsize = FALSE
    )
    ts("  ✓ Forest plot A → forest_MVMR_all_exposures_HTN_adjusted.pdf")
  }

  # ── B. Forest plot par outcome ─────────────────────────────────────────

  for (out_name in unique(expo_data$outcome)) {

    out_data <- expo_data[expo_data$outcome == out_name, ]
    if (nrow(out_data) == 0) next

    out_data$label <- factor(out_data$label, levels = rev(out_data$label))

    p_out <- ggplot(out_data, aes(x = b, y = label)) +
      geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
      geom_point(aes(color = pval < 0.05), size = 3) +
      geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi, color = pval < 0.05),
                     height = 0.2) +
      scale_color_manual(
        values = c("TRUE" = "#D62728", "FALSE" = "#1F77B4"),
        labels = c("TRUE" = "p < 0.05", "FALSE" = "p >= 0.05"),
        name   = ""
      ) +
      labs(
        title    = sprintf("MVMR adjusted for HTN → %s", out_name),
        x = "Beta (95% CI)",
        y = NULL
      ) +
      theme_bw(base_size = 12) +
      theme(
        plot.title = element_text(face = "bold", size = 14),
        legend.position = "bottom"
      )

    ht_out <- max(4, nrow(out_data) * 0.6 + 2)
    ggsave(
      file.path(OUTDIR_MVMR, sprintf("forest_MVMR_HTN_%s.pdf", clean_name(out_name))),
      p_out, width = 10, height = ht_out, limitsize = FALSE
    )
    ts(sprintf("  ✓ Forest per outcome → forest_MVMR_HTN_%s.pdf", clean_name(out_name)))
  }

  # ── C. Comparison forest plot : MVMR vs Univariable ────────────────────

  if (nrow(comparison) > 0 &&
      any(!is.na(comparison$Univariable_IVW_b)) &&
      any(!is.na(comparison$MVMR_b_adjusted_HTN))) {

    # Build long format
    mvmr_long <- data.frame(
      label  = paste0(comparison$Exposure, " → ", comparison$Outcome),
      method = "MVMR (adjusted HTN)",
      b      = comparison$MVMR_b_adjusted_HTN,
      se     = comparison$MVMR_se_adjusted_HTN,
      pval   = comparison$MVMR_p_adjusted_HTN_raw,
      outcome = comparison$Outcome,
      stringsAsFactors = FALSE
    )

    uni_se_vec <- rep(NA_real_, nrow(comparison))
    for (k in seq_len(nrow(comparison))) {
      row_k <- uni_tbl[uni_tbl$Exposure == comparison$Exposure[k] &
                          uni_tbl$Outcome == comparison$Outcome[k], ]
      if (nrow(row_k) > 0) {
        bse_k <- row_k$IVW_Beta_SE[1]
        if (!is.na(bse_k)) {
          se_k <- regmatches(bse_k, regexpr("(?<=\\()[0-9.]+(?=\\))", bse_k, perl = TRUE))
          if (length(se_k) > 0) uni_se_vec[k] <- as.numeric(se_k)
        }
      }
    }

    uni_long <- data.frame(
      label  = paste0(comparison$Exposure, " → ", comparison$Outcome),
      method = "Univariable (total)",
      b      = comparison$Univariable_IVW_b,
      se     = uni_se_vec,
      pval   = comparison$Univariable_IVW_p_raw,
      outcome = comparison$Outcome,
      stringsAsFactors = FALSE
    )

    comp_long <- rbind(mvmr_long, uni_long)
    comp_long <- comp_long[!is.na(comp_long$b), ]
    comp_long <- comp_long[!is.na(comp_long$se), ] 

    
    
    
    if (nrow(comp_long) > 0) {

      comp_long$ci_lo <- comp_long$b - 1.96 * comp_long$se
      comp_long$ci_hi <- comp_long$b + 1.96 * comp_long$se

      # One comparison per outcome
      for (out_name in unique(comp_long$outcome)) {

        out_comp <- comp_long[comp_long$outcome == out_name, ]
        if (nrow(out_comp) == 0) next

        out_comp$label <- factor(out_comp$label, levels = rev(unique(out_comp$label)))

        p2 <- ggplot(out_comp, aes(x = b, y = label, color = method, shape = method)) +
          geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
          geom_point(size = 3, position = position_dodge(width = 0.5)) +
          geom_errorbarh(
            aes(xmin = ci_lo, xmax = ci_hi),
            height = 0.2,
            position = position_dodge(width = 0.5)
          ) +
          scale_color_manual(
            values = c("MVMR (adjusted HTN)" = "#D62728",
                       "Univariable (total)"  = "#1F77B4")
          ) +
          scale_shape_manual(
            values = c("MVMR (adjusted HTN)" = 16,
                       "Univariable (total)"  = 17)
          ) +
          labs(
            title    = sprintf("MVMR vs Univariable → %s", out_name),
            subtitle = "Red = direct effect (adjusted HTN) | Blue = total effect",
            x = "Beta (95% CI)", y = NULL,
            color = "Method", shape = "Method"
          ) +
          theme_bw(base_size = 12) +
          theme(
            plot.title    = element_text(face = "bold", size = 14),
            plot.subtitle = element_text(size = 10, color = "grey40"),
            legend.position = "bottom"
          )

        n_lab <- length(unique(out_comp$label))
        ht2 <- max(4, n_lab * 0.8 + 2)
        ggsave(
          file.path(OUTDIR_MVMR, sprintf("forest_comparison_HTN_%s.pdf",
                                          clean_name(out_name))),
          p2, width = 11, height = ht2, limitsize = FALSE
        )
        ts(sprintf("  ✓ Comparison plot → forest_comparison_HTN_%s.pdf",
                   clean_name(out_name)))
      }
    }
  }

  # ── D. Significant results only ────────────────────────────────────────

  sig_expo <- expo_data[!is.na(expo_data$pval) & expo_data$pval < 0.05, ]

  if (nrow(sig_expo) > 0) {

    sig_expo$label <- factor(sig_expo$label, levels = rev(sig_expo$label))

    p3 <- ggplot(sig_expo, aes(x = b, y = label)) +
      geom_vline(xintercept = 0, linetype = "dashed", color = "grey50") +
      geom_point(aes(color = sig_bonferroni), size = 3) +
      geom_errorbarh(aes(xmin = ci_lo, xmax = ci_hi, color = sig_bonferroni),
                     height = 0.2) +
      scale_color_manual(
        values = c("TRUE" = "#d17600", "FALSE" = "#D62728"),
        labels = c("TRUE" = "Bonferroni sig", "FALSE" = "Nominal sig"),
        name   = ""
      ) +
      labs(
        title    = "MVMR adjusted for HTN — Significant direct effects (p < 0.05)",
        subtitle = sprintf("Gold = Bonferroni (p < %s) | Red = nominal only",
                           fmt_p(bonf_threshold)),
        x = "Beta (95% CI)",
        y = NULL
      ) +
      theme_bw(base_size = 12) +
      theme(
        plot.title    = element_text(face = "bold", size = 14),
        plot.subtitle = element_text(size = 10, color = "grey40"),
        legend.position = "bottom"
      )

    ht3 <- max(5, nrow(sig_expo) * 0.6 + 2)
    ggsave(
      file.path(OUTDIR_MVMR, "forest_MVMR_HTN_significant.pdf"),
      p3, width = 12, height = ht3, limitsize = FALSE
    )
    ts("  ✓ Global forest → forest_MVMR_HTN_significant.pdf")

  } else {
    ts("  ⚠ No significant results — no global forest plot")
  }

  ts("═══ Forest plots complete ═══")

  # ── Résumé final ────────────────────────────────────────────────────────────
  ts("═══ MVMR Summary ═══")
  ts(sprintf("  N directions testées    : %d", nrow(directions)))
  ts(sprintf("  N réussies              : %d", length(mvmr_results)))
  ts(sprintf("  N lignes résultat       : %d", nrow(mvmr_tbl)))
  ts(sprintf("  N expositions d'intérêt : %d", nrow(mvmr_expo)))
  ts(sprintf("  N sig (p < 0.05)        : %d", sum(mvmr_tbl$sig_nominal, na.rm = TRUE)))
  ts(sprintf("  Seuil Bonferroni        : %.2e (%d tests)", bonf_threshold, N_TESTS_MVMR))
  ts(sprintf("  N Bonferroni            : %d", sum(mvmr_tbl$sig_bonferroni, na.rm = TRUE)))

  if (nrow(comparison) > 0) {
    ts("── Comparaison univariable vs MVMR ──")
    ts(sprintf("  Direct confirmed     : %d",
               sum(comparison$Interpretation == "Direct effect confirmed (independent of HTN)")))
    ts(sprintf("  Attenuated by HTN    : %d",
               sum(comparison$Interpretation == "Effect attenuated (may be mediated by HTN)")))
    ts(sprintf("  Unmasked by HTN      : %d",
               sum(comparison$Interpretation == "Effect unmasked (HTN was negative confounder)")))
    ts(sprintf("  No effect            : %d",
               sum(comparison$Interpretation == "No effect in either analysis")))
    ts(sprintf("  Comparison NA        : %d",
               sum(comparison$Interpretation == "Comparison not possible")))
  }

  ts(sprintf("  Résultats → %s", OUTDIR_MVMR))

} else {
  ts("  ⚠ No MVMR results produced")
}

ts("═══ MVMR script complete ═══")
