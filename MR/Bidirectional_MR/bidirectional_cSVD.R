library(TwoSampleMR)
library(data.table)
library(dplyr)
library(ggplot2)

HAS_RADIAL <- requireNamespace("RadialMR", quietly = TRUE)  #retourne true si le radialMR est installé sans le charger
HAS_XLSX   <- requireNamespace("openxlsx", quietly = TRUE) #retourne true si le xlsx est chargé 

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

Sys.setenv(OPENGWAS_JWT = "eyJhbGciOiJSUzI1NiIsImtpZCI6ImFwaS1qd3QiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJhcGkub3Blbmd3YXMuaW8iLCJhdWQiOiJhcGkub3Blbmd3YXMuaW8iLCJzdWIiOiJtYXJpbmUyODA2MDVAZ21haWwuY29tIiwiaWF0IjoxNzgxODcwNDY2LCJleHAiOjE3ODMwODAwNjZ9.EcIOvENBnWvBij9bz2N9SixPZq2vFaZ5tzW1S3nfnLiADlbZYeClStlT6G_Y_0M3dfPOK4Yy3RdJKNOjocUa_qt5CM25O2E0NVpXihdcyRJWZUWR0sm-62icQFls-FUkT1Ver28IHtPY0neuLiQT93_d_3WbPCpUlOBgKqRj4iKvaAp0X8sg_jU6nUP4JoDN_dFoCIXq3m_LsQfeMAfxHMy0Mis7fx7XPxFpzhL4uQVdj8V0tFeYH6u8xqcUCzU1X7VNUDFhfMUPt9XWp8Lsk-fHL4uWbb-iGtVK0XwD108i_hwSv0PF_v_i4Xv-zgKOPQJ9GQaBAQX2RgffHdfBXA")
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
       binary = TRUE, prev = 0.07, n_cases_manual    = NULL,n_controls_manual = NULL),

  list(name = "Perivascular spaces",
       file = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/UKBiobank/sumstats_shiva_total_pvs_ball_iint.tsv",
       binary = FALSE, prev = NULL, n_manual = NULL)
)


# ── Expositions ───────────────────────────────────────────────────────────────
exposures <- list(

  # ── Neuro ───────────────────────────────────────────────────────────────────
  list(name = "Alzheimer's disease (Nicolas 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/AD_nicolas2025/ad_nicolas2025_hg38.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.05,  n_cases_manual    = NULL,       n_controls_manual = NULL, primary_role = "outcome"),

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

 list(name = "Ischaemic stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/ISCHAEMICstroke_mishra2022_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.01 , n_cases_manual    = 47025,    
       n_controls_manual = 630246, primary_role = "outcome"),

 
 list(name = "Any stroke (Mishra 2022)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/ANYstroke_mishra2022_hg19.gwaslab.tsv.gz",
        binary = TRUE, prev =  0.015,  n_cases_manual   = 51018,    
       n_controls_manual = 630246, primary_role = "outcome"),


  # ── Cardio-vasculaire ────────────────────────────────────────────────────────
  list(name = "Atrial fibrillation (Yuan 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/AF_yuan2025/af_yuan2025_hg38.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.01, n_manual = NULL, primary_role = "exposure"),

  list(name = "Heart failure (Shah 2020)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/HF_shah2020/hf_shah2020_hg19.gwaslab.tsv.gz",
       binary = TRUE, prev = 0.02,  n_cases_manual    = NULL, n_controls_manual = NULL, primary_role = "exposure"),

  # ── Athérosclérose ──────────────────────────────────────────────────────────
  list(name = "Carotid atherosclerosis / IMT (Gummesson 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/ATHERO_gummesson2025/carotid_gummesson2025_hg38.gwaslab.tsv.gz",
       binary = FALSE, prev = NULL, n_manual = 26807, primary_role = "exposure"),

  list(name = "Coronary plaq (Gummesson 2025)",
       file = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/ATHERO_gummesson2025/sis_gummesson2025_hg38.gwaslab.tsv.gz",
       binary = FALSE, prev =NULL, n_manual = 24811, primary_role = "exposure"),

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
MIN_IVS  <- 1;    MIN_EAF  <- 0.01

dir.create(OUTDIR, recursive = TRUE, showWarnings = FALSE)
ts <- function(...) message(format(Sys.time(), "[%H:%M:%S] "), ...)


# =============================================================================
# HELPERS
# =============================================================================

fmt_bse <- function(b, se, d = 4) {
  if (is.null(b) || is.null(se)) return(NA_character_)
  b  <- suppressWarnings(as.numeric(b))
  se <- suppressWarnings(as.numeric(se))
  if (is.na(b) || is.na(se)) return(NA_character_)
  sprintf("%.*f (%.*f)", d, b, d, se)
} #Formate un beta et son erreur standard, avec d décimal 

fmt_p <- function(p) {
  if (is.null(p) || length(p) == 0) return(NA_character_)
  p <- suppressWarnings(as.numeric(p[1]))
  if (is.na(p))  return(NA_character_)
  if (p < 0.001) formatC(p, format = "e", digits = 2) #notation scientifique si < 0.001
  else           as.character(round(p, 3))
}


#fonctions qui gèrent les valeurs NULL, les vecteurs vides et les non-numériques, retournant NA_real_ en cas de problème.
safe_round <- function(x, digits) {
  if (is.null(x) || length(x) == 0) return(NA_real_)
  x <- suppressWarnings(as.numeric(x[1]))
  if (is.na(x)) return(NA_real_)
  round(x, digits)
}

safe_numeric <- function(x) {
  if (is.null(x) || length(x) == 0) return(NA_real_)
  x <- suppressWarnings(as.numeric(x[1]))
  if (is.na(x)) return(NA_real_)
  x
}

#permettent de retourner NA si les tests de pléiotropie et d'hétérogénéité n'ont pas pu être effectué 
safe_pleio <- function(pleio, col) {
  if (is.null(pleio) || !is.data.frame(pleio) || nrow(pleio) == 0) return(NA_real_)  # test échoué
  if (!col %in% names(pleio)) return(NA_real_) # format inattendu
  v <- pleio[[col]][1] # format inattendu
  if (is.null(v) || length(v) == 0) return(NA_real_)  # colonne absente
  suppressWarnings(as.numeric(v))
}

safe_het <- function(het, method_name, col) {
  if (is.null(het) || !is.data.frame(het) || nrow(het) == 0) return(NA_real_)
  het_sub <- het[grepl(method_name, het$method, ignore.case = TRUE), ]  # ← sub → het_sub
  if (nrow(het_sub) == 0 || !col %in% names(het_sub)) return(NA_real_)
  suppressWarnings(as.numeric(het_sub[[col]][1]))
}

check_palindromic <- function(EA, NEA) {
  (EA == "T" & NEA == "A") |
  (EA == "A" & NEA == "T") |
  (EA == "G" & NEA == "C") |
  (EA == "C" & NEA == "G")
}

#build_col_map permet à run_direction d'être une fonction générique qui fonctionne avec n'importe quel fichier GWAS dans les deux directions, sans jamais avoir à vérifier elle-même quelles colonnes existent.
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

       

      
#cfg = configuration du trait 
inject_n <- function(dat, cfg) {


  if (isTRUE(cfg$binary)) {

    if (!"N_CASE" %in% names(dat) || all(is.na(dat$N_CASE))) { #Vérifie si N_CASE est absent du fichier OU entièrement NA
      if (!is.null(cfg$n_cases_manual)) {   
        dat$N_CASE <- cfg$n_cases_manual #njecte la valeur manuelle dans toutes les lignes du dataframe si vide 
        ts(sprintf("    N_CASE    (manuel) : %s",
                   format(cfg$n_cases_manual, big.mark = ",")))
      } else {
        ts(sprintf("    ⚠ [%s] N_CASE absent", cfg$name)) #Si pas de valeur manuelle non plus → affiche un avertissement. 
      }
    }

    if (!"N_CONTROL" %in% names(dat) || all(is.na(dat$N_CONTROL))) {
      if (!is.null(cfg$n_controls_manual)) {
        dat$N_CONTROL <- cfg$n_controls_manual
        ts(sprintf("    N_CONTROL (manuel) : %s",
                   format(cfg$n_controls_manual, big.mark = ",")))
      } else {
        ts(sprintf("    ⚠ [%s] N_CONTROL absent", cfg$name))
      }
    } # Exactement la même logique que pour N_CASE, mais pour les contrôles.


    if ((!"N" %in% names(dat) || all(is.na(dat$N))) && #Si N total absent → le recalcule = cas + contrôles
        "N_CASE" %in% names(dat) && "N_CONTROL" %in% names(dat) && #et les colonnes case and control remplies 
        !all(is.na(dat$N_CASE)) && !all(is.na(dat$N_CONTROL))) { 
      dat$N <- dat$N_CASE + dat$N_CONTROL
      ts(sprintf("    N total reconstruit : %s", format(dat$N[1], big.mark = ",")))
    }

  } else {

    n_val <- if (!is.null(cfg$n_total_manual)) cfg$n_total_manual else cfg$n_manual
#si pas valeur de N 
    if (!"N" %in% names(dat) || all(is.na(dat$N))) {
      if (!is.null(n_val)) {
        dat$N <- n_val #injecte si valeur disponible, avertit sinon.
        ts(sprintf("    N total   (manuel) : %s", format(n_val, big.mark = ",")))
      } else {
        ts(sprintf("    ⚠ [%s] N total absent", cfg$name))
      }
    }
  }

  dat
}

# ── Sauvegarde XLSX incrémentale ──────────────────────────────────────────────
<<<<<<< HEAD
append_to_xlsx <- function(row, xlsx_path) { #Sauvegarde incrémentale, à chaque direction terminée, on ajoute une ligne au fichier Excel existant.
=======
#à chaque nouvelle direction MR analysée, ajoute une ligne sans recréer tout le fichier.


append_to_xlsx <- function(row, xlsx_path) { #Sauvegarde incrémentale
>>>>>>> 730430f (2026-06-22 13:13 - update)

  if (!HAS_XLSX) return(invisible(NULL))

  tryCatch({

    tbl_inc <- if (file.exists(xlsx_path)) {
      tryCatch(
        openxlsx::read.xlsx(xlsx_path, sheet = "Results"), # charge son contenu actuel.
        error = function(e) {
          ts(sprintf("  ⚠ XLSX incrémental illisible — réinitialisé (%s)",
                     conditionMessage(e)))
          NULL
        }
      )
    } else NULL

    if (!is.null(tbl_inc) && nrow(tbl_inc) > 0) {
      cols_new <- setdiff(names(row),     names(tbl_inc))
      cols_old <- setdiff(names(tbl_inc), names(row))
      for (col in cols_new) tbl_inc[[col]] <- NA
      for (col in cols_old) row[[col]]     <- NA
      row     <- row[, names(tbl_inc), drop = FALSE]
      tbl_inc <- rbind(tbl_inc, row) #ajoute la nouvelle ligne 
    } else {
      tbl_inc <- row
    }

    h_style <- openxlsx::createStyle(
      fontColour = "#FFFFFF", fgFill = "#2F5597",
      halign = "CENTER", textDecoration = "Bold", wrapText = TRUE
    )
    s_style <- openxlsx::createStyle(fgFill = "#E2EFDA") #Style pour les lignes significatives (p < 0.05) : fond vert clair.

    wb <- openxlsx::createWorkbook()
    openxlsx::addWorksheet(wb, "Results")
    openxlsx::writeData(wb, "Results", tbl_inc, headerStyle = h_style)

    sig_rows <- which(!is.na(tbl_inc$IVW_p_raw) & tbl_inc$IVW_p_raw < 0.05) #Identifie les lignes significatives (IVW p < 0.05) et applique le style vert. + 1 car la ligne 1 est l'en-tête.
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
    ts(sprintf("  ! Erreur XLSX incrémental : %s", conditionMessage(e)))
  })
}

# ── make_row   ──────────────────────────────────────────────
make_row <- function(d, analysis_type = "primary", bonf_n = NA_integer_) {
#Convertit les résultats d'une direction MR en une ligne de dataframe pour le tableau final.

#p-value Bonferroni = p × N_tests (plafonné à 1)
  bonfp <- tryCatch({
    p <- safe_numeric(d$ivw$pval)
    if (!is.na(p) && !is.na(bonf_n)) min(1, p * bonf_n) else NA_real_
  }, error = function(e) NA_real_) 


  data.frame(
    Analysis_type              = analysis_type, #primary or sensitive reverse 
    Exposure                   = d$exposure,
    Outcome                    = d$outcome,
    N_SNPs                     = d$n_snps,
    F_statistic_median         = d$f_median,
    IVW_Beta_SE                = fmt_bse(d$ivw$b,  d$ivw$se),
    IVW_p                      = fmt_p(d$ivw$pval),
    IVW_p_raw                  = safe_numeric(d$ivw$pval),
    IVW_p_Bonferroni           = fmt_p(bonfp),
    IVW_FE_Beta_SE             = fmt_bse(d$ivw_fe$b, d$ivw_fe$se),  
    IVW_FE_p                   = fmt_p(d$ivw_fe$pval),               
    IVW_FE_p_raw               = safe_numeric(d$ivw_fe$pval), 
    Concordant_sensitivity     = d$concordant,
    Concordance_reason         = d$conc_reason,
    Q                          = safe_round(d$het_Q,  2),
    Q_p                        = fmt_p(d$het_Qp),
    Egger_Beta_SE              = fmt_bse(d$eg$b,  d$eg$se),
    Egger_Beta_p               = fmt_p(d$eg$pval),
    Egger_Intercept            = safe_round(d$eg_int,    5),
    Egger_Intercept_SE         = safe_round(d$eg_int_se, 5),
    Egger_Intercept_p          = fmt_p(d$eg_int_p),
    Egger_Heterogeneity_p      = fmt_p(d$eg_het_p),
    WM_Beta_SE                 = fmt_bse(d$wm$b,  d$wm$se),
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

# ── Validate required gwaslab columns ─────────────────────────────────────

  required <- c("SNPID", "CHR", "POS", "NEA", "EA", "BETA", "SE", "P")
  missing  <- setdiff(required, names(dt))
  if (length(missing) > 0)
    stop("Missing required gwaslab columns: ", paste(missing, collapse = ", "))

  n0 <- nrow(dt)

  # ── rsID present and non-empty ────────────────────────────────────────────

  if ("rsID" %in% names(dt)) {
    dt <- dt[!is.na(dt$rsID) & dt$rsID != "" & dt$rsID != ".", ]
    if (verbose)
      ts(sprintf("  rsID filter          : %s removed  (%s remaining)",
                 format(n0 - nrow(dt), big.mark = ","),
                 format(nrow(dt),      big.mark = ",")))
    n0 <- nrow(dt)
  }

# ── EAF filter ──────────────────────────────────────────

  if (!is.null(min_eaf) && "EAF" %in% names(dt)) {
    n_before <- nrow(dt)
    dt <- dt[!is.na(dt$EAF) & dt$EAF >= min_eaf & dt$EAF <= (1 - min_eaf), ]
    if (verbose)
      ts(sprintf("  EAF filter [%.2f-%.2f] : %d removed  (%d remaining)",
                 min_eaf, 1 - min_eaf, n_before - nrow(dt), nrow(dt)))
  }

  ts(sprintf("  Final               : %s variants ready for MR",
             format(nrow(dt), big.mark = ",")))
  dt
}

# ── Radial MR: detect outliers via Cochran Q, re-run IVW without them ────────

run_radial <- function(dat) {
  empty <- list(b = NA_real_, se = NA_real_, pval = NA_real_,
                nsnp = NA_integer_, n_out = 0L)# liste vide que la fonction renverra si une étape échoue pour éviter que le pipeline plante en recevant un objet mal formé 
#dat =data.frame issu de harmonise_data () 

  if (!HAS_RADIAL || nrow(dat) < 4) return(empty) # si pas radial package ou moins de 4 SNPs → résultat non fiable, on ne commence pas le radial

  tryCatch({
    if (any(is.na(dat$beta.exposure)) || any(is.na(dat$beta.outcome)) ||
        any(is.na(dat$se.exposure))   || any(is.na(dat$se.outcome))) {
      ts("  RadialMR: NA values in beta/se — skipping")
      return(empty)
    }#si b ou se manquant dans exposure ou outcome, on arrête la fonction

    ri <- RadialMR::format_radial(
      BXG  = dat$beta.exposure, BYG  = dat$beta.outcome,
      seBXG = dat$se.exposure,  seBYG = dat$se.outcome,
      RSID  = dat$SNP
    )#formatage des noms des colonnes pour radial MR 



    if (is.null(ri) || nrow(ri) == 0) return(empty)  # ← vérifier que le formatage a bien fonctionné 

    out <- RadialMR::ivw_radial(ri, alpha = 0.05, weights = 3)
  #on effectue l'analyse radial MR 



# Étape 1 : identifier les outliers

    if (is.null(out$outliers) || nrow(out$outliers) == 0) {
      ts("  RadialMR: 0 outliers — primary IVW stands")
      return(modifyList(empty, list(nsnp = nrow(dat), n_out = 0L)))
    }

    bad       <- as.character(out$outliers$SNP)
    ts(sprintf("  RadialMR: %d outlier(s): %s", length(bad), paste(bad, collapse = ", ")))  # collapse = séparateur des rsID 


# Étape 2 : retirer les outliers

    clean_dat <- dat[!dat$SNP %in% bad, ]
    if (nrow(clean_dat) < MIN_IVS) return(modifyList(empty, list(n_out = length(bad))))


# Étape 3 : recalculer IVW sans les outliers

    r2 <- mr(clean_dat, method_list = "mr_ivw")  # re-run mr in twosampleMR for IVW after excluding outliers
    list(b = r2$b[1], se = r2$se[1], pval = r2$pval[1], #[1] on ne garde que le premier terme de chaque colonne (1ère méthode = ivW)
         nsnp = nrow(clean_dat), n_out = length(bad))

  }, error = function(e) { ts("  RadialMR error: ", conditionMessage(e)); empty })
}

# ── Concordance: do sensitivity analyses support the primary IVW? ─────────────

check_concordance <- function(ivw_b, ivw_p, eg_b, eg_p, wm_b, wm_p, a = 0.05) {
  issues <- character(0)

  ivw_b <- safe_numeric(ivw_b)
  ivw_p <- safe_numeric(ivw_p)
  eg_b  <- safe_numeric(eg_b)
  wm_b  <- safe_numeric(wm_b)
  wm_p  <- safe_numeric(wm_p)

   # ── MR-Egger ────────────────────────────────────────── #vérifie que MR-Egger a produit un résultat exploitable puis compare le signe de eg_b et ivw_b 

  if (!is.na(ivw_p) && ivw_p < a) {
    if (!is.na(eg_b) && !is.na(ivw_b) && sign(eg_b) != sign(ivw_b))
      issues <- c(issues, "MR-Egger direction discordant")
 
 # ── Weighted Median ─────────────────────────────────── # on  compare le signe de wm_b et ivw_b  

    if (!is.na(wm_b) && !is.na(ivw_b) && sign(wm_b) != sign(ivw_b))
      issues <- c(issues, "Weighted median direction discordant")
  }

  list(
    ok     = length(issues) == 0,
    reason = if (length(issues) == 0) "—" else paste(issues, collapse = "; ")
  )
}


# =============================================================================
# CORE FUNCTION: run one MR direction (last version)
#
# ec / oc : named lists of column mappings
#   Required: snp, beta, se, ea, oa, eaf, pval, n, chr, pos
#   Outcome only (optional): ncase, ncontrol
# =============================================================================

run_direction <- function(
    exp_gwas, out_gwas,
    exp_name,  out_name,
    ec, oc,
    exp_units      = "SD",
    out_units      = "log odds",
    exp_binary     = FALSE, # par défaut les 2 traits sont continus
    out_binary     = FALSE,
    exp_prevalence = NULL,
    out_prevalence = NULL
) {
  SEP <- paste(rep("─", 62), collapse = "")
  ts(SEP); ts("  ", exp_name, "  →  ", out_name); ts(SEP)
  #fabrique une ligne de séparation visuelle "----"


 # ── Validate binary/prevalence consistency ──────────────────────────────

  if (exp_binary && is.null(exp_prevalence))
    stop("exp_prevalence required when exp_binary = TRUE") # Si exposition binaire MAIS prévalence oubliée → arrêt immédiat avec message clair, si exp binary = TRUE et rien dans prevalence 
  if (out_binary && is.null(out_prevalence))
    stop("out_prevalence required when out_binary = TRUE")

  # ── 1. Instrument selection ───────────────────────────────────────────────
  pv  <- exp_gwas[[ec$pval]]
  ivs <- exp_gwas[!is.na(pv) & pv < PVAL_IV, ]
  ts(sprintf("  GW-sig (p < 5e-8): %d SNPs", nrow(ivs))) #on ne garde que les SNPS significatifs de l'exposure 


  if (nrow(ivs) < MIN_IVS) {
    ivs <- exp_gwas[!is.na(pv) & pv < 1e-6, ] # Si moins de 3 SNPs genome-wide significatifs → essaie un seuil plus souple de p value 
    ts(sprintf("  Relaxed (p < 1e-6): %d SNPs", nrow(ivs)))
  }
  if (nrow(ivs) < MIN_IVS) { ts("  ✗ Not enough IVs — skipping"); return(NULL) }

  f_all    <- (ivs[[ec$beta]] / ivs[[ec$se]])^2 # Calcule la F-statistique pour chaque SNP = mesure la force de chaque instrument
  f_median <- round(median(f_all, na.rm = TRUE), 1) #Calcule la médiane des F-stats — arrondie à 1 décimale, calculer une F‑stat pour chaque instrument (dans f_all), la médiane (force globale), la valeur minimale (instrument le plus faible), le nombre d’instruments avec F < 10 (instruments faibles),
  ts(sprintf("  F-stat: median = %.1f | min = %.1f | n(F < 10) = %d",
             f_median, min(f_all, na.rm = TRUE), sum(f_all < 10, na.rm = TRUE)))

  # ── Availability filter ───────────────────────────────────────────────────
  avail_rsid <- ivs[[ec$rsid]] %in% out_gwas[[oc$rsid]]  #Pour chaque SNP instrument — est-il présent dans l'outcome ? on prend les rsid de ivs (snps significatifs) qu'on vérifie dans les rsid de l'outcome 
  n_avail    <- sum(avail_rsid)   # Compte les SNPs disponibles 
  n_missing  <- nrow(ivs) - n_avail #on calcule le nb de SNPs retirés 


  ts(sprintf("  rsID match : %d / %d SNPs found  |  %d missing (%.1f%%)",
             n_avail, nrow(ivs), n_missing, 100 * n_missing / nrow(ivs)))

  if (n_avail < MIN_IVS) {
    ts(sprintf("  ✗ Only %d SNPs available (< MIN_IVS = %d) — skipping", n_avail, MIN_IVS))
    return(NULL)
  } #Si moins de 3 SNPs disponibles dans l'outcome → abandonne l'analyse 
 
  ivs <- ivs[avail_rsid, ] # crée un subgroupe et remplace ivs par ce subgroup qui ne garde que les SNPs présents dans l'outcome

  # ── Remove palindromes ────────────────────────────────────────────────────
  ivs$is_palindromic <- check_palindromic(EA = ivs[[ec$ea]], NEA = ivs[[ec$oa]])  #on crée is_palindromic dans ivs, on check les palindromes 

  n_palind <- sum(ivs$is_palindromic, na.rm = TRUE)
  ts(sprintf("  Palindrome : %d palindromic SNPs", n_palind))  #affiche les palindromes restants 
  ivs <- ivs[!is.na(ivs$is_palindromic) & !ivs$is_palindromic, ]

 

  if (nrow(ivs) < MIN_IVS) { ts("  ✗ Not enough IVs after palindrome removal"); return(NULL) }


           
# ── 2. Format exposure ────────────────────────────────────────────────────
 # snp_col MUST be rsID — the LD reference panel only recognises rsIDs, eargs = exposure arguments 
 # prépare les arguments pour format_data qui s'occupe de la mise en forme, à partir de la structure de ec. Pour dire quelle colonne contient les rsID,  quelles colonnes contiennent beta, SE, allèles, EAF, p‑valeurs, taille d’échantillon, etc.
 # ajouter éventuellement ncase/ncontrol pour un trait binaire,
# produire un objet exp_fmt bien étiqueté pour la suite des analyses MR (harmonisation, MR, Steiger, Radial, etc.).

  eargs <- list(
    ivs, type = "exposure",
    snp_col           = ec$rsid,
    beta_col          = ec$beta,
    se_col            = ec$se,
    effect_allele_col = ec$ea,
    other_allele_col  = ec$oa,
    pval_col          = ec$pval
  )
  if (!is.null(ec$eaf)     && ec$eaf      %in% names(ivs)) eargs$eaf_col        <- ec$eaf
  if (!is.null(ec$n)       && ec$n        %in% names(ivs)) eargs$samplesize_col <- ec$n
  if (!is.null(ec$chr)     && ec$chr      %in% names(ivs)) eargs$chr_col        <- ec$chr
  if (!is.null(ec$pos)     && ec$pos      %in% names(ivs)) eargs$pos_col        <- ec$pos
  if (!is.null(ec$ncase)   && ec$ncase    %in% names(ivs)) eargs$ncase_col      <- ec$ncase
  if (!is.null(ec$ncontrol)&& ec$ncontrol %in% names(ivs)) eargs$ncontrol_col   <- ec$ncontrol

  exp_fmt          <- do.call(format_data, eargs)
  exp_fmt$exposure <- exp_name # pour que les tables soient bien labellisées 

# ── 3. LD clumping (EUR 1000G, r² < 0.001, 10 000 kb) ────────────────────
  ts("  Clumping ...")
  exp_c <- tryCatch(
    clump_data(exp_fmt, clump_r2 = CLUMP_R2, clump_kb = CLUMP_KB, pop = "EUR"),
    error = function(e) { ts("  ! API clumping failed: ", conditionMessage(e)); exp_fmt } #Si l'API est inaccessible → affiche l'erreur et retourne tous les SNPs non clumpés
  )
  ts(sprintf("  %d independent IVs after clumping", nrow(exp_c)))
  if (nrow(exp_c) < MIN_IVS) { ts("  ✗ Not enough IVs post-clump"); return(NULL) }

  # ── 4. Extract outcome SNPs ───────────────────────────────────────────────
 # exp_c$SNP now contains rsIDs → match outcome on rsID column

  out_sub <- out_gwas[out_gwas[[oc$rsid]] %in% exp_c$SNP, ]  # ←  Cherche dans l'outcome GWAS les SNPs dont le rsID est dans exp_c$SNP, sachant qu'il est issu de exp_fmt qui contient ivs (clean, après filtrage matching)
  ts(sprintf("  Outcome match: %d / %d by rsID", nrow(out_sub), nrow(exp_c))) #Affiche combien de SNPs instruments ont été trouvés dans l'outcome

#Si la colonne chr existe ET moins de 50% des SNPs trouvés par rsID → essaie le fallback chr:pos

  if (!is.null(oc$chr) && nrow(out_sub) < 0.5 * nrow(exp_c)) {
    ts("  Trying chr:pos fallback ...")
    exp_cp <- paste0(sub("^chr", "", exp_c$chr.exposure), ":", exp_c$pos.exposure)  #Crée des identifiants chr:pos pour les instruments
    out_cp <- paste0(sub("^chr", "", out_gwas[[oc$chr]]),  ":", out_gwas[[oc$pos]]) #Crée les mêmes identifiants chr:pos pour l'outcome GWAS
    idx    <- which(out_cp %in% exp_cp)  # indices des lignes d’outcome dont le chr:pos correspond à un instrument

     # si ce fallback récupère plus d’IV que le match par rsID initial, on le remplace
    if (length(idx) > nrow(out_sub)) {
      cpmap          <- setNames(exp_c$SNP, exp_cp)
      tmp            <- out_gwas[idx, ]
      tmp[[oc$rsid]] <- cpmap[out_cp[idx]]
      if (nrow(tmp) > nrow(out_sub)) out_sub <- tmp
    }
  }
  if (nrow(out_sub) < MIN_IVS) { ts("  ✗ Not enough IVs in outcome GWAS"); return(NULL) }

# ── 5. Format outcome ─────────────────────────────────────────────────────

# prépare les arguments pour format_data qui s'occupe de la mise en forme, à partir de la structure de ec. Pour dire quelle colonne contient les rsID,  quelles colonnes contiennent beta, SE, allèles, EAF, p‑valeurs, taille d’échantillon, etc.
 # ajouter éventuellement ncase/ncontrol pour un trait binaire,
# produire un objet exp_fmt bien étiqueté pour la suite des analyses MR (harmonisation, MR, Steiger, Radial, etc.).

  oargs <- list(
    out_sub, type = "outcome",
    snp_col           = oc$rsid, # ← rsID, not SNPID
    beta_col          = oc$beta,
    se_col            = oc$se,
    effect_allele_col = oc$ea,
    other_allele_col  = oc$oa,
    pval_col          = oc$pval
  )
  if (!is.null(oc$eaf)     && oc$eaf      %in% names(out_sub)) oargs$eaf_col        <- oc$eaf
  if (!is.null(oc$n)       && oc$n        %in% names(out_sub)) oargs$samplesize_col <- oc$n
  if (!is.null(oc$chr)     && oc$chr      %in% names(out_sub)) oargs$chr_col        <- oc$chr
  if (!is.null(oc$pos)     && oc$pos      %in% names(out_sub)) oargs$pos_col        <- oc$pos
  if (!is.null(oc$ncase)   && oc$ncase    %in% names(out_sub)) oargs$ncase_col      <- oc$ncase
  if (!is.null(oc$ncontrol)&& oc$ncontrol %in% names(out_sub)) oargs$ncontrol_col   <- oc$ncontrol

  out_fmt         <- do.call(format_data, oargs) #appel la fonction format_data et rentre les arguments qu'on a inscrit dans la list 
  out_fmt$outcome <- out_name # label l'outcome pour les tableaux 

# ── 6. Harmonise (action=3:,exclude ambiguous palindromic MAF 0.42–0.58) ────────────
  ts("  Harmonising (action = 3) ...")
  dat    <- harmonise_data(exp_c, out_fmt, action = 3)
  dat_mr <- dat[dat$mr_keep, ] #mr_keep est un vecteur de la fonction harmonise data qui attribue à chaque SNP true or false à l'issue de l'harmonisation 
  ts(sprintf("  Total: %d | Kept: %d | Removed: %d",
             nrow(dat), nrow(dat_mr), sum(!dat$mr_keep)))  #non mr_keep sont retirés (!mr_keep)  

  if (nrow(dat_mr) < MIN_IVS) { ts("  ✗ Not enough SNPs post-harmonisation"); return(NULL) }

# ── 7. Steiger directionality test ──────────────────────────────────────
  ts("  Steiger directionality test ...")

 # Reconstruire samplesize si absent pour les traits binaires, si les colonnes existent et qu'elles ne sont pas vides 

  if ("ncase.outcome" %in% names(dat_mr) &&
      sum(!is.na(dat_mr$ncase.outcome)) > 0 &&
      (!"samplesize.outcome" %in% names(dat_mr) ||
       all(is.na(dat_mr$samplesize.outcome)))) {
    dat_mr$samplesize.outcome <- dat_mr$ncase.outcome + dat_mr$ncontrol.outcome
  }

  if ("ncase.exposure" %in% names(dat_mr) &&
      sum(!is.na(dat_mr$ncase.exposure)) > 0 &&
      (!"samplesize.exposure" %in% names(dat_mr) ||
       all(is.na(dat_mr$samplesize.exposure)))) {
    dat_mr$samplesize.exposure <- dat_mr$ncase.exposure + dat_mr$ncontrol.exposure
  }
  
   # ── Helper: compute r² (corrélation SNP-trait) contribution per SNP ─────────────────────────────

  compute_r <- function(beta, eaf, pval, n, ncase, ncontrol,
                        is_binary, prevalence, label) {
    n_snps <- length(beta)  # ← ajout nb de snps selon le nb de b 

    if (is_binary) { #is_binary issu de exp_binary défini dans traits (liste)
         # Binary trait: convert log-OR to r via liability-scale conversion
      if (is.null(ncase) || all(is.na(ncase)) ||
          is.null(ncontrol) || all(is.na(ncontrol))) {
        pval_c <- pmax(pmin(pval, 1 - 1e-15), 1e-300)
        n_c    <- pmax(n, 2L)
        r <- TwoSampleMR::get_r_from_pn(p = pval_c, n = n_c) #convertit p‑value + N en une corrélation $r$ approximative si absence de n_case et n_control
      } else { #si ncase et control disponibles, lor = log-odds ratio 
        r <- TwoSampleMR::get_r_from_lor(
          lor = beta, af = eaf,
          ncase = ncase, ncontrol = ncontrol,
          prevalence = prevalence, model = "logit", correction = FALSE
        )
      }
    } else {
           # Continuous trait (is_binary false): convert p + N to r
      if (is.null(n) || all(is.na(n))) {
        return(rep(NA_real_, n_snps))
      }
      pval_c <- pmax(pmin(pval, 1 - 1e-15), 1e-300)
      n_c    <- pmax(n, 2L)
      r <- TwoSampleMR::get_r_from_pn(p = pval_c, n = n_c) #on obtient r à partir du calcul par TWOSAMPLEMR
    }

    if (length(r) == 0 || length(r) != n_snps) return(rep(NA_real_, n_snps))
    pmin(pmax(r, -0.9999), 0.9999) # clamp/borner to valid correlation range
  }

#application pour les données exposure et outcome 

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

 # Steiger directionality test — 
  dir_res <- tryCatch(
    directionality_test(dat_mr),
    error = function(e) { ts("  ! directionality_test failed: ", conditionMessage(e)); NULL }
  )
#Fonction de sécurité : si dir_res est NULL, vide, ou sans la colonne demandée = retourne NA
# sinon, on prend la première valeur de cette colonne (dir_res)
  safe_col <- function(df, col) {
    if (is.null(df) || nrow(df) == 0 || !col %in% names(df)) return(NA)
    v <- df[[col]][1]; if (length(v) == 0) NA else v
  }

  stg_dir  <- safe_col(dir_res, "correct_causal_direction")
  stg_pval <- safe_col(dir_res, "steiger_pval")
  ts(sprintf("  Steiger: correct = %s | p = %s", stg_dir, fmt_p(stg_pval)))

  dat_use <- dat_mr

  # ── 8. Primary MR ─────────────────────────────────────────────────────────
  ts("  Running MR ...")
  res <- mr(dat_use, method_list = c(
    "mr_ivw",
    "mr_ivw_fe",
    "mr_egger_regression",
    "mr_weighted_median"
  ))

  # IVW = tous les instruments valides
# MR-Egger, intercept ≠ 0 → évidence de pléiotropie (INSIDE assumption = pléiotropie compensée ou indépendante de l'effet causal), si Q et Qf proches alors
# Weighted Median — méthode de sensibilité : 50% des instruments corrects


  ts(sprintf("  Méthodes MR disponibles : %s", paste(res$method, collapse = " | ")))

  # ── 9. Heterogeneity & pleiotropy ─────────────────────────────────────────
  het   <- tryCatch(mr_heterogeneity(dat_use),  error = function(e) { ts("  ⚠ Heterogeneity: ", conditionMessage(e)); NULL })

 # normalement les SNPs donnent un effet similaire (dépendant de si on considère le fixed effect ou le random effect model)
 # Q mesure l'hétérogénéité entre les SNPs instruments, si Q petit = effets similaires des SNPs
 # Q_df = nombre de SNPs - 1


  pleio <- tryCatch(mr_pleiotropy_test(dat_use), error = function(e) { ts("  ⚠ Pleiotropy: ",   conditionMessage(e)); NULL })

#Teste si l'intercept de MR-Egger est différent de 0 = pléiotropie directionnelle



  # ── 10. Radial MR ─────────────────────────────────────────────────────────
  ts("  Running Radial MR ...")
  rad <- run_radial(dat_use)
#détecte les SNPs outliers via Cochran Q, recalcule IVW sans les outliers, return b, se, pval, nsnp, n_out


  # ── 11. Save per-direction outputs ────────────────────────────────────────
  pfx <- file.path(OUTDIR, sprintf("%s_to_%s",
    gsub("[^A-Za-z0-9]", "_", exp_name),
    gsub("[^A-Za-z0-9]", "_", out_name)))

#créer le préfixe, utilisé pour tous les noms de fichiers de résultats pour cette direction 
# exposure to outcome préfixe 
#remplace tous les caractères non alphanumériques par _ pour avoir un nom de fichier sûr (pas d’espace, pas de parenthèse, etc.).

#Écrit des données dans un fichier

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
    r <- res[grepl(method_pattern, res$method, ignore.case = TRUE), ]
    if (nrow(r) == 0) list(b = NA_real_, se = NA_real_, pval = NA_real_)
    else              list(b = r$b[1],   se = r$se[1],  pval = r$pval[1])
  }#Fonction locale — extrait b, se, pval pour une méthode donnée, si méthode absente → retourne NA, si présente → retourne les valeurs
#res = résultat de la MR 

  ivw <- grp("Inverse variance weighted")
  ivw_fe <- grp("fixed effects")   
  eg  <- grp("MR Egger")
  wm  <- grp("Weighted median")
 #Extrait les résultats des 4 méthodes

  cc <- check_concordance(ivw$b, ivw$pval, eg$b, eg$pval, wm$b, wm$pval)

  list(
    exposure = exp_name,  outcome  = out_name,
    n_snps   = nrow(dat_use), f_median = f_median,
    ivw = ivw,
    ivw_fe = ivw_fe,
    het_Q  = safe_het(het,  "Inverse variance weighted", "Q"),
    het_Qp = safe_het(het,  "Inverse variance weighted", "Q_pval"),
    eg = eg,
    eg_int    = safe_pleio(pleio, "egger_intercept"),   # ← sécurisé
    eg_int_se = safe_pleio(pleio, "se"),                # ← sécurisé
    eg_int_p  = safe_pleio(pleio, "pval"),              # ← sécurisé
    eg_het_p  = safe_het(het, "MR Egger", "Q_pval"),
    wm = wm, rad = rad,
    stg_dir = stg_dir, stg_pval = stg_pval,
    concordant = cc$ok, conc_reason = cc$reason
  )
}


# =============================================================================
# CHARGEMENT DES GWAS
# =============================================================================

ts("Loading all cSVD GWAS ...")
gwas_list <- list()

for (trait in csvd_traits) {
  ts(sprintf("  Loading %s ...", trait$name))
  dat <- read_gwaslab(trait$file, min_eaf = MIN_EAF) #filtre les variants avec EAF < 0.01 ou > 0.99

  if (!"N" %in% names(dat)) { #Vérifie si la colonne N total est absente du fichier (certains fichiers cSVD ne la contiennent pas).
    if ("N_CASE" %in% names(dat) && "N_CONTROL" %in% names(dat)) { #Si N_CASE et N_CONTROL existent → calcule N total = cas + contrôles.
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

for (exp in exposures) { #Itère sur chacune des expositions définies (BMI, lipides, stroke, etc.).
  ts(sprintf("  Chargement : %s", exp$name)) #Affiche le nom de l'exposition en cours.
  dat <- tryCatch({
    d <- read_gwaslab(exp$file, min_eaf = MIN_EAF) #Lit le fichier GWAS de l'exposition avec filtre EAF.
    d <- inject_n(d, exp) #Injecte les effectifs manquants (N_CASE, N_CONTROL, N) depuis la configuration manuelle si nécessaire.
    d
  }, error = function(e) {
    ts(sprintf("  ✗ Échec chargement %s : %s", exp$name, conditionMessage(e)))
    NULL
  })
  if (!is.null(dat)) {
    exp_loaded[[exp$name]] <- list(gwas = dat, cfg = exp) # stocke dans exp_loaded sous la clé exp$name. 
    ts(sprintf("    %s SNPs ✓", format(nrow(dat), big.mark = ",")))
  }
}
ts(sprintf("  %d / %d expositions chargées", length(exp_loaded), length(exposures)))


# =============================================================================
# BOUCLE BIDIRECTIONNELLE
# =============================================================================

all_results          <- list() #Accumulera tous les résultats MR (directions A et B) sous forme de listes brutes.
result_rows          <- list() #Accumulera les résultats formatés en lignes de dataframe (sorties de make_row).
out_tsv_incremental  <- file.path(OUTDIR, "MR_results_incremental.tsv") #Chemins des fichiers de sauvegarde incrémentale (mis à jour après chaque direction).
out_xlsx_incremental <- file.path(OUTDIR, "MR_results_incremental.xlsx")
header_written       <- FALSE
N_PAIRS              <- length(exp_loaded) * length(csvd_loaded) #Nombre total de paires exposition × cSVD (ex: 25 expositions × 4 cSVD = 100 paires). Utilisé pour l'affichage de progression.
pair_i               <- 0L #Compteur de paires initialisé à 0
clean_name           <- function(s) gsub("[^A-Za-z0-9]", "_", s) #Fonction utilitaire : remplace tout caractère non alphanumérique par _

for (exp_item in exp_loaded) {

  exp_gwas <- exp_item$gwas
  exp_cfg  <- exp_item$cfg
  exp_cm   <- build_col_map(exp_gwas)

  for (csvd_item in csvd_loaded) {

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

    # ── Direction A ───────────────────────────────────────────────────────
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
      append_to_xlsx(row_A, out_xlsx_incremental)
    }

    # ── Direction B ───────────────────────────────────────────────────────
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
      append_to_xlsx(row_B, out_xlsx_incremental)
    }

  }
}

ts(sprintf("══ Boucle terminée : %d directions lancées ══", length(all_results)))


# =============================================================================
# TABLEAU FINAL
# =============================================================================

valid_results <- Filter(Negate(is.null), all_results)  #on garde uniquement les directions avec résultats valides

#applique make row à chaque direction 
tbl <- do.call(rbind, lapply(names(valid_results), function(key) {
  d     <- valid_results[[key]]
  atype <- if (!is.null(d$analysis_type)) d$analysis_type else "unknown"
  make_row(d, analysis_type = atype)
}))

tbl_primary     <- tbl[tbl$Analysis_type == "primary",             ]
tbl_sensitivity <- tbl[tbl$Analysis_type == "sensitivity_reverse", ]

N_TESTS <- nrow(tbl_primary) # NB d'analyses primaires, sachant qu'on va en réalité corriger pour les tests indépendants (à faire à la fin)
ts(sprintf("  N_TESTS (Bonferroni) = %d", N_TESTS))

if (N_TESTS == 0) {
  warning("⚠ N_TESTS = 0 — vérifier primary_role dans les expositions")
  N_TESTS <- 1L
}



# Recalculer Bonferroni maintenant que N_TESTS est connu
tbl <- do.call(rbind, lapply(names(valid_results), function(key) {
  d     <- valid_results[[key]]
  atype <- if (!is.null(d$analysis_type)) d$analysis_type else "unknown"
  make_row(d, analysis_type = atype, bonf_n = N_TESTS)
}))

tbl <- tbl[order(tbl$Analysis_type != "primary", tbl$IVW_p_raw, na.last = TRUE), ]
rownames(tbl) <- NULL

tbl_primary     <- tbl[tbl$Analysis_type == "primary",             ]
tbl_sensitivity <- tbl[tbl$Analysis_type == "sensitivity_reverse", ]

# ── Export TSV ────────────────────────────────────────────────────────────────
out_tsv <- file.path(OUTDIR, "FINAL_bidirectional_MR_all_exposures.tsv")
fwrite(tbl, out_tsv, sep = "\t")
fwrite(tbl_primary,     file.path(OUTDIR, "FINAL_MR_primary.tsv"),             sep = "\t")
fwrite(tbl_sensitivity, file.path(OUTDIR, "FINAL_MR_sensitivity_reverse.tsv"), sep = "\t")

ts(sprintf("  TSV : %d lignes | Primary : %d | Sensitivity : %d",
           nrow(tbl), nrow(tbl_primary), nrow(tbl_sensitivity)))


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
    bonf_rows <- which(!is.na(data$IVW_p_raw) & data$IVW_p_raw < bonf_thresh)

    if (length(sig_rows) > 0)
      openxlsx::addStyle(wb, sheet_name, style = sig_style,
                         rows = sig_rows + 1, cols = seq_len(ncol(data)),
                         gridExpand = TRUE)

    if (length(bonf_rows) > 0)
      openxlsx::addStyle(wb, sheet_name, style = bonf_style,
                         rows = bonf_rows + 1, cols = seq_len(ncol(data)),
                         gridExpand = TRUE)

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
  ts("  ⚠ openxlsx non disponible")
}


# ── Résumé final ──────────────────────────────────────────────────────────────
ts("═══ All done ═══")
ts(sprintf("  N total directions : %d", length(all_results)))
ts(sprintf("  N valides          : %d", length(valid_results)))
ts(sprintf("  N primary          : %d", nrow(tbl_primary)))
ts(sprintf("  N sensitivity      : %d", nrow(tbl_sensitivity)))
ts(sprintf("  Seuil Bonferroni   : %.2e", 0.05 / N_TESTS))
ts(sprintf("  Résultats → %s", OUTDIR))
