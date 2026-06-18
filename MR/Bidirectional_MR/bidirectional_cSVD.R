library(TwoSampleMR)
library(data.table)
library(dplyr)
library(ggplot2)

HAS_RADIAL <- requireNamespace("RadialMR", quietly = TRUE)
HAS_XLSX   <- requireNamespace("openxlsx", quietly = TRUE)

proxy_url <- "http://proxy-icm:3128"
Sys.setenv(https_proxy = proxy_url)
httr::set_config(httr::use_proxy(url = proxy_url))
cat("Testing raw connection...\n")
resp <- httr::GET(
  "https://api.opengwas.io/api/status",
  httr::use_proxy(url = proxy_url),
  httr::timeout(30)
)
cat("Status code:", httr::status_code(resp), "\n")

Sys.setenv(OPENGWAS_JWT = "eyJhbGciOiJSUzI1NiIsImtpZCI6ImFwaS1qd3QiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJhcGkub3Blbmd3YXMuaW8iLCJhdWQiOiJhcGkub3Blbmd3YXMuaW8iLCJzdWIiOiJtYXJpbmUyODA2MDVAZ21haWwuY29tIiwiaWF0IjoxNzgwOTIyMDczLCJleHAiOjE3ODIxMzE2NzN9.BHvWnLOy7sIX2VU1E3jAySqSvt_VHROwrpG7i_uw3c_YHxEyz5v45ld9W_mvOPQLoqc-FuiCLyWrPYFo5QiUWAMQsfzK3t3YhFUpUYdjlbBfyMUC_9Sebmms2yMmK_uhvVSrjrJywxgtRKldj6t87ckZ6VNK57XIMFsRAL9H809Db_rc3sAhF31pfNe24wJ7Zy1NJiTBVfNIC8kfO8gbolfBmMWMjPR-5UI2_6jiijtHxPCsO7_QjO9ut10UadigjYHO17dhGjTj8K8Cag6p4UUv_dU9lk7FkrtsM_hVbKDC-WnjzgGt0S2DDyrc4ogc67IRhTmxgsLuATWpa1wV-A")
ieugwasr::get_opengwas_jwt()
ieugwasr::user()


# ── Paths ─────────────────────────────────────────────────────────────────────
OUTDIR <- "/network/iss/debette/users/marine.huang/MR/results"
 
files <- list.files(
  path       = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank",
  pattern    = "gwaslab\\.tsv\\.gz$",
  recursive  = TRUE,
  full.names = TRUE
)
files


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
       binary = TRUE, prev = 0.07, n_manual = NULL),

  list(name = "Perivascular spaces",
       file = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/UKBiobank/sumstats_shiva_total_pvs_ball_iint.tsv",
       binary = FALSE, prev = NULL, n_manual = NULL)
)


# ── Expositions ───────────────────────────────────────────────────────────────
exposures <- list(

  # ── Neuro ───────────────────────────────────────────────────────────────────
  list(name = "Alzheimer's disease (Nicolas 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/AD_nicolas2025/ad_nicolas2025_hg38.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.05, n_manual = NULL, primary_role = "outcome"),

  list(name = "Parkinson's disease (Leonard 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/PD_leonard2025/GP2_euro_ancestry_meta_analysis_2024/pd_leonard2025_hg38.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.001, primary_role = "outcome", n_cases_manual    = 34933,    
       n_controls_manual = 3100),

  list(name = "Major depressive disorder (Adams 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/MDD_adams2025/mdd_adams2025_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.05, n_manual = NULL, primary_role = "outcome"),

  # ── AVC / sous-types ────────────────────────────────────────────────────────
  list(name = "Cardioembolic stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/CEstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.002, n_cases_manual    = 8405,    
       n_controls_manual = 630246, primary_role = "outcome"),

  list(name = "Large artery stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/LAAstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.002,n_cases_manual    = 5873,    
       n_controls_manual = 630246, primary_role = "outcome"),

  list(name = "Small vessel stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/SVstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.0025, n_cases_manual    = 5976,    
       n_controls_manual = 630246, primary_role = "outcome"),

  # ── Cardio-vasculaire ────────────────────────────────────────────────────────
  list(name = "Atrial fibrillation (Yuan 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/AF_yuan2025/af_yuan2025_hg38.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.01, n_manual = NULL, primary_role = "exposure"),

  list(name = "Heart failure (Shah 2020)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/HF_shah2020/hf_shah2020_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.02, n_manual = NULL, primary_role = "exposure"),

  # ── Athérosclérose ──────────────────────────────────────────────────────────
  list(name = "Carotid atherosclerosis / IMT (Gummesson 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/ATHERO_gummesson2025/carotid_gummesson2025_hg38.gwaslab.tsv.gz",
       binary = FALSE, prev = 26807, n_manual = NULL, primary_role = "exposure"),

  list(name = "Coronary plaq (Gummesson 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/ATHERO_gummesson2025/sis_gummesson2025_hg38.gwaslab.tsv.gz",
       binary = FALSE, prev =24811, n_manual = NULL, primary_role = "exposure"),

  list(name = "Coronary artery calcification (Kavousi 2023)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/CAC_kavousi2023/cac_kavousi2023_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure"), #n dans le data set 

  # ── Métabolique ──────────────────────────────────────────────────────────────
  list(name = "BMI (Locke 2015)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/BODY_giant/bmi_locke2015_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL,
       primary_role = "exposure"),    # ← FIX 5 : primary_role ajouté

  list(name = "WHRadjBMI (Shungin 2015)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/BODY_giant/whradjBMI_shungin2015_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure"),

  list(name = "Type 2 diabetes (Mahajan 2018)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/T2DM_mahajan2018/t2dm_mahajan2018_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.10, n_cases_manual    = 36654,    
       n_controls_manual = 330433, primary_role = "exposure"),

  # ── Rein ─────────────────────────────────────────────────────────────────────
  list(name = "Chronic kidney disease (Wuttke 2019)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/CKD_wuttke2019/CKD_wuttke2019_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.14, n_manual = NULL, primary_role = "exposure"),

  list(name = "Kidney function / eGFR (Wuttke 2019)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/CKD_wuttke2019/eGFR_wuttke2019_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure"),

  # ── Toxines ──────────────────────────────────────────────────────────────────
  list(name = "Smoking (Liu 2019)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/HABITS_liu2019/cigpday_liu2019_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure"),

  list(name = "Alcohol consumption (Liu 2019)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/HABITS_liu2019/drinkspweek_liu2019_hg19.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = NULL, primary_role = "exposure"),

  # ── Lipides ──────────────────────────────────────────────────────────────────
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
MIN_IVS  <- 3;    MIN_EAF  <- 0.01
# ↑ FIX 3 : T2D_PREVALENCE supprimé (non utilisé — prévalence passée via exp_cfg$prev)

dir.create(OUTDIR, recursive = TRUE, showWarnings = FALSE)
ts <- function(...) message(format(Sys.time(), "[%H:%M:%S] "), ...)


# =============================================================================
# HELPERS
# =============================================================================

fmt_bse <- function(b, se, d = 4) {
  if (is.na(b) || is.na(se)) return(NA_character_)
  sprintf("%.*f (%.*f)", d, b, d, se)
}

fmt_p <- function(p) {
  if (is.null(p) || length(p) == 0) return(NA_character_)
  p <- p[1]
  if (is.na(p))  return(NA_character_)
  if (p < 0.001) formatC(p, format = "e", digits = 2)
  else           as.character(round(p, 3))
}

check_palindromic <- function(EA, NEA) {
  (EA == "T" & NEA == "A") |
  (EA == "A" & NEA == "T") |
  (EA == "G" & NEA == "C") |
  (EA == "C" & NEA == "G")
}

# ── FIX 4 : build_col_map — toutes les colonnes vérifiées avant assignation ──
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

# ── FIX 3 : inject_n — injecte le N dans le dataframe selon le type ──────────
inject_n <- function(dat, cfg) {

  if (isTRUE(cfg$binary)) {

    # N_CASE
    if (!"N_CASE" %in% names(dat) || all(is.na(dat$N_CASE))) {
      if (!is.null(cfg$n_cases_manual)) {
        dat$N_CASE <- cfg$n_cases_manual
        ts(sprintf("    N_CASE    (manuel) : %s",
                   format(cfg$n_cases_manual, big.mark = ",")))
      } else {
        ts(sprintf("    ⚠ [%s] N_CASE absent — Steiger utilisera get_r_from_pn", cfg$name))
      }
    }

    # N_CONTROL
    if (!"N_CONTROL" %in% names(dat) || all(is.na(dat$N_CONTROL))) {
      if (!is.null(cfg$n_controls_manual)) {
        dat$N_CONTROL <- cfg$n_controls_manual
        ts(sprintf("    N_CONTROL (manuel) : %s",
                   format(cfg$n_controls_manual, big.mark = ",")))
      } else {
        ts(sprintf("    ⚠ [%s] N_CONTROL absent — Steiger utilisera get_r_from_pn", cfg$name))
      }
    }

    # N total reconstruit
    if ((!"N" %in% names(dat) || all(is.na(dat$N))) &&
        "N_CASE" %in% names(dat) && "N_CONTROL" %in% names(dat) &&
        !all(is.na(dat$N_CASE)) && !all(is.na(dat$N_CONTROL))) {
      dat$N <- dat$N_CASE + dat$N_CONTROL
      ts(sprintf("    N total reconstruit : %s", format(dat$N[1], big.mark = ",")))
    }

  } else {

    # Trait continu : n_total_manual ou n_manual (rétrocompatibilité)
    n_val <- if (!is.null(cfg$n_total_manual)) cfg$n_total_manual else cfg$n_manual

    if (!"N" %in% names(dat) || all(is.na(dat$N))) {
      if (!is.null(n_val)) {
        dat$N <- n_val
        ts(sprintf("    N total   (manuel) : %s", format(n_val, big.mark = ",")))
      } else {
        ts(sprintf("    ⚠ [%s] N total absent — Steiger limité", cfg$name))
      }
    }
  }

  dat
}

# ── Sauvegarde XLSX incrémentale après chaque direction ───────────────────────
# Lit l'existant, ajoute la nouvelle ligne, réécrit.
# Robuste aux crashes : chaque direction est persistée immédiatement.
# Bonferroni = NA ici (N_TESTS inconnu) — mis à jour dans le tableau final.

append_to_xlsx <- function(row, xlsx_path) {

  if (!HAS_XLSX) return(invisible(NULL))

  tryCatch({

    # ── Lire le fichier existant ────────────────────────────────────────────
    tbl_inc <- if (file.exists(xlsx_path)) {
      tryCatch(
        openxlsx::read.xlsx(xlsx_path, sheet = "Results"),
        error = function(e) {
          ts(sprintf("  ⚠ XLSX incrémental illisible — réinitialisé (%s)",
                     conditionMessage(e)))
          NULL
        }
      )
    } else NULL

    # ── Fusionner ────────────────────────────────────────────────────────────
    if (!is.null(tbl_inc) && nrow(tbl_inc) > 0) {

      # Harmoniser les colonnes si make_row a évolué entre 2 sessions
      cols_new <- setdiff(names(row),     names(tbl_inc))
      cols_old <- setdiff(names(tbl_inc), names(row))
      for (col in cols_new) tbl_inc[[col]] <- NA
      for (col in cols_old) row[[col]]     <- NA
      row     <- row[, names(tbl_inc), drop = FALSE]
      tbl_inc <- rbind(tbl_inc, row)

    } else {
      tbl_inc <- row
    }

    # ── Styles ───────────────────────────────────────────────────────────────
    h_style <- openxlsx::createStyle(
      fontColour = "#FFFFFF", fgFill = "#2F5597",
      halign = "CENTER", textDecoration = "Bold", wrapText = TRUE
    )
    s_style <- openxlsx::createStyle(fgFill = "#E2EFDA")   # vert  p < 0.05

    # ── Construire le workbook ────────────────────────────────────────────────
    wb <- openxlsx::createWorkbook()
    openxlsx::addWorksheet(wb, "Results")
    openxlsx::writeData(wb, "Results", tbl_inc, headerStyle = h_style)

    sig_rows <- which(!is.na(tbl_inc$IVW_p_raw) & tbl_inc$IVW_p_raw < 0.05)
    if (length(sig_rows) > 0)
      openxlsx::addStyle(wb, "Results",
                         style      = s_style,
                         rows       = sig_rows + 1,
                         cols       = seq_len(ncol(tbl_inc)),
                         gridExpand = TRUE)

    openxlsx::setColWidths(wb, "Results",
                           cols   = seq_len(ncol(tbl_inc)),
                           widths = "auto")
    openxlsx::freezePane(wb, "Results", firstRow = TRUE)

    openxlsx::saveWorkbook(wb, xlsx_path, overwrite = TRUE)
    ts(sprintf("  ✓ XLSX incrémental : %d ligne(s) → %s",
               nrow(tbl_inc), basename(xlsx_path)))

  }, error = function(e) {
    ts(sprintf("  ! Erreur XLSX incrémental : %s — résultat préservé dans TSV",
               conditionMessage(e)))
  })
}

# ── FIX 2 : make_row déplacé ici — AVANT la boucle qui l'appelle ─────────────
make_row <- function(d, analysis_type = "primary", bonf_n = NA_integer_) {

  bonfp <- if (!is.na(d$ivw$pval) && !is.na(bonf_n)) {
    min(1, d$ivw$pval * bonf_n)
  } else NA_real_

  data.frame(
    Analysis_type              = analysis_type,
    Exposure                   = d$exposure,
    Outcome                    = d$outcome,
    N_SNPs                     = d$n_snps,
    F_statistic_median         = d$f_median,
    IVW_Beta_SE                = fmt_bse(d$ivw$b, d$ivw$se),
    IVW_p                      = fmt_p(d$ivw$pval),
    IVW_p_raw                  = d$ivw$pval,
    IVW_p_Bonferroni           = fmt_p(bonfp),
    Concordant_sensitivity     = d$concordant,
    Concordance_reason         = d$conc_reason,
    Q                          = round(d$het_Q, 2),
    Q_p                        = fmt_p(d$het_Qp),
    Egger_Beta_SE              = fmt_bse(d$eg$b, d$eg$se),
    Egger_Beta_p               = fmt_p(d$eg$pval),
    Egger_Intercept            = round(d$eg_int,    5),
    Egger_Intercept_SE         = round(d$eg_int_se, 5),
    Egger_Intercept_p          = fmt_p(d$eg_int_p),
    Egger_Heterogeneity_p      = fmt_p(d$eg_het_p),
    WM_Beta_SE                 = fmt_bse(d$wm$b, d$wm$se),
    WM_p                       = fmt_p(d$wm$pval),
    RadialMR_IVW_Beta_SE       = fmt_bse(d$rad$b, d$rad$se),
    RadialMR_IVW_p             = fmt_p(d$rad$pval),
    RadialMR_N_SNPs_used       = d$rad$nsnp,
    RadialMR_N_outliers        = d$rad$n_out,
    Steiger_correct_direction  = d$stg_dir,
    Steiger_p                  = fmt_p(d$stg_pval),
    stringsAsFactors = FALSE
  )
}


read_gwaslab <- function(path, min_eaf = NULL, verbose = TRUE) {

  if (!file.exists(path)) stop("File not found: ", path)

  ts(sprintf("  Reading: %s", basename(path)))
  dt <- data.table::fread(path, data.table = FALSE)
  ts(sprintf("  Loaded  : %s variants  |  %d columns",
             format(nrow(dt), big.mark = ","), ncol(dt)))

  if (verbose)
    ts(sprintf("  Columns : %s", paste(names(dt), collapse = ", ")))

  required <- c("SNPID", "CHR", "POS", "NEA", "EA", "BETA", "SE", "P")
  missing  <- setdiff(required, names(dt))
  if (length(missing) > 0)
    stop("Missing required gwaslab columns: ", paste(missing, collapse = ", "),
         "\n  Found: ", paste(names(dt), collapse = ", "))

  n0 <- nrow(dt)

  if ("rsID" %in% names(dt)) {
    dt <- dt[!is.na(dt$rsID) & dt$rsID != "" & dt$rsID != ".", ]
    if (verbose)
      ts(sprintf("  rsID filter          : %s removed  (%s remaining)",
                 format(n0 - nrow(dt), big.mark = ","),
                 format(nrow(dt),      big.mark = ",")))
    n0 <- nrow(dt)
  }

  if (!is.null(min_eaf) && "EAF" %in% names(dt)) {
    n_before <- nrow(dt)
    dt <- dt[!is.na(dt$EAF) & dt$EAF >= min_eaf & dt$EAF <= (1 - min_eaf), ]
    if (verbose)
      ts(sprintf("  EAF filter [%.2f-%.2f] : %d removed  (%d remaining)",
                 min_eaf, 1 - min_eaf, n_before - nrow(dt), nrow(dt)))
    n0 <- nrow(dt)
  }

  ts(sprintf("  Final               : %s variants ready for MR",
             format(nrow(dt), big.mark = ",")))
  dt
}


run_radial <- function(dat) {
  empty <- list(b = NA_real_, se = NA_real_, pval = NA_real_,
                nsnp = NA_integer_, n_out = 0L)

  if (!HAS_RADIAL || nrow(dat) < 4) return(empty)

  tryCatch({
    if (any(is.na(dat$beta.exposure)) || any(is.na(dat$beta.outcome)) ||
        any(is.na(dat$se.exposure))   || any(is.na(dat$se.outcome))) {
      ts("  RadialMR: NA values in beta/se — skipping")
      return(empty)
    }

    ri <- RadialMR::format_radial(
      BXG = dat$beta.exposure, BYG = dat$beta.outcome,
      seBXG = dat$se.exposure, seBYG = dat$se.outcome,
      RSID = dat$SNP
    )

    if (is.null(ri) || nrow(ri) == 0) {
      ts("  RadialMR: format_radial retourné vide — skipping")
      return(empty)
    }

    out <- RadialMR::ivw_radial(ri, alpha = 0.05, weights = 3)

    if (is.null(out$outliers) || nrow(out$outliers) == 0) {
      ts("  RadialMR: 0 outliers — primary IVW stands")
      return(modifyList(empty, list(nsnp = nrow(dat), n_out = 0L)))
    }

    bad      <- as.character(out$outliers$SNP)
    ts(sprintf("  RadialMR: %d outlier(s): %s", length(bad), paste(bad, collapse = ", ")))

    clean_dat <- dat[!dat$SNP %in% bad, ]   # ← FIX 6 : renommé clean → clean_dat
    if (nrow(clean_dat) < MIN_IVS) return(modifyList(empty, list(n_out = length(bad))))

    r2 <- mr(clean_dat, method_list = "mr_ivw")
    list(b = r2$b[1], se = r2$se[1], pval = r2$pval[1],
         nsnp = nrow(clean_dat), n_out = length(bad))

  }, error = function(e) { ts("  RadialMR error: ", conditionMessage(e)); empty })
}


check_concordance <- function(ivw_b, ivw_p, eg_b, eg_p, wm_b, wm_p, a = 0.05) {
  issues <- character(0)
  if (!is.na(ivw_p) && ivw_p < a) {
    if (!is.na(eg_b) && sign(eg_b) != sign(ivw_b))
      issues <- c(issues, "MR-Egger direction discordant")
    if (!is.na(wm_b) && sign(wm_b) != sign(ivw_b))
      issues <- c(issues, "Weighted median direction discordant")
    if (!is.na(wm_p) && wm_p >= a)
      issues <- c(issues, "Weighted median non-significant")
  }
  list(
    ok     = length(issues) == 0,
    reason = if (length(issues) == 0) "—" else paste(issues, collapse = "; ")
  )
}


# =============================================================================
# CORE FUNCTION
# =============================================================================

run_direction <- function(
    exp_gwas, out_gwas,
    exp_name,  out_name,
    ec, oc,
    exp_units      = "SD",
    out_units      = "log odds",
    exp_binary     = FALSE,
    out_binary     = FALSE,
    exp_prevalence = NULL,
    out_prevalence = NULL
) {
  SEP <- paste(rep("─", 62), collapse = "")
  ts(SEP); ts("  ", exp_name, "  →  ", out_name); ts(SEP)

  if (exp_binary && is.null(exp_prevalence))
    stop("exp_prevalence required when exp_binary = TRUE")
  if (out_binary && is.null(out_prevalence))
    stop("out_prevalence required when out_binary = TRUE")

  # ── 1. Instrument selection ───────────────────────────────────────────────
  pv  <- exp_gwas[[ec$pval]]
  ivs <- exp_gwas[!is.na(pv) & pv < PVAL_IV, ]
  ts(sprintf("  GW-sig (p < 5e-8): %d SNPs", nrow(ivs)))

  if (nrow(ivs) < MIN_IVS) {
    ivs <- exp_gwas[!is.na(pv) & pv < 1e-6, ]
    ts(sprintf("  Relaxed (p < 1e-6): %d SNPs", nrow(ivs)))
  }
  if (nrow(ivs) < MIN_IVS) { ts("  ✗ Not enough IVs — skipping"); return(NULL) }

  f_all    <- (ivs[[ec$beta]] / ivs[[ec$se]])^2
  f_median <- round(median(f_all, na.rm = TRUE), 1)
  ts(sprintf("  F-stat: median = %.1f | min = %.1f | n(F < 10) = %d",
             f_median, min(f_all, na.rm = TRUE), sum(f_all < 10, na.rm = TRUE)))

  # ── Availability filter ───────────────────────────────────────────────────
  ts("  Checking IV availability in outcome GWAS ...")
  avail_rsid <- ivs[[ec$rsid]] %in% out_gwas[[oc$rsid]]
  n_avail    <- sum(avail_rsid)
  n_missing  <- nrow(ivs) - n_avail

  ts(sprintf("  rsID match         : %d / %d SNPs found in outcome  |  %d missing (%.1f%%)",
             n_avail, nrow(ivs), n_missing, 100 * n_missing / nrow(ivs)))

  if (n_avail < MIN_IVS) {
    ts(sprintf("  ✗ Only %d SNPs available in outcome (< MIN_IVS = %d) — skipping",
               n_avail, MIN_IVS))
    return(NULL)
  }

  ivs <- ivs[avail_rsid, ]
  ts(sprintf("  %d SNPs retained → proceeding to palindrome removal", nrow(ivs)))

  # ── Remove palindromes ────────────────────────────────────────────────────
  ivs$is_palindromic <- check_palindromic(EA = ivs[[ec$ea]], NEA = ivs[[ec$oa]])
  n_palind <- sum(ivs$is_palindromic, na.rm = TRUE)
  ts(sprintf("  Palindrome  : %d palindromic SNPs in data set", n_palind))
  ivs <- ivs[!is.na(ivs$is_palindromic) & !ivs$is_palindromic, ]
  ts(sprintf("  %d SNPs retained after palindrome removal → proceeding to LD clumping", nrow(ivs)))

  if (nrow(ivs) < MIN_IVS) { ts("  ✗ Not enough IVs after palindrome removal"); return(NULL) }

  # ── 2. Format exposure ────────────────────────────────────────────────────
    eargs <- list(
    ivs, type = "exposure",
    snp_col           = ec$rsid,
    beta_col          = ec$beta,
    se_col            = ec$se,
    effect_allele_col = ec$ea,
    other_allele_col  = ec$oa,
    pval_col          = ec$pval
  )
  if (!is.null(ec$eaf)     && ec$eaf     %in% names(ivs)) eargs$eaf_col        <- ec$eaf
  if (!is.null(ec$n)       && ec$n       %in% names(ivs)) eargs$samplesize_col <- ec$n
  if (!is.null(ec$chr)     && ec$chr     %in% names(ivs)) eargs$chr_col        <- ec$chr
  if (!is.null(ec$pos)     && ec$pos     %in% names(ivs)) eargs$pos_col        <- ec$pos
  if (!is.null(ec$ncase)   && ec$ncase   %in% names(ivs)) eargs$ncase_col      <- ec$ncase
  if (!is.null(ec$ncontrol)&& ec$ncontrol%in% names(ivs)) eargs$ncontrol_col   <- ec$ncontrol

  exp_fmt          <- do.call(format_data, eargs)
  exp_fmt$exposure <- exp_name

  # ── 3. LD clumping ────────────────────────────────────────────────────────
  ts("  Clumping ...")
  exp_c <- tryCatch(
    clump_data(exp_fmt, clump_r2 = CLUMP_R2, clump_kb = CLUMP_KB, pop = "EUR"),
    error = function(e) { ts("  ! API clumping failed: ", conditionMessage(e)); exp_fmt }
  )
  ts(sprintf("  %d independent IVs after clumping", nrow(exp_c)))
  if (nrow(exp_c) < MIN_IVS) { ts("  ✗ Not enough IVs post-clump"); return(NULL) }

  # ── 4. Extract outcome SNPs ───────────────────────────────────────────────
  out_sub <- out_gwas[out_gwas[[oc$rsid]] %in% exp_c$SNP, ]
  ts(sprintf("  Outcome match: %d / %d by rsID", nrow(out_sub), nrow(exp_c)))

  if (!is.null(oc$chr) && nrow(out_sub) < 0.5 * nrow(exp_c)) {
    ts("  Trying chr:pos fallback ...")
    exp_cp <- paste0(sub("^chr", "", exp_c$chr.exposure), ":", exp_c$pos.exposure)
    out_cp <- paste0(sub("^chr", "", out_gwas[[oc$chr]]),  ":", out_gwas[[oc$pos]])
    idx    <- which(out_cp %in% exp_cp)
    if (length(idx) > nrow(out_sub)) {
      cpmap          <- setNames(exp_c$SNP, exp_cp)
      tmp            <- out_gwas[idx, ]
      tmp[[oc$rsid]] <- cpmap[out_cp[idx]]
      ts(sprintf("  Chr:pos matched %d IVs", nrow(tmp)))
      if (nrow(tmp) > nrow(out_sub)) out_sub <- tmp
    }
  }
  if (nrow(out_sub) < MIN_IVS) { ts("  ✗ Not enough IVs in outcome GWAS"); return(NULL) }

  # ── 5. Format outcome ─────────────────────────────────────────────────────
 oargs <- list(
    out_sub, type = "outcome",
    snp_col           = oc$rsid,
    beta_col          = oc$beta,
    se_col            = oc$se,
    effect_allele_col = oc$ea,
    other_allele_col  = oc$oa,
    pval_col          = oc$pval
  )
  if (!is.null(oc$eaf)     && oc$eaf     %in% names(out_sub)) oargs$eaf_col        <- oc$eaf
  if (!is.null(oc$n)       && oc$n       %in% names(out_sub)) oargs$samplesize_col <- oc$n
  if (!is.null(oc$chr)     && oc$chr     %in% names(out_sub)) oargs$chr_col        <- oc$chr
  if (!is.null(oc$pos)     && oc$pos     %in% names(out_sub)) oargs$pos_col        <- oc$pos
  if (!is.null(oc$ncase)   && oc$ncase   %in% names(out_sub)) oargs$ncase_col      <- oc$ncase
  if (!is.null(oc$ncontrol)&& oc$ncontrol%in% names(out_sub)) oargs$ncontrol_col   <- oc$ncontrol

  out_fmt         <- do.call(format_data, oargs)
  out_fmt$outcome <- out_name

  # ── 6. Harmonise ─────────────────────────────────────────────────────────
  ts(" Harmonising (action = 3) ...")
  dat    <- harmonise_data(exp_c, out_fmt, action = 3)
  dat_mr <- dat[dat$mr_keep, ]
  ts(sprintf("  Total: %d | Kept: %d | Removed: %d",
             nrow(dat), nrow(dat_mr), sum(!dat$mr_keep)))

  if (any(!dat$mr_keep)) {
    dat %>% filter(!mr_keep) %>%
      count(palindromic, ambiguous, remove) %>% print()
  }
  if (nrow(dat_mr) < MIN_IVS) { ts("  ✗ Not enough SNPs post-harmonisation"); return(NULL) }

  # ── 7. Steiger ────────────────────────────────────────────────────────────
  ts("  Steiger directionality test ...")

  if ("ncase.outcome" %in% names(dat_mr) &&
      sum(!is.na(dat_mr$ncase.outcome)) > 0 &&
      (!"samplesize.outcome" %in% names(dat_mr) ||
       all(is.na(dat_mr$samplesize.outcome)))) {
    dat_mr$samplesize.outcome <- dat_mr$ncase.outcome + dat_mr$ncontrol.outcome
    ts("  samplesize.outcome reconstruit depuis ncase + ncontrol ✓")
  }

  if ("ncase.exposure" %in% names(dat_mr) &&
      sum(!is.na(dat_mr$ncase.exposure)) > 0 &&
      (!"samplesize.exposure" %in% names(dat_mr) ||
       all(is.na(dat_mr$samplesize.exposure)))) {
    dat_mr$samplesize.exposure <- dat_mr$ncase.exposure + dat_mr$ncontrol.exposure
    ts("  samplesize.exposure reconstruit depuis ncase + ncontrol ✓")
  }

  compute_r <- function(beta, eaf, pval, n, ncase, ncontrol,
                        is_binary, prevalence, label) {
    n_snps <- length(beta)

    if (is_binary) {
      if (is.null(ncase) || all(is.na(ncase)) ||
          is.null(ncontrol) || all(is.na(ncontrol))) {
        ts(sprintf("  WARNING: %s is binary but ncase/ncontrol absent — falling back to get_r_from_pn", label))
        pval_c <- pmax(pmin(pval, 1 - 1e-15), 1e-300)
        n_c    <- pmax(n, 2L)
        r <- TwoSampleMR::get_r_from_pn(p = pval_c, n = n_c)
      } else {
        r <- TwoSampleMR::get_r_from_lor(
          lor = beta, af = eaf,
          ncase = ncase, ncontrol = ncontrol,
          prevalence = prevalence, model = "logit", correction = FALSE
        )
      }
    } else {
      if (is.null(n) || all(is.na(n))) {
        ts(sprintf("  WARNING: %s samplesize absent — r set to NA", label))
        return(rep(NA_real_, n_snps))
      }
      pval_c <- pmax(pmin(pval, 1 - 1e-15), 1e-300)
      n_c    <- pmax(n, 2L)
      r <- TwoSampleMR::get_r_from_pn(p = pval_c, n = n_c)
    }

    if (length(r) == 0 || length(r) != n_snps) {
      ts(sprintf("  WARNING: %s compute_r length mismatch — r set to NA", label))
      return(rep(NA_real_, n_snps))
    }
    pmin(pmax(r, -0.9999), 0.9999)
  }

  dat_mr$r.exposure <- compute_r(
    beta = dat_mr$beta.exposure, eaf = dat_mr$eaf.exposure,
    pval = dat_mr$pval.exposure, n   = dat_mr$samplesize.exposure,
    ncase    = if ("ncase.exposure"    %in% names(dat_mr)) dat_mr$ncase.exposure    else NULL,
    ncontrol = if ("ncontrol.exposure" %in% names(dat_mr)) dat_mr$ncontrol.exposure else NULL,
    is_binary = exp_binary, prevalence = exp_prevalence, label = exp_name
  )

  dat_mr$r.outcome <- compute_r(
    beta = dat_mr$beta.outcome, eaf = dat_mr$eaf.outcome,
    pval = dat_mr$pval.outcome, n   = dat_mr$samplesize.outcome,
    ncase    = if ("ncase.outcome"    %in% names(dat_mr)) dat_mr$ncase.outcome    else NULL,
    ncontrol = if ("ncontrol.outcome" %in% names(dat_mr)) dat_mr$ncontrol.outcome else NULL,
    is_binary = out_binary, prevalence = out_prevalence, label = out_name
  )

  ts(sprintf("  r.exposure: median = %.4f | NAs = %d  [%s]",
             median(dat_mr$r.exposure, na.rm = TRUE), sum(is.na(dat_mr$r.exposure)),
             if (exp_binary) "binary / get_r_from_lor" else "continuous / get_r_from_pn"))
  ts(sprintf("  r.outcome:  median = %.4f | NAs = %d  [%s]",
             median(dat_mr$r.outcome, na.rm = TRUE), sum(is.na(dat_mr$r.outcome)),
             if (out_binary) "binary / get_r_from_lor" else "continuous / get_r_from_pn"))

  dir_res <- tryCatch(
    directionality_test(dat_mr),
    error = function(e) { ts("  ! directionality_test failed: ", conditionMessage(e)); NULL }
  )

  safe_col <- function(df, col) {
    if (is.null(df) || nrow(df) == 0 || !col %in% names(df)) return(NA)
    v <- df[[col]][1]; if (length(v) == 0) NA else v
  }

  stg_dir  <- safe_col(dir_res, "correct_causal_direction")
  stg_pval <- safe_col(dir_res, "steiger_pval")
  ts(sprintf("  Steiger directionality: correct = %s | p = %s", stg_dir, fmt_p(stg_pval)))

  dat_use <- dat_mr

  # ── 8. Primary MR ─────────────────────────────────────────────────────────
  ts("  Running MR ...")
  res <- mr(dat_use, method_list = c(
    "mr_ivw",
    "mr_egger_regression",
    "mr_weighted_median"
  ))

  # ── 9. Heterogeneity & pleiotropy ─────────────────────────────────────────
  het   <- tryCatch(mr_heterogeneity(dat_use),  error = function(e) NULL)
  pleio <- tryCatch(mr_pleiotropy_test(dat_use), error = function(e) NULL)

  # ── 10. Radial MR ─────────────────────────────────────────────────────────
  ts("  Running Radial MR ...")
  rad <- run_radial(dat_use)

  # ── 11. Save per-direction outputs ────────────────────────────────────────
  pfx <- file.path(OUTDIR, sprintf("%s_to_%s",
    gsub("[^A-Za-z0-9]", "_", exp_name),
    gsub("[^A-Za-z0-9]", "_", out_name)))

  tryCatch({
    fwrite(dat_use, sprintf("%s_dat_mr.tsv",     pfx), sep = "\t")
    fwrite(res,     sprintf("%s_mr_results.tsv", pfx), sep = "\t")
    if (!is.null(dir_res)) fwrite(dir_res, sprintf("%s_steiger.tsv", pfx), sep = "\t")
    if (!is.null(het))     fwrite(het,     sprintf("%s_het.tsv",     pfx), sep = "\t")
    if (!is.null(pleio))   fwrite(pleio,   sprintf("%s_pleio.tsv",   pfx), sep = "\t")
    ts("  Fichiers sauvegardés ✓")
  }, error = function(e) ts("  ! Erreur sauvegarde : ", conditionMessage(e)))

  # ── 12. Plots ─────────────────────────────────────────────────────────────
  tryCatch({
    ht  <- max(6, nrow(dat_use) * 0.35 + 2)
    sng <- mr_singlesnp(dat_use)
    loo <- mr_leaveoneout(dat_use)
    ggsave(sprintf("%s_scatter.pdf", pfx), mr_scatter_plot(res, dat_use)[[1]], width = 8, height = 6)
    ggsave(sprintf("%s_forest.pdf",  pfx), mr_forest_plot(sng)[[1]],           width = 8, height = ht)
    ggsave(sprintf("%s_loo.pdf",     pfx), mr_leaveoneout_plot(loo)[[1]],      width = 8, height = ht)
    ggsave(sprintf("%s_funnel.pdf",  pfx), mr_funnel_plot(sng)[[1]],           width = 6, height = 6)
  }, error = function(e) ts("  ! Plot error: ", conditionMessage(e)))

  # ── 13. Extract results ───────────────────────────────────────────────────
  
  grp <- function(method_pattern) {
  # Correspondance partielle → insensible aux variations de version
  r <- res[grepl(method_pattern, res$method, ignore.case = TRUE), ]
  if (nrow(r) == 0) list(b = NA_real_, se = NA_real_, pval = NA_real_)
  else              list(b = r$b[1], se = r$se[1], pval = r$pval[1])
}

# Vérifier les noms réels dans res avant d'extraire
ts(sprintf("  Méthodes MR disponibles : %s", paste(res$method, collapse = " | ")))

ivw <- grp("Inverse variance weighted")  # capture toutes les variantes IVW
eg  <- grp("MR Egger")
wm  <- grp("Weighted median")

  hi <- if (!is.null(het)) het[het$method == "Inverse variance weighted", ] else NULL
  he <- if (!is.null(het)) het[het$method == "MR Egger", ]                  else NULL

  cc <- check_concordance(ivw$b, ivw$pval, eg$b, eg$pval, wm$b, wm$pval)

  list(
    exposure = exp_name,  outcome  = out_name,
    n_snps   = nrow(dat_use), f_median = f_median,
    ivw = ivw,
    het_Q  = if (!is.null(hi) && nrow(hi) > 0) hi$Q[1]      else NA_real_,
    het_Qp = if (!is.null(hi) && nrow(hi) > 0) hi$Q_pval[1] else NA_real_,
    eg = eg,
    eg_int    = if (!is.null(pleio)) pleio$egger_intercept[1] else NA_real_,
    eg_int_se = if (!is.null(pleio)) pleio$se[1]              else NA_real_,
    eg_int_p  = if (!is.null(pleio)) pleio$pval[1]            else NA_real_,
    eg_het_p  = if (!is.null(he) && nrow(he) > 0) he$Q_pval[1] else NA_real_,
    wm = wm, rad = rad,
    stg_dir = stg_dir, stg_pval = stg_pval,
    concordant = cc$ok, conc_reason = cc$reason
    # analysis_type ajouté par la boucle après l'appel
  )
}


# =============================================================================
# CHARGEMENT DES GWAS
# =============================================================================

# ── Traits cSVD ───────────────────────────────────────────────────────────────
ts("Loading all cSVD GWAS ...")
gwas_list <- list()

for (trait in csvd_traits) {
  ts(sprintf("  Loading %s ...", trait$name))

  dat <- read_gwaslab(trait$file, min_eaf = MIN_EAF)

  if (!"N" %in% names(dat)) {
    if ("N_CASE" %in% names(dat) && "N_CONTROL" %in% names(dat)) {
      dat$N <- dat$N_CASE + dat$N_CONTROL
      ts(sprintf("    N reconstruit : %d", dat$N[1]))
    } else if (!is.null(trait$n_manual)) {
      dat$N <- trait$n_manual
      ts(sprintf("    N manuel : %d", trait$n_manual))
    }
  }

  gwas_list[[trait$name]] <- list(gwas = dat, cfg = trait)
  ts(sprintf("    %d SNPs ✓", nrow(dat)))
}

csvd_loaded <- gwas_list   # alias utilisé par la boucle


# ── Expositions ───────────────────────────────────────────────────────────────
ts("Loading exposure GWAS ...")
exp_loaded <- list()

for (exp in exposures) {
  ts(sprintf("  Chargement : %s", exp$name))
  dat <- tryCatch(
    {
      d <- read_gwaslab(exp$file, min_eaf = MIN_EAF)
      d <- inject_n(d, exp)    # ← REMPLACE l'ancien bloc if/n_manual
      d
    },
    error = function(e) {
      ts(sprintf("  ✗ Échec chargement %s : %s", exp$name, conditionMessage(e)))
      NULL
    }
  )
  if (!is.null(dat)) {
    exp_loaded[[exp$name]] <- list(gwas = dat, cfg = exp)
    ts(sprintf("    %s SNPs ✓", format(nrow(dat), big.mark = ",")))
  }
}
ts(sprintf("  %d / %d expositions chargées", length(exp_loaded), length(exposures)))


# =============================================================================
# BOUCLE BIDIRECTIONNELLE
# =============================================================================

all_results         <- list()
result_rows         <- list()
out_tsv_incremental <- file.path(OUTDIR, "MR_results_incremental.tsv")
out_xlsx_incremental<- file.path(OUTDIR, "MR_results_incremental.xlsx")
header_written      <- FALSE
N_PAIRS             <- length(exp_loaded) * length(csvd_loaded)
pair_i              <- 0L
clean_name          <- function(s) gsub("[^A-Za-z0-9]", "_", s)

for (exp_item in exp_loaded) {

  exp_gwas <- exp_item$gwas
  exp_cfg  <- exp_item$cfg
  exp_cm   <- build_col_map(exp_gwas)

  for (csvd_item in csvd_loaded) {    # ← boucle interne OUVRE ici

    csvd_gwas <- csvd_item$gwas
    csvd_cfg  <- csvd_item$cfg
    csvd_cm   <- build_col_map(csvd_gwas)

    pair_i <- pair_i + 1L
    ts(sprintf("══ Paire %d / %d : %s ↔ %s ══",
               pair_i, N_PAIRS, exp_cfg$name, csvd_cfg$name))

    primary_role <- if (!is.null(exp_cfg$primary_role)) exp_cfg$primary_role else "exposure"
    type_A <- if (primary_role == "exposure") "primary"            else "sensitivity_reverse"
    type_B <- if (primary_role == "outcome")  "primary"            else "sensitivity_reverse"

    key_A <- sprintf("%s__to__%s", clean_name(exp_cfg$name),  clean_name(csvd_cfg$name))
    key_B <- sprintf("%s__to__%s", clean_name(csvd_cfg$name), clean_name(exp_cfg$name))

    # ── Direction A : exposition → cSVD ──────────────────────────────────
    ts(sprintf("  ── Direction A [%s] : %s → %s", type_A, exp_cfg$name, csvd_cfg$name))

    res_A <- tryCatch(
      run_direction(
        exp_gwas = exp_gwas, out_gwas = csvd_gwas,
        exp_name = exp_cfg$name,  out_name = csvd_cfg$name,
        ec = exp_cm,  oc = csvd_cm,
        exp_units      = if (isTRUE(exp_cfg$binary))  "log odds" else "SD",
        out_units      = if (isTRUE(csvd_cfg$binary)) "log odds" else "SD",
        exp_binary     = isTRUE(exp_cfg$binary),  exp_prevalence = exp_cfg$prev,
        out_binary     = isTRUE(csvd_cfg$binary), out_prevalence = csvd_cfg$prev
      ),
      error = function(e) {
        ts(sprintf("  ✗ Erreur direction A : %s", conditionMessage(e))); NULL
      }
    )

    if (!is.null(res_A)) res_A$analysis_type <- type_A
    all_results[[key_A]] <- res_A

    if (!is.null(res_A)) {
      row_A                <- make_row(res_A, analysis_type = type_A)
      result_rows[[key_A]] <- row_A
      data.table::fwrite(row_A, out_tsv_incremental,
                         sep = "\t", append = header_written, col.names = !header_written)
      header_written <- TRUE
      ts(sprintf("  ✓ TSV incrémental → %s", basename(out_tsv_incremental)))
      append_to_xlsx(row_A, out_xlsx_incremental)
    }

    # ── Direction B : cSVD → exposition ──────────────────────────────────
    # ↑ DOIT être ici, DANS la boucle interne, PAS après la fermeture }
    ts(sprintf("  ── Direction B [%s] : %s → %s", type_B, csvd_cfg$name, exp_cfg$name))

    res_B <- tryCatch(
      run_direction(
        exp_gwas = csvd_gwas, out_gwas = exp_gwas,
        exp_name = csvd_cfg$name, out_name = exp_cfg$name,
        ec = csvd_cm, oc = exp_cm,
        exp_units      = if (isTRUE(csvd_cfg$binary)) "log odds" else "SD",
        out_units      = if (isTRUE(exp_cfg$binary))  "log odds" else "SD",
        exp_binary     = isTRUE(csvd_cfg$binary), exp_prevalence = csvd_cfg$prev,
        out_binary     = isTRUE(exp_cfg$binary),  out_prevalence = exp_cfg$prev
      ),
      error = function(e) {
        ts(sprintf("  ✗ Erreur direction B : %s", conditionMessage(e))); NULL
      }
    )

    if (!is.null(res_B)) res_B$analysis_type <- type_B
    all_results[[key_B]] <- res_B

    if (!is.null(res_B)) {
      row_B                <- make_row(res_B, analysis_type = type_B)
      result_rows[[key_B]] <- row_B
      data.table::fwrite(row_B, out_tsv_incremental,
                         sep = "\t", append = TRUE, col.names = FALSE)
      ts(sprintf("  ✓ TSV incrémental → %s", basename(out_tsv_incremental)))
      append_to_xlsx(row_B, out_xlsx_incremental)
    }

  }   # ← boucle interne FERME ici (Direction B doit être AU-DESSUS de cette ligne)
}

ts(sprintf("══ Boucle terminée : %d directions lancées ══", length(all_results)))


# =============================================================================
# TABLEAU FINAL
# =============================================================================

valid_results <- Filter(Negate(is.null), all_results)
N_TESTS       <- length(valid_results)

ts(sprintf("  %d directions valides / %d lancées — N_TESTS (Bonferroni) = %d",
           N_TESTS, length(all_results), N_TESTS))

tbl <- do.call(rbind, lapply(names(valid_results), function(key) {
  d     <- valid_results[[key]]
  atype <- if (!is.null(d$analysis_type)) d$analysis_type else "unknown"
  make_row(d, analysis_type = atype, bonf_n = N_TESTS)   # bonf_n renseigné ici
}))

tbl <- tbl[order(tbl$Analysis_type != "primary", tbl$IVW_p_raw, na.last = TRUE), ]
rownames(tbl) <- NULL

# ── Export TSV ────────────────────────────────────────────────────────────────
out_tsv <- file.path(OUTDIR, "FINAL_bidirectional_MR_all_exposures.tsv")
fwrite(tbl, out_tsv, sep = "\t")
ts(sprintf("  TSV sauvegardé : %d lignes → %s", nrow(tbl), basename(out_tsv)))

tbl_primary     <- tbl[tbl$Analysis_type == "primary",             ]
tbl_sensitivity <- tbl[tbl$Analysis_type == "sensitivity_reverse", ]

fwrite(tbl_primary,     file.path(OUTDIR, "FINAL_MR_primary.tsv"),             sep = "\t")
fwrite(tbl_sensitivity, file.path(OUTDIR, "FINAL_MR_sensitivity_reverse.tsv"), sep = "\t")

ts(sprintf("  Primary     : %d lignes", nrow(tbl_primary)))
ts(sprintf("  Sensitivity : %d lignes", nrow(tbl_sensitivity)))


# ── Export XLSX ───────────────────────────────────────────────────────────────
if (HAS_XLSX) {

  wb <- openxlsx::createWorkbook()

  header_style <- openxlsx::createStyle(
    fontColour = "#FFFFFF", fgFill = "#2F5597",
    halign = "CENTER", textDecoration = "Bold", wrapText = TRUE
  )
  sig_style  <- openxlsx::createStyle(fgFill = "#E2EFDA")
  bonf_style <- openxlsx::createStyle(fgFill = "#FFD966")

  write_sheet <- function(wb, sheet_name, data) {
    if (nrow(data) == 0) {
      ts(sprintf("  ⚠ Feuille '%s' vide — non créée", sheet_name))
      return(invisible(NULL))
    }
    openxlsx::addWorksheet(wb, sheet_name)
    openxlsx::writeData(wb, sheet_name, data, headerStyle = header_style)

    bonf_thresh <- 0.05 / N_TESTS

    sig_rows  <- which(!is.na(data$IVW_p_raw) & data$IVW_p_raw < 0.05)
    if (length(sig_rows) > 0)
      openxlsx::addStyle(wb, sheet_name, style = sig_style,
                         rows = sig_rows + 1, cols = seq_len(ncol(data)), gridExpand = TRUE)

    bonf_rows <- which(!is.na(data$IVW_p_raw) & data$IVW_p_raw < bonf_thresh)
    if (length(bonf_rows) > 0)
      openxlsx::addStyle(wb, sheet_name, style = bonf_style,
                         rows = bonf_rows + 1, cols = seq_len(ncol(data)), gridExpand = TRUE)

    openxlsx::setColWidths(wb, sheet_name, cols = seq_len(ncol(data)), widths = "auto")
    openxlsx::freezePane(wb, sheet_name, firstRow = TRUE)

    ts(sprintf("  Feuille '%s' : %d lignes | %d sig (p<0.05) | %d Bonferroni (p<%.2e)",
               sheet_name, nrow(data), length(sig_rows), length(bonf_rows), bonf_thresh))
  }

  write_sheet(wb, "All results",           tbl)
  write_sheet(wb, "Primary",               tbl_primary)
  write_sheet(wb, "Sensitivity (reverse)", tbl_sensitivity)

  out_xlsx <- file.path(OUTDIR, "FINAL_bidirectional_MR_all_exposures.xlsx")
  openxlsx::saveWorkbook(wb, out_xlsx, overwrite = TRUE)
  ts(sprintf("  XLSX sauvegardé → %s", basename(out_xlsx)))

} else {
  ts("  ⚠ openxlsx non disponible — mamba install -c conda-forge r-openxlsx")
}


ts("═══ All done ═══")
ts(sprintf("  N total directions  : %d", length(all_results)))
ts(sprintf("  N valides           : %d", N_TESTS))
ts(sprintf("  N primary           : %d", nrow(tbl_primary)))
ts(sprintf("  N sensitivity       : %d", nrow(tbl_sensitivity)))
ts(sprintf("  Seuil Bonferroni    : %.2e", 0.05 / N_TESTS))
ts(sprintf("  Résultats → %s",  OUTDIR))