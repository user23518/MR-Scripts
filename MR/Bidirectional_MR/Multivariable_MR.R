# =============================================================================
# MULTIVARIABLE MENDELIAN RANDOMISATION (MVMR) — STANDALONE SCRIPT
#
# Reads the same GWAS files used in the univariable pipeline.
# Does NOT re-run any univariable MR.
# Estimates the DIRECT effect of each exposure on each cSVD outcome,
# adjusted for the other exposures in the group.
# =============================================================================

library(TwoSampleMR)
library(data.table)
library(dplyr)
library(ggplot2)

HAS_XLSX <- requireNamespace("openxlsx", quietly = TRUE)

# ── Proxy (same as univariable script) ───────────────────────────────────────
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


# ── Paths ────────────────────────────────────────────────────────────────────
OUTDIR_UNI  <- "/network/iss/debette/users/marine.huang/MR/results"
OUTDIR_MVMR <- "/network/iss/debette/users/marine.huang/MR/results/MVMR"
dir.create(OUTDIR_MVMR, recursive = TRUE, showWarnings = FALSE)

# ── Parameters ───────────────────────────────────────────────────────────────
PVAL_IV  <- 5e-8
CLUMP_R2 <- 0.001
CLUMP_KB <- 10000
MIN_EAF  <- 0.01

ts <- function(...) message(format(Sys.time(), "[%H:%M:%S] "), ...)
clean_name <- function(s) gsub("[^A-Za-z0-9]", "_", s)
fmt_p <- function(p) {
  if (is.null(p) || length(p) == 0) return(NA_character_)
  p <- suppressWarnings(as.numeric(p[1]))
  if (is.na(p))  return(NA_character_)
  if (p < 0.001) formatC(p, format = "e", digits = 2) else as.character(round(p, 3))
}


# =============================================================================
# TRAIT DEFINITIONS (same as univariable script)
# =============================================================================

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

exposures <- list(
  list(name = "Alzheimer's disease (Nicolas 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/AD_nicolas2025/ad_nicolas2025_hg38.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.05, n_cases_manual = NULL, n_controls_manual = NULL),
  list(name = "Parkinson's disease (Leonard 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/PD_leonard2025/GP2_euro_ancestry_meta_analysis_2024/pd_leonard2025_hg38.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.001, n_cases_manual = 34933, n_controls_manual = 3100),
  list(name = "Major depressive disorder (Adams 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/MDD_adams2025/mdd_adams2025_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.05, n_manual = NULL),
  list(name = "Migraine (Hautakangas 2022)",
       file = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/NON_UKBiobank/migraine_hautakangas2022/without_ukb/migraine_without_ukb_hautakangas2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.14, n_cases_manual = 38094, n_controls_manual = 210211),
  list(name = "Cardioembolic stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/CEstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.002, n_cases_manual = 10804, n_controls_manual = 865389),
  list(name = "Large artery stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/LAAstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.002, n_cases_manual = 6399, n_controls_manual = 865389),
  list(name = "Small vessel stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/SVstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.0025, n_cases_manual = 6811, n_controls_manual = 865389),
  list(name = "Ischaemic stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/ISCHAEMICstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.01, n_cases_manual = 59890, n_controls_manual = 865389),
  list(name = "Any stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/ANYstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.015, n_cases_manual = 70720, n_controls_manual = 865389),
  list(name = "Atrial fibrillation (Yuan 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/AF_yuan2025/af_yuan2025_hg38.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.01, n_manual = NULL),
  list(name = "Heart failure (Shah 2020)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/HF_shah2020/hf_shah2020_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.02, n_cases_manual = NULL, n_controls_manual = NULL),
  list(name = "HTN (Verma 2024)",
       file = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/NON_UKBiobank/htn_verma2024/htn_verma2024_hg38.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.3, n_cases_manual = 320429, n_controls_manual = 107275),
  list(name = "Carotid atherosclerosis / IMT (Gummesson 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/ATHERO_gummesson2025/carotid_gummesson2025_hg38.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = 26807),
  list(name = "Coronary plaq (Gummesson 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/ATHERO_gummesson2025/sis_gummesson2025_hg38.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = 24811),
  list(name = "Coronary artery calcification (Kavousi 2023)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/CAC_kavousi2023/cac_kavousi2023_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL),
  list(name = "Venous thromboembolism (Thibord 2022)",
       file = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/NON_UKBiobank/VTE_thibord2022/VTE_thibord2022_hg38.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.16, n_manual = NULL),
  list(name = "BMI (Locke 2015)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/BODY_giant/bmi_locke2015_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL),
  list(name = "WHRadjBMI (Shungin 2015)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/BODY_giant/whradjBMI_shungin2015_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL),
  list(name = "Type 2 diabetes (Mahajan 2018)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/T2DM_mahajan2018/t2dm_mahajan2018_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.10, n_cases_manual = 72209, n_controls_manual = 400308),
  list(name = "Chronic kidney disease (Wuttke 2019)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/CKD_wuttke2019/CKD_wuttke2019_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.14, n_manual = NULL),
  list(name = "Kidney function / eGFR (Wuttke 2019)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/CKD_wuttke2019/eGFR_wuttke2019_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL),
  list(name = "Smoking (Liu 2019)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/HABITS_liu2019/cigpday_liu2019_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL),
  list(name = "Alcohol consumption (Liu 2019)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/HABITS_liu2019/drinkspweek_liu2019_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL),
  list(name = "HDL cholesterol (Graham 2021)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/LIPIDS_graham2021/hdl_graham2021_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL),
  list(name = "LDL cholesterol (Graham 2021)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/LIPIDS_graham2021/ldl_graham2021_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL),
  list(name = "Non-HDL cholesterol (Graham 2021)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/LIPIDS_graham2021/nonhdl_graham2021_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL),
  list(name = "Total cholesterol (Graham 2021)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/LIPIDS_graham2021/tc_graham2021_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL),
  list(name = "Triglycerides (Graham 2021)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/LIPIDS_graham2021/tg_graham2021_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL)
)


# =============================================================================
# HELPERS
# =============================================================================

check_palindromic <- function(EA, NEA) {
  (EA == "T" & NEA == "A") | (EA == "A" & NEA == "T") |
  (EA == "G" & NEA == "C") | (EA == "C" & NEA == "G")
}

build_col_map <- function(dat) {
  list(
    rsid     = if ("rsID"      %in% names(dat)) "rsID"      else NULL,
    beta     = "BETA",
    se       = "SE",
    ea       = "EA",
    oa       = "NEA",
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
      if (!is.null(cfg$n_cases_manual)) { dat$N_CASE <- cfg$n_cases_manual; ts(sprintf("    N_CASE injected: %s", format(cfg$n_cases_manual, big.mark = ","))) }
    if (!"N_CONTROL" %in% names(dat) || all(is.na(dat$N_CONTROL)))
      if (!is.null(cfg$n_controls_manual)) { dat$N_CONTROL <- cfg$n_controls_manual; ts(sprintf("    N_CONTROL injected: %s", format(cfg$n_controls_manual, big.mark = ","))) }
    if ((!"N" %in% names(dat) || all(is.na(dat$N))) &&
        "N_CASE" %in% names(dat) && "N_CONTROL" %in% names(dat) &&
        !all(is.na(dat$N_CASE)) && !all(is.na(dat$N_CONTROL))) {
      dat$N <- dat$N_CASE + dat$N_CONTROL
      ts(sprintf("    N reconstructed: %s", format(dat$N[1], big.mark = ",")))
    }
  } else {
    n_val <- if (!is.null(cfg$n_total_manual)) cfg$n_total_manual else cfg$n_manual
    if (!"N" %in% names(dat) || all(is.na(dat$N)))
      if (!is.null(n_val)) { dat$N <- n_val; ts(sprintf("    N injected: %s", format(n_val, big.mark = ","))) }
  }
  dat
}

read_gwaslab <- function(path, min_eaf = NULL) {
  if (!file.exists(path)) stop("File not found: ", path)
  ts(sprintf("  Reading: %s", basename(path)))
  dt <- data.table::fread(path, data.table = FALSE)
  required <- c("SNPID", "CHR", "POS", "NEA", "EA", "BETA", "SE", "P")
  missing  <- setdiff(required, names(dt))
  if (length(missing) > 0) stop("Missing columns: ", paste(missing, collapse = ", "))
  if ("rsID" %in% names(dt))
    dt <- dt[!is.na(dt$rsID) & dt$rsID != "" & dt$rsID != ".", ]
  if (!is.null(min_eaf) && "EAF" %in% names(dt))
    dt <- dt[!is.na(dt$EAF) & dt$EAF >= min_eaf & dt$EAF <= (1 - min_eaf), ]
  ts(sprintf("    %s variants ready", format(nrow(dt), big.mark = ",")))
  dt
}


# =============================================================================
# 0. READ UNIVARIABLE RESULTS (for comparison in output)
# =============================================================================

ts("═══ Reading univariable MR results (for reference) ═══")

uni_results_file <- file.path(OUTDIR_UNI, "FINAL_MR_primary.tsv")
uni_results <- if (file.exists(uni_results_file)) {
  tbl <- fread(uni_results_file, data.table = FALSE)
  ts(sprintf("  Loaded %d univariable primary results", nrow(tbl)))
  tbl
} else {
  ts("  ⚠ No univariable results found — continuing without")
  NULL
}


# =============================================================================
# 1. DEFINE MVMR GROUPS
# =============================================================================

mvmr_groups <- list(

  # ── GROUPE 1 : HTN + Lipides → cSVD ───────────────────────────
  # HTN, TG, HDL tous sig pour WMH et PVS
  # LDL inclus car corrélé génétiquement avec TG/HDL
  # Question : chacun a-t-il un effet DIRECT indépendant ?
  list(
    name = "HTN_Lipids_LDL_HDL_TG",
    exposure_names = c(
      "HTN (Verma 2024)",
      "LDL cholesterol (Graham 2021)",
      "HDL cholesterol (Graham 2021)",
      "Triglycerides (Graham 2021)"
    )
  ),

  # ── GROUPE 2 : HTN + TG → PVS ─────────────────────────────────
  # Seuls 2 sig pour PVS — tester avec modèle simple
  list(
    name = "HTN_TG",
    exposure_names = c(
      "HTN (Verma 2024)",
      "Triglycerides (Graham 2021)"
    )
  ),

  # ── GROUPE 3 : HTN + AF → WMH ─────────────────────────────────
  # AF et HTN corrélés (HTN → remodelage → AF)
  # Question : AF a-t-il un effet direct sur WMH indépendamment de HTN ?
  list(
    name = "HTN_AF",
    exposure_names = c(
      "HTN (Verma 2024)",
      "Atrial fibrillation (Yuan 2025)"
    )
  ),

  # ── GROUPE 4 : HTN + CAC → WMH Shiva ──────────────────────────
  # HTN cause l'athérosclérose
  # Question : CAC a-t-il un effet direct ou passe par HTN ?
  list(
    name = "HTN_CAC",
    exposure_names = c(
      "HTN (Verma 2024)",
      "Coronary artery calcification (Kavousi 2023)"
    )
  ),

  # ── GROUPE 5 : HTN + Carotid IMT → WMH Bianca ────────────────
  # Même logique que groupe 4 pour l'IMT carotidienne
  list(
    name = "HTN_CarotidIMT",
    exposure_names = c(
      "HTN (Verma 2024)",
      "Carotid atherosclerosis / IMT (Gummesson 2025)"
    )
  ),

  # ── GROUPE 6 : WMH + PVS → Ischaemic stroke ──────────────────
  # WMH et PVS tous deux sig pour ischaemic stroke
  # Marqueurs cSVD indépendants ou redondants ?
  list(
    name = "WMH_PVS_to_stroke",
    exposure_names = c(
      "WMH Shiva",
      "Perivascular spaces"
    )
  ),

  # ── GROUPE 7 : WMH + PVS → Small vessel stroke ────────────────
  list(
    name = "WMH_PVS_to_SVstroke",
    exposure_names = c(
      "WMH Bianca",
      "Perivascular spaces"
    )
  )
)


# =============================================================================
# 2. IDENTIFY WHICH GWAS FILES TO LOAD
# =============================================================================

ts("═══ Identifying GWAS files needed ═══")

# Build lookup: trait name → config
all_trait_cfgs <- c(exposures, csvd_traits)
trait_lookup   <- setNames(all_trait_cfgs, sapply(all_trait_cfgs, `[[`, "name"))

# All unique exposure names needed across all groups
needed_exposures <- unique(unlist(lapply(mvmr_groups, `[[`, "exposure_names")))
needed_outcomes  <- sapply(csvd_traits, `[[`, "name")

# Also need stroke outcomes for groups 6-7
stroke_outcomes <- list(
  list(name = "Ischaemic stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/ISCHAEMICstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.01, n_cases_manual = 59890, n_controls_manual = 865389),
  list(name = "Small vessel stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/SVstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.0025, n_cases_manual = 6811, n_controls_manual = 865389),
  list(name = "Any stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/ANYstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.015, n_cases_manual = 70720, n_controls_manual = 865389)
)

# Add stroke outcomes to the lookup and to the outcomes list for groups 6-7
for (s in stroke_outcomes) {
  trait_lookup[[s$name]] <- s
}

ts(sprintf("  Exposures needed : %d", length(needed_exposures)))
ts(sprintf("  Outcomes (cSVD)  : %d", length(needed_outcomes)))

# Check all exposure names exist
missing_defs <- setdiff(needed_exposures, names(trait_lookup))
if (length(missing_defs) > 0)
  stop("These exposure names are not defined in the traits list:\n  ",
       paste(missing_defs, collapse = "\n  "),
       "\n  → Check spelling matches exactly.")


# =============================================================================
# 3. LOAD GWAS DATA
# =============================================================================

ts("═══ Loading GWAS data ═══")

gwas_cache <- list()

load_trait <- function(trait_name) {
  if (trait_name %in% names(gwas_cache)) return(invisible(NULL))  # already loaded
  cfg <- trait_lookup[[trait_name]]
  ts(sprintf("  Loading : %s", trait_name))
  dat <- read_gwaslab(cfg$file, min_eaf = MIN_EAF)
  dat <- inject_n(dat, cfg)
  if (!"N" %in% names(dat) || all(is.na(dat$N))) {
    if ("N_CASE" %in% names(dat) && "N_CONTROL" %in% names(dat) &&
        !all(is.na(dat$N_CASE)) && !all(is.na(dat$N_CONTROL)))
      dat$N <- dat$N_CASE + dat$N_CONTROL
  }
  gwas_cache[[trait_name]] <<- list(gwas = dat, cfg = cfg)
  ts(sprintf("    ✓ %s variants", format(nrow(dat), big.mark = ",")))
}

# Load exposures
for (exp_name in needed_exposures) load_trait(exp_name)

# Load cSVD outcomes
for (out_name in needed_outcomes) load_trait(out_name)

# Load stroke outcomes (for groups 6-7)
for (s in stroke_outcomes) load_trait(s$name)

ts(sprintf("  %d GWAS datasets loaded", length(gwas_cache)))


# =============================================================================
# 4. DEFINE WHICH OUTCOMES TO TEST FOR EACH GROUP
# =============================================================================

# By default: each group is tested against all 4 cSVD outcomes
# Groups 6-7: also test against stroke outcomes

group_outcomes <- list()

for (group in mvmr_groups) {
  if (grepl("to_stroke|to_SVstroke", group$name)) {
    # cSVD → stroke groups: test against stroke outcomes
    group_outcomes[[group$name]] <- c(
      "Ischaemic stroke (Mishra 2022)",
      "Small vessel stroke (Mishra 2022)",
      "Any stroke (Mishra 2022)"
    )
  } else {
    # Standard groups: test against all 4 cSVD outcomes
    group_outcomes[[group$name]] <- needed_outcomes
  }
}


# =============================================================================
# 5. MVMR CORE FUNCTION
# =============================================================================

run_mvmr_group <- function(group, outcome_name) {

  group_name     <- group$name
  exposure_names <- group$exposure_names
  n_exp          <- length(exposure_names)

  if (!outcome_name %in% names(gwas_cache)) {
    ts(sprintf("    ✗ Outcome %s not loaded — skipping", outcome_name))
    return(NULL)
  }

  outcome_gwas <- gwas_cache[[outcome_name]]$gwas
  outcome_cfg  <- gwas_cache[[outcome_name]]$cfg
  outcome_cm   <- build_col_map(outcome_gwas)

  SEP <- paste(rep("─", 65), collapse = "")
  ts(SEP)
  ts(sprintf("  MVMR group [%s] → %s", group_name, outcome_name))
  ts(sprintf("  Exposures : %s", paste(exposure_names, collapse = " + ")))
  ts(SEP)

  # ── A. Select instruments per exposure ─────────────────────────────────
  #    Same filtering pipeline as univariable run_direction:
  #    1. GW-sig (p < 5e-8)
  #    2. Relaxed (p < 5e-6) if needed
  #    3. Availability filter (rsID match in outcome)
  #    4. Palindromic removal
  #    5. EAF filter
  #    6. F-statistic
  # ────────────────────────────────────────────────────────────────────────

  instrument_rsids <- list()
  f_stats_per_exp  <- list()

  for (exp_name in exposure_names) {
    eg  <- gwas_cache[[exp_name]]$gwas
    ecm <- build_col_map(eg)

    # ── 1. GW-sig SNPs ──────────────────────────────────────────────────
    pv  <- eg[[ecm$pval]]
    ivs <- eg[!is.na(pv) & pv < PVAL_IV, ]
    ts(sprintf("    [1-IV] %s : %d GW-sig (p < 5e-8)", exp_name, nrow(ivs)))

    # ── 2. Relaxed threshold if needed ──────────────────────────────────
    iv_relaxed <- FALSE
    if (nrow(ivs) < MIN_IVS) {
      ivs <- eg[!is.na(pv) & pv < 5e-6, ]
      iv_relaxed <- TRUE
      ts(sprintf("    [2-Relax] %s : relaxed to p < 5e-6 → %d SNPs", exp_name, nrow(ivs)))
    }

    if (nrow(ivs) < MIN_IVS) {
      ts(sprintf("    ✗ 0 instruments for %s — skipping group", exp_name))
      return(NULL)
    }

    # valid rsID
    if (!is.null(ecm$rsid))
      ivs <- ivs[!is.na(ivs[[ecm$rsid]]) & ivs[[ecm$rsid]] != "" & ivs[[ecm$rsid]] != ".", ]

    # ── 3. Availability filter (same as univariable) ────────────────────
    avail_rsid <- ivs[[ecm$rsid]] %in% outcome_gwas[[outcome_cm$rsid]]
    n_avail    <- sum(avail_rsid)
    n_missing  <- nrow(ivs) - n_avail

    ts(sprintf("    [3-Avail] %s : %d / %d found in outcome | %d missing (%.1f%%)",
               exp_name, n_avail, nrow(ivs), n_missing,
               100 * n_missing / max(nrow(ivs), 1)))

    if (n_avail < MIN_IVS) {
      ts(sprintf("    ✗ %s : only %d SNPs in outcome — skipping group", exp_name, n_avail))
      return(NULL)
    }

    ivs <- ivs[avail_rsid, ]

    # ── 4. Palindromic removal (same as univariable) ────────────────────
    ivs$is_palindromic <- check_palindromic(EA = ivs[[ecm$ea]], NEA = ivs[[ecm$oa]])
    n_palind <- sum(ivs$is_palindromic, na.rm = TRUE)
    ivs <- ivs[!is.na(ivs$is_palindromic) & !ivs$is_palindromic, ]

    ts(sprintf("    [4-Palindrome] %s : %d removed | %d remaining",
               exp_name, n_palind, nrow(ivs)))

    if (nrow(ivs) < MIN_IVS) {
      ts(sprintf("    ✗ %s : 0 SNPs after palindrome removal — skipping group", exp_name))
      return(NULL)
    }

    # ── 5. EAF filter ───────────────────────────────────────────────────
    if (!is.null(ecm$eaf) && ecm$eaf %in% names(ivs)) {
      n_before_eaf <- nrow(ivs)
      ivs <- ivs[!is.na(ivs[[ecm$eaf]]) &
                   ivs[[ecm$eaf]] >= MIN_EAF &
                   ivs[[ecm$eaf]] <= (1 - MIN_EAF), ]
      ts(sprintf("    [5-EAF] %s : %d removed | %d remaining",
                 exp_name, n_before_eaf - nrow(ivs), nrow(ivs)))
    }

    if (nrow(ivs) < MIN_IVS) {
      ts(sprintf("    ✗ %s : 0 SNPs after EAF filter — skipping group", exp_name))
      return(NULL)
    }

    # ── 6. F-statistic (same as univariable) ────────────────────────────
    f_all    <- (ivs[[ecm$beta]] / ivs[[ecm$se]])^2
    f_median <- round(median(f_all, na.rm = TRUE), 1)
    ts(sprintf("    [6-Fstat] %s : median = %.1f | min = %.1f | n(F<10) = %d | %d instruments",
               exp_name, f_median,
               min(f_all, na.rm = TRUE),
               sum(f_all < 10, na.rm = TRUE),
               nrow(ivs)))

    f_stats_per_exp[[exp_name]] <- list(
      f_median = f_median,
      f_min    = round(min(f_all, na.rm = TRUE), 1),
      n_weak   = sum(f_all < 10, na.rm = TRUE),
      n_ivs    = nrow(ivs),
      relaxed  = iv_relaxed
    )

    instrument_rsids[[exp_name]] <- unique(ivs[[ecm$rsid]])
  }

  # ── B. Pool all instrument rsIDs ───────────────────────────────────────
  pooled_snps <- unique(unlist(instrument_rsids))
  ts(sprintf("    [Pool] %d unique instrument SNPs (from %d exposures)",
             length(pooled_snps), n_exp))

  for (exp_name in exposure_names) {
    n_own    <- length(instrument_rsids[[exp_name]])
    n_unique <- sum(!instrument_rsids[[exp_name]] %in%
                      unlist(instrument_rsids[setdiff(exposure_names, exp_name)]))
    ts(sprintf("      %s : %d instruments (%d unique to this exposure)",
               exp_name, n_own, n_unique))
  }

  if (length(pooled_snps) < n_exp + 1) {
    ts(sprintf("    ✗ Only %d pooled SNPs — need > %d for %d exposures — skipping",
               length(pooled_snps), n_exp, n_exp))
    return(NULL)
  }

  # ── C. Look up ALL pooled SNPs in each exposure's FULL GWAS ────────────
  exposure_dats <- list()

  for (i in seq_along(exposure_names)) {
    exp_name <- exposure_names[i]
    eg       <- gwas_cache[[exp_name]]$gwas
    ecm      <- build_col_map(eg)

    exp_sub <- eg[eg[[ecm$rsid]] %in% pooled_snps, ]
    ts(sprintf("    [Lookup] %s : %d / %d pooled SNPs found in full GWAS",
               exp_name, nrow(exp_sub), length(pooled_snps)))

    if (nrow(exp_sub) < 3) {
      ts(sprintf("    ✗ Too few SNPs for %s — skipping group", exp_name))
      return(NULL)
    }

    eargs <- list(
      exp_sub, type = "exposure",
      snp_col           = ecm$rsid,
      beta_col          = ecm$beta,
      se_col            = ecm$se,
      effect_allele_col = ecm$ea,
      other_allele_col  = ecm$oa,
      pval_col          = ecm$pval
    )
    if (!is.null(ecm$eaf) && ecm$eaf %in% names(exp_sub))
      eargs$eaf_col <- ecm$eaf
    if (!is.null(ecm$n) && ecm$n %in% names(exp_sub))
      eargs$samplesize_col <- ecm$n
    if (!is.null(ecm$ncase) && ecm$ncase %in% names(exp_sub))
      eargs$ncase_col <- ecm$ncase
    if (!is.null(ecm$ncontrol) && ecm$ncontrol %in% names(exp_sub))
      eargs$ncontrol_col <- ecm$ncontrol

    exp_fmt <- tryCatch(do.call(format_data, eargs), error = function(e) {
      ts(sprintf("    ✗ format_data failed for %s : %s", exp_name, conditionMessage(e)))
      NULL
    })
    if (is.null(exp_fmt)) return(NULL)

    exp_fmt$id.exposure <- paste0("mvmr_", i)
    exp_fmt$exposure    <- exp_name

    exposure_dats[[i]] <- exp_fmt
  }

  # ── Align columns before rbind ─────────────────────────────────────────
  all_cols <- unique(unlist(lapply(exposure_dats, names)))
  exposure_dats <- lapply(exposure_dats, function(df) {
    missing_cols <- setdiff(all_cols, names(df))
    for (col in missing_cols) df[[col]] <- NA
    df[, all_cols, drop = FALSE]
  })
  combined_exp <- do.call(rbind, exposure_dats)

  ts(sprintf("    [Combined] %d rows | %d unique SNPs | %d exposures",
             nrow(combined_exp), length(unique(combined_exp$SNP)), n_exp))

  # ── D. Clump the pooled set ────────────────────────────────────────────
  clump_input <- combined_exp %>%
    group_by(SNP) %>%
    slice_min(pval.exposure, n = 1, with_ties = FALSE) %>%
    ungroup() %>%
    as.data.frame()

  clump_result <- tryCatch(
    clump_data(clump_input, clump_r2 = CLUMP_R2, clump_kb = CLUMP_KB, pop = "EUR"),
    error = function(e) {
      ts(sprintf("    ⚠ Clumping API failed : %s — using unclumped", conditionMessage(e)))
      clump_input
    }
  )

  clumped_snps <- unique(clump_result$SNP)
  ts(sprintf("    [Clump] %d → %d independent SNPs", length(pooled_snps), length(clumped_snps)))

  if (length(clumped_snps) < n_exp + 1) {
    ts(sprintf("    ✗ Need > %d SNPs for %d exposures — skipping", n_exp, n_exp))
    return(NULL)
  }

  combined_exp <- combined_exp[combined_exp$SNP %in% clumped_snps, ]

  # ── E. Format outcome ─────────────────────────────────────────────────
  out_sub <- outcome_gwas[outcome_gwas[[outcome_cm$rsid]] %in% clumped_snps, ]
  ts(sprintf("    [Outcome] %d / %d SNPs matched", nrow(out_sub), length(clumped_snps)))

  if (nrow(out_sub) < n_exp + 1) {
    ts("    ✗ Too few outcome SNPs — skipping")
    return(NULL)
  }

  oargs <- list(
    out_sub, type = "outcome",
    snp_col           = outcome_cm$rsid,
    beta_col          = outcome_cm$beta,
    se_col            = outcome_cm$se,
    effect_allele_col = outcome_cm$ea,
    other_allele_col  = outcome_cm$oa,
    pval_col          = outcome_cm$pval
  )
  if (!is.null(outcome_cm$eaf) && outcome_cm$eaf %in% names(out_sub))
    oargs$eaf_col <- outcome_cm$eaf
  if (!is.null(outcome_cm$n) && outcome_cm$n %in% names(out_sub))
    oargs$samplesize_col <- outcome_cm$n
  if (!is.null(outcome_cm$ncase) && outcome_cm$ncase %in% names(out_sub))
    oargs$ncase_col <- outcome_cm$ncase
  if (!is.null(outcome_cm$ncontrol) && outcome_cm$ncontrol %in% names(out_sub))
    oargs$ncontrol_col <- outcome_cm$ncontrol

  out_fmt <- tryCatch(do.call(format_data, oargs), error = function(e) {
    ts(sprintf("    ✗ Outcome format failed : %s", conditionMessage(e)))
    NULL
  })
  if (is.null(out_fmt)) return(NULL)
  out_fmt$outcome    <- outcome_name
  out_fmt$id.outcome <- "mvmr_outcome"

  # ── F. mv_harmonise_data ──────────────────────────────────────────────
  mvdat <- tryCatch(
    mv_harmonise_data(combined_exp, out_fmt, harmonise_strictness = 2),
    error = function(e) {
      ts(sprintf("    ✗ mv_harmonise_data failed : %s", conditionMessage(e)))
      NULL
    }
  )
  if (is.null(mvdat)) return(NULL)

  n_snps_final <- nrow(mvdat$exposure_beta)
  n_exp_final  <- ncol(mvdat$exposure_beta)
  ts(sprintf("    [Harmonised] %d SNPs × %d exposures", n_snps_final, n_exp_final))

  if (n_snps_final < n_exp_final + 1) {
    ts(sprintf("    ✗ Under-identified (%d SNPs for %d exposures) — skipping",
               n_snps_final, n_exp_final))
    return(NULL)
  }

  # ── G. Run MVMR (IVW, no intercept) ───────────────────────────────────
  ts("    Running mv_multiple (IVW) ...")
  mvmr_ivw <- tryCatch(
    mv_multiple(mvdat, intercept = FALSE),
    error = function(e) {
      ts(sprintf("    ✗ mv_multiple failed : %s", conditionMessage(e)))
      NULL
    }
  )

  if (is.null(mvmr_ivw) || is.null(mvmr_ivw$result) || nrow(mvmr_ivw$result) == 0) {
    ts("    ✗ No MVMR result")
    return(NULL)
  }

  # ── H. Run MVMR with intercept (Egger-like pleiotropy check) ──────────
  ts("    Running mv_multiple (with intercept = MVMR-Egger) ...")
  mvmr_egger <- tryCatch(
    mv_multiple(mvdat, intercept = TRUE),
    error = function(e) { ts("    ⚠ MVMR-Egger failed"); NULL }
  )

  # ── I. Annotate results ───────────────────────────────────────────────
  r <- mvmr_ivw$result
  r$group      <- group_name
  r$outcome    <- outcome_name
  r$n_snps     <- n_snps_final
  r$n_exp      <- n_exp_final
  r$exposures  <- paste(exposure_names, collapse = " + ")

  # ── F-stat info per exposure ───────────────────────────────────────────
  r$f_median          <- NA_real_
  r$f_min             <- NA_real_
  r$n_weak_instruments <- NA_integer_
  r$n_instruments      <- NA_integer_
  r$iv_relaxed         <- NA

  for (j in seq_len(nrow(r))) {
    exp_j <- r$exposure[j]
    if (exp_j %in% names(f_stats_per_exp)) {
      fs <- f_stats_per_exp[[exp_j]]
      r$f_median[j]           <- fs$f_median
      r$f_min[j]              <- fs$f_min
      r$n_weak_instruments[j] <- fs$n_weak
      r$n_instruments[j]      <- fs$n_ivs
      r$iv_relaxed[j]         <- fs$relaxed
    }
  }

  # ── Egger intercept ────────────────────────────────────────────────────
  r$mvmr_egger_intercept   <- NA_real_
  r$mvmr_egger_intercept_p <- NA_real_
  if (!is.null(mvmr_egger) && !is.null(mvmr_egger$result)) {
    tryCatch({
      eg_r <- mvmr_egger$result
      int_row <- eg_r[grepl("intercept", eg_r$exposure, ignore.case = TRUE), ]
      if (nrow(int_row) > 0) {
        r$mvmr_egger_intercept   <- int_row$b[1]
        r$mvmr_egger_intercept_p <- int_row$pval[1]
      }
    }, error = function(e) NULL)
  }

  # ── Compare with univariable IVW if available ─────────────────────────
  r$univariable_IVW_b    <- NA_real_
  r$univariable_IVW_pval <- NA_real_
  if (!is.null(uni_results)) {
    for (j in seq_len(nrow(r))) {
      exp_j <- r$exposure[j]
      out_j <- r$outcome[j]
      match_row <- uni_results[uni_results$Exposure == exp_j &
                                 uni_results$Outcome  == out_j, ]
      if (nrow(match_row) > 0) {
        bse <- match_row$IVW_Beta_SE[1]
        if (!is.na(bse)) {
          parts <- regmatches(bse, regexpr("^[-0-9.]+", bse))
          if (length(parts) > 0) r$univariable_IVW_b[j] <- as.numeric(parts)
        }
        r$univariable_IVW_pval[j] <- match_row$IVW_p_raw[1]
      }
    }
  }

  ts("    ✓ MVMR results:")
  print(r[, intersect(c("exposure", "outcome", "nsnp", "b", "se", "pval",
                         "n_snps", "group", "f_median", "n_instruments"),
                       names(r))])

  # ── J. Save per-group TSV ──────────────────────────────────────────────
  pfx <- file.path(OUTDIR_MVMR, sprintf("MVMR_%s__%s",
                                          clean_name(group_name),
                                          clean_name(outcome_name)))
  tryCatch({
    fwrite(r, paste0(pfx, "_results.tsv"), sep = "\t")
    ts(sprintf("    ✓ Saved → %s_results.tsv", basename(pfx)))
  }, error = function(e)
    ts(sprintf("    ⚠ Save failed : %s", conditionMessage(e))))

  r
}

  # ── XLSX ─────────────────────────────────────────────────────────────────
  if (HAS_XLSX) {

    wb <- openxlsx::createWorkbook()

    h_style <- openxlsx::createStyle(
      fontColour = "#FFFFFF", fgFill = "#2F5597",
      halign = "CENTER", textDecoration = "Bold", wrapText = TRUE)
    s_style <- openxlsx::createStyle(fgFill = "#E2EFDA")
    b_style <- openxlsx::createStyle(fgFill = "#FFD966")

    # ── All results sheet ──────────────────────────────────────────────────
    openxlsx::addWorksheet(wb, "All MVMR results")
    openxlsx::writeData(wb, "All MVMR results", mvmr_tbl, headerStyle = h_style)

    sig_rows  <- which(mvmr_tbl$sig_nominal & !mvmr_tbl$sig_bonferroni)
    bonf_rows <- which(mvmr_tbl$sig_bonferroni)

    if (length(sig_rows) > 0)
      openxlsx::addStyle(wb, "All MVMR results", style = s_style,
                         rows = sig_rows + 1, cols = seq_len(ncol(mvmr_tbl)),
                         gridExpand = TRUE)
    if (length(bonf_rows) > 0)
      openxlsx::addStyle(wb, "All MVMR results", style = b_style,
                         rows = bonf_rows + 1, cols = seq_len(ncol(mvmr_tbl)),
                         gridExpand = TRUE)

    openxlsx::setColWidths(wb, "All MVMR results",
                           cols = seq_len(ncol(mvmr_tbl)), widths = "auto")
    openxlsx::freezePane(wb, "All MVMR results", firstRow = TRUE)

    # ── Per-group sheets ───────────────────────────────────────────────────
    for (grp_name in unique(mvmr_tbl$group)) {
      sheet_name <- substr(grp_name, 1, 31)  # Excel max 31 chars
      grp_data   <- mvmr_tbl[mvmr_tbl$group == grp_name, ]
      openxlsx::addWorksheet(wb, sheet_name)
      openxlsx::writeData(wb, sheet_name, grp_data, headerStyle = h_style)

      sig_r  <- which(grp_data$sig_nominal & !grp_data$sig_bonferroni)
      bonf_r <- which(grp_data$sig_bonferroni)
      if (length(sig_r) > 0)
        openxlsx::addStyle(wb, sheet_name, style = s_style,
                           rows = sig_r + 1, cols = seq_len(ncol(grp_data)),
                           gridExpand = TRUE)
      if (length(bonf_r) > 0)
        openxlsx::addStyle(wb, sheet_name, style = b_style,
                           rows = bonf_r + 1, cols = seq_len(ncol(grp_data)),
                           gridExpand = TRUE)

      openxlsx::setColWidths(wb, sheet_name,
                             cols = seq_len(ncol(grp_data)), widths = "auto")
      openxlsx::freezePane(wb, sheet_name, firstRow = TRUE)
    }

    # ── Comparison sheet (MVMR vs univariable) ────────────────────────────
    if (any(!is.na(mvmr_tbl$univariable_IVW_b))) {
      comp <- mvmr_tbl[, intersect(
        c("group", "exposure", "outcome", "b", "se", "pval",
          "univariable_IVW_b", "univariable_IVW_pval",
          "n_snps", "mvmr_egger_intercept", "mvmr_egger_intercept_p"),
        names(mvmr_tbl)
      )]
      openxlsx::addWorksheet(wb, "MVMR vs Univariable")
      openxlsx::writeData(wb, "MVMR vs Univariable", comp, headerStyle = h_style)
      openxlsx::setColWidths(wb, "MVMR vs Univariable",
                             cols = seq_len(ncol(comp)), widths = "auto")
      openxlsx::freezePane(wb, "MVMR vs Univariable", firstRow = TRUE)
    }

    mvmr_final_xlsx <- file.path(OUTDIR_MVMR, "FINAL_MVMR_all_results.xlsx")
    openxlsx::saveWorkbook(wb, mvmr_final_xlsx, overwrite = TRUE)
    ts(sprintf("  MVMR XLSX → %s", mvmr_final_xlsx))
  }

  # ── Summary ──────────────────────────────────────────────────────────────
  ts("═══════════════════════════════════════════════════════════════")
  ts("  MVMR SUMMARY")
  ts("═══════════════════════════════════════════════════════════════")
  ts(sprintf("  Groups tested            : %d", length(mvmr_groups)))
  ts(sprintf("  Total group×outcome      : %d", N_MVMR_PAIRS))
  ts(sprintf("  Successful               : %d", length(mvmr_rows)))
  ts(sprintf("  Total result rows        : %d", nrow(mvmr_tbl)))
  ts(sprintf("  Significant (p < 0.05)   : %d",
             sum(mvmr_tbl$sig_nominal, na.rm = TRUE)))
  ts(sprintf("  Bonferroni (p < %.2e) : %d",
             bonf_mvmr, sum(mvmr_tbl$sig_bonferroni, na.rm = TRUE)))
  ts(sprintf("  Results → %s", OUTDIR_MVMR))

  # ── Print top hits ────────────────────────────────────────────────────────
  top <- head(mvmr_tbl[mvmr_tbl$sig_nominal == TRUE, ], 20)
  if (nrow(top) > 0) {
    ts("  ── Top MVMR hits (p < 0.05) ──")
    print(top[, intersect(c("group", "exposure", "outcome", "b", "se", "pval",
                             "n_snps", "sig_bonferroni"), names(top))])
  }

} else {
  ts("  ⚠ No MVMR results were produced")
}

ts("═══ MVMR script complete ═══")