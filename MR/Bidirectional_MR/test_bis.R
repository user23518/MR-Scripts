library(TwoSampleMR) # Core MR methods
  library(data.table) # Fast file reading
  library(dplyr)   # Data manipulation
  library(ggplot2)  # Plotting



HAS_RADIAL <- requireNamespace("RadialMR", quietly = TRUE)  #servent à tester si des packages R sont installés, sans les charger obligatoirement.
HAS_XLSX   <- requireNamespace("openxlsx", quietly = TRUE)

# ── Paths ─────────────────────────────────────────────────────────────────────
WMH_FILE <- "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/UKBiobank/sumstats_shiva_total_wmh_ball_dint.tsv"
T2D_FILE  <- "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/NON_UKBiobank/T2DM_mahajan2018/t2dm_mahajan2018_hg19.gwaslab.tsv.gz"
OUTDIR   <- "/network/iss/debette/users/marine.huang/MR/results"

files <- list.files(
  path      = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank",
  pattern   = "gwaslab\\.tsv\\.gz$",
  recursive = TRUE,
  full.names = TRUE)

# Step 1: module load proxy in CLI
# Step 2: echo $https_proxy in CLI then copy proxy address
proxy_url <- "http://proxy-icm:3128"
# Set enrivonment and test connection
Sys.setenv(https_proxy = proxy_url)
httr::set_config(httr::use_proxy(url = proxy_url))
cat("Testing raw connection...\n")
resp <- httr::GET(
"https://api.opengwas.io/api/status",
httr::use_proxy(url = proxy_url),
httr::timeout(30)
)
cat("Status code:", httr::status_code(resp), "\n") # Should be 200

Sys.setenv(OPENGWAS_JWT ="eyJhbGciOiJSUzI1NiIsImtpZCI6ImFwaS1qd3QiLCJ0eXAiOiJKV1QifQ.eyJpc3MiOiJhcGkub3Blbmd3YXMuaW8iLCJhdWQiOiJhcGkub3Blbmd3YXMuaW8iLCJzdWIiOiJtYXJpbmUyODA2MDVAZ21haWwuY29tIiwiaWF0IjoxNzgwOTIyMDczLCJleHAiOjE3ODIxMzE2NzN9.BHvWnLOy7sIX2VU1E3jAySqSvt_VHROwrpG7i_uw3c_YHxEyz5v45ld9W_mvOPQLoqc-FuiCLyWrPYFo5QiUWAMQsfzK3t3YhFUpUYdjlbBfyMUC_9Sebmms2yMmK_uhvVSrjrJywxgtRKldj6t87ckZ6VNK57XIMFsRAL9H809Db_rc3sAhF31pfNe24wJ7Zy1NJiTBVfNIC8kfO8gbolfBmMWMjPR-5UI2_6jiijtHxPCsO7_QjO9ut10UadigjYHO17dhGjTj8K8Cag6p4UUv_dU9lk7FkrtsM_hVbKDC-WnjzgGt0S2DDyrc4ogc67IRhTmxgsLuATWpa1wV-A")
# Verify
ieugwasr::get_opengwas_jwt()
ieugwasr::user()

# ── Définir les traits cSVD (last version)  ───────────────────────────────────────────────
csvd_traits <- list(

  list(
    name     = "WMH Shiva",
    file     = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/UKBiobank/sumstats_shiva_total_wmh_ball_dint.tsv",
    binary   = FALSE,
    prev     = NULL
  ),

  list(
    name     = "WMH Bianca",
    file     = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/UKBiobank/sumstats_bianca_total_wmh_ball_dint.tsv",
    binary   = FALSE,
    prev     = NULL
  ),

  list(
    name     = "cerebral microbleeds", 
    file     = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/UKBiobank/sumstats_shiva_total_cmb_ball_bin.tsv",
    binary   = TRUE,
    prev     = 0.07
  ),

  list(
    name     = "Perivascular spaces",
    file     = "/network/iss/debette/users/marine.huang/Data/MR_EUR_datasets/UKBiobank/sumstats_shiva_total_pvs_ball_iint.tsv",
    binary   = FALSE,
    prev     = NULL
  )
)

# ── Définir les expositions (non-UKB) ─────────────────────────────────────
exposures <- list(

  # ── Neuro ─────────────────────────────────────────────────────────────────
  list(
    name     = "Alzheimer's disease (Nicolas 2025)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/AD_nicolas2025/ad_nicolas2025_hg38.gwaslab.tsv.gz",
    binary   = TRUE,
    prev     = 0.05,        
    n_manual = NULL,
    primary_role     = "outcome"
  ),

  list(
    name     = "Parkinson's disease (Leonard 2025)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/PD_leonard2025/GP2_euro_ancestry_meta_analysis_2024/pd_leonard2025_hg38.gwaslab.tsv.gz",
    binary   = TRUE,
    prev     = 0.001,        
    n_manual = NULL,
    primary_role     = "outcome"
  ),

  list(
    name     = "Major depressive disorder (Adams 2025)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/MDD_adams2025/mdd_adams2025_hg19.gwaslab.tsv.gz",
    binary   = TRUE,
    prev     = 0.05,        
    n_manual = NULL,
    primary_role     = "outcome"
  ),

  # ── Cardio-vasculaire / Rythme ────────────────────────────────────────────
  list(
    name     = "Atrial fibrillation (Yuan 2025)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/AF_yuan2025/af_yuan2025_hg38.gwaslab.tsv.gz",
    binary   = TRUE,
    prev     = 0.01,      
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  list(
    name     = "Heart failure (Shah 2020)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/HF_shah2020/hf_shah2020_hg19.gwaslab.tsv.gz",
    binary   = TRUE,
    prev     = 0.02,        
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  # ── Athérosclérose ────────────────────────────────────────────────────────
  list(
    name     = "Carotid atherosclerosis / IMT (Gummesson 2025)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/ATHERO_gummesson2025/carotid_gummesson2025_hg38.gwaslab.tsv.gz",
    binary   = FALSE,
    prev     = NULL,       
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  list(
    name     = "Severe internal carotid stenosis (Gummesson 2025)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/ATHERO_gummesson2025/sis_gummesson2025_hg38.gwaslab.tsv.gz",
    binary   = FALSE,
    prev     = NULL,        
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  list(
    name     = "Coronary artery calcification (Kavousi 2023)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/CAC_kavousi2023/cac_kavousi2023_hg19.gwaslab.tsv.gz",
    binary   = FALSE,
    prev     = NULL,       
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  # ── Métabolique ───────────────────────────────────────────────────────────
  list(
    name     = "BMI (Locke 2015)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/BODY_giant/bmi_locke2015_hg19.gwaslab.tsv.gz",
    binary   = FALSE,
    prev     = NULL,         
    n_manual = NULL
  ),

  list(
    name     = "WHRadjBMI (Shungin 2015)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/BODY_giant/whradjBMI_shungin2015_hg19.gwaslab.tsv.gz",
    binary   = FALSE,
    prev     = NULL,         
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  list(
    name     = "Type 2 diabetes (Mahajan 2018)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/T2DM_mahajan2018/t2dm_mahajan2018_hg19.gwaslab.tsv.gz",
    binary   = TRUE,
    prev     = 0.10,       
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  # ── Rein ──────────────────────────────────────────────────────────────────
  list(
    name     = "Chronic kidney disease (Wuttke 2019)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/CKD_wuttke2019/CKD_wuttke2019_hg19.gwaslab.tsv.gz",
    binary   = TRUE,
    prev     = 0.14,         
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  list(
    name     = "Kidney function / eGFR (Wuttke 2019)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/CKD_wuttke2019/eGFR_wuttke2019_hg19.gwaslab.tsv.gz",
    binary   = FALSE,
    prev     = NULL,       
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  # ── Toxines ───────────────────────────────────────────────────────────────
  list(
    name     = "Smoking (Liu 2019)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/HABITS_liu2019/cigpday_liu2019_hg19.gwaslab.tsv.gz",
    binary   = FALSE,
    prev     = NULL,         
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  list(
    name     = "Alcohol consumption (Liu 2019)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/HABITS_liu2019/drinkspweek_liu2019_hg19.gwaslab.tsv.gz",
    binary   = FALSE,
    prev     = NULL,        
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  # ── Lipides ───────────────────────────────────────────────────────────────
  list(
    name     = "HDL cholesterol (Graham 2021)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/LIPIDS_graham2021/hdl_graham2021_hg19.gwaslab.tsv.gz",
    binary   = FALSE,
    prev     = NULL,         
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  list(
    name     = "LDL cholesterol (Graham 2021)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/LIPIDS_graham2021/ldl_graham2021_hg19.gwaslab.tsv.gz",
    binary   = FALSE,
    prev     = NULL,         
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  list(
    name     = "Non-HDL cholesterol (Graham 2021)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/LIPIDS_graham2021/nonhdl_graham2021_hg19.gwaslab.tsv.gz",
    binary   = FALSE,
    prev     = NULL,         
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  list(
    name     = "Total cholesterol (Graham 2021)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/LIPIDS_graham2021/tc_graham2021_hg19.gwaslab.tsv.gz",
    binary   = FALSE,
    prev     = NULL,         
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  list(
    name     = "Triglycerides (Graham 2021)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/LIPIDS_graham2021/tg_graham2021_hg19.gwaslab.tsv.gz",
    binary   = FALSE,
    prev     = NULL,        
    n_manual = NULL,
    primary_role     = "exposure"
  ),

  # ── AVC / sous-types ──────────────────────────────────────────────────────
  list(
    name     = "Cardioembolic stroke (Mishra 2022)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/CEstroke_mishra2022_hg19.gwaslab.tsv.gz",
    binary   = TRUE,
    prev     = 0.002,       
    n_manual = NULL,
    primary_role     = "outcome"
  ),

  list(
    name     = "Large artery stroke (Mishra 2022)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/LAAstroke_mishra2022_hg19.gwaslab.tsv.gz",
    binary   = TRUE,
    prev     = 0.002,        
    n_manual = NULL,
    primary_role     = "outcome"
  ),

  list(
    name     = "Small vessel stroke (Mishra 2022)",
    file     = "/network/iss/debette/shared/MR_EUR_datasets/NON_UKBiobank/STROKE_mishra2022/SVstroke_mishra2022_hg19.gwaslab.tsv.gz",
    binary   = TRUE,
    prev     = 0.0025,       
    n_manual = NULL,
    primary_role     = "outcome"
  )
)

# ── Parameters (last version)  ────────────────────────────────────────────────────────────────
PVAL_IV <- 5e-8;  CLUMP_R2 <- 0.001;  CLUMP_KB <- 10000; 
MIN_IVS <- 3 ;   MIN_EAF  <- 0.01 ;  


# MIN_IVS <- 3, au moins 3 instruments
# CLUMP_R2 = R2 max toléré entre 2 SNPs
# CLUMB_KB = fenêtre max de kb
# MIN_EAF = fréquence allélique minimale de 1%

dir.create(OUTDIR, recursive = TRUE, showWarnings = FALSE) # créer le dossier de sortie, recursive = true = crée aussi les dossiers parents manquants, showWarnings FAlSE # silencieux si le dossier existe déjà
ts <- function(...) message(format(Sys.time(), "[%H:%M:%S] "), ...) # Crée un outil pour tracer la progression avec l'heure


#  =============================================================================
# HELPERS
# =============================================================================


# Formater Beta (SE), 4 chiffres significatifs,b manquant = NA pour le tableau final 


fmt_bse <- function(b, se, d = 4) {
 if (is.na(b) || is.na(se)) return(NA_character_)
 sprintf("%.*f (%.*f)", d, b, d, se)
}

fmt_p <- function(p) {
 if (is.null(p) || length(p) == 0) return(NA_character_)
 p <- p[1]
 if (is.na(p))  return(NA_character_)
 if (p < 0.001) formatC(p, format = "e", digits = 2)
 else           as.character(round(p, 3))}  #2 signes significatifs,  p‑value arrondie à 3 décimales si p>0.001, notation sicentifique si p<0.001 


# ── Palindromic SNP detection ─────────────────────────────────────────────
check_palindromic <- function(EA, NEA) {
 (EA == "T" & NEA == "A") |
 (EA == "A" & NEA == "T") |
 (EA == "G" & NEA == "C") |
 (EA == "C" & NEA == "G")
}


#' @param path      Path to .gwaslab.tsv(.gz) file.
#' @param min_eaf   Minimum EAF filter (NULL = skip); symmetric, also applies
#'                  to 1 - min_eaf.
#' @param verbose   Print per-filter counts = montre le lb de SNPs retirés
#' @return          data.frame with gwaslab-standard column names.



read_gwaslab <- function(path, min_eaf = NULL, verbose = TRUE) {


 if (!file.exists(path))
   stop("File not found: ", path)


 ts(sprintf("  Reading: %s", basename(path)))
 dt <- data.table::fread(path, data.table = FALSE) # lecture du dataset (dt) via data.table sans application du format 
 ts(sprintf("  Loaded  : %s variants  |  %d columns", # nb de variants 
            format(nrow(dt), big.mark = ","), ncol(dt)))


 if (verbose)
   ts(sprintf("  Columns : %s", paste(names(dt), collapse = ", "))) #liste le nom des colonnes du fichier dt 


# ── Validate required gwaslab columns ─────────────────────────────────────
 required <- c("SNPID", "CHR", "POS", "NEA", "EA", "BETA", "SE", "P")
 missing  <- setdiff(required, names(dt))  #renvoie les éléments dans required mais absents names (dt)
 if (length(missing) > 0)
   stop("Missing required gwaslab columns: ", paste(missing, collapse = ", "),
        "\n  Found: ", paste(names(dt), collapse = ", ")) #arrête le code si pas les colonnes nécessaires 

 n0 <- nrow(dt) #Sauvegarde le nombre initial de SNPs


  # ── rsID present and non-empty ────────────────────────────────────────────
 if ("rsID" %in% names(dt)) {
   dt <- dt[!is.na(dt$rsID) & dt$rsID != "" & dt$rsID != ".", ] # la ligne (SNP) n'est gardé que si elle est false pour NA dans rSID, "" or . 
   if (verbose)
     ts(sprintf("  rsID filter          : %s removed  (%s remaining)",
                format(n0 - nrow(dt), big.mark = ","),
                format(nrow(dt),      big.mark = ",")))
   n0 <- nrow(dt) #sauvegarde les SNPs avvec rsID 
 }


# ── EAF filter ──────────────────────────────────────────
 if (!is.null(min_eaf) && "EAF" %in% names(dt)) {
   n_before <- nrow(dt) #nb de SNPs avant filtrage 
   dt <- dt[!is.na(dt$EAF) &
             dt$EAF >= min_eaf &             # la ligne n'est gardé que si elle est false pour NA dans EAF et si EAF > 0.01 et < 0.99 /  ! = false  
             dt$EAF <= (1 - min_eaf), ]
   if (verbose)
     ts(sprintf("  EAF filter [%.2f-%.2f] : %d removed  (%d remaining)",
                min_eaf, 1 - min_eaf,
                n_before - nrow(dt), nrow(dt)))
   n0 <- nrow(dt)
 }


ts(sprintf("  Final               : %s variants ready for MR",
            format(nrow(dt), big.mark = ",")))
 dt

}


# ── Radial MR: detect outliers via Cochran Q, re-run IVW without them ────────
run_radial <- function(dat) {
 empty <- list(b = NA_real_, se = NA_real_, pval = NA_real_,
               nsnp = NA_integer_, n_out = 0L) # liste vide que la fonction renverra si une étape échoue pour éviter que le pipeline plante en recevant un objet mal formé 
#dat =data.frame issu de harmonise_data () 

 if (!HAS_RADIAL || nrow(dat) < 4) return(empty)  # si pas radial package ou moins de 4 SNPs → résultat non fiable, on ne commence pas le radial


 tryCatch({
   if (any(is.na(dat$beta.exposure)) || any(is.na(dat$beta.outcome)) ||
       any(is.na(dat$se.exposure))   || any(is.na(dat$se.outcome))) {
     ts("  RadialMR: NA values in beta/se — skipping")
     return(empty)
   } #si b ou se manquant dans exposure ou outcome, on arrête la fonction

   ri  <- RadialMR::format_radial(
     BXG = dat$beta.exposure, BYG = dat$beta.outcome,
     seBXG = dat$se.exposure, seBYG = dat$se.outcome,
     RSID = dat$SNP
   ) #formatage des noms des colonnes pour radial MR 
  
 
   if (is.null(ri) || nrow(ri) == 0) {
      ts("  RadialMR: format_radial retourné vide — skipping")
     return(empty)
   }    # ← vérifier que le formatage a bien fonctionné 

   # weights=3 → modified second order weights (Cochran's Q) outlier detection
   # la fonction renvoie out$coef = estimation ivw sur tous les snps, out$qstat, out$qpval et out$outliers 

   out <- RadialMR::ivw_radial(
    ri, # A formatted data frame using the format_radial function.
    alpha = 0.05, # A value specifying the statistical significance threshold for identifying outliers (0.05 specifies a p-value threshold of 0.05).
    weights = 3) # A value specifying the inverse variance weights used to calculate IVW estimate and Cochran's Q statistic. By default modified second order weights are used, but one can choose to select first order (1), second order (2) or modified second order weights (3).
  #on effectue l'analyse radial MR 


   if (is.null(out$outliers) || nrow(out$outliers) == 0) {
     ts("  RadialMR: 0 outliers — primary IVW stands")
     return(modifyList(empty, list(nsnp = nrow(dat), n_out = 0L)))
   } #si pas de outliers ,la première analyse ivw stands 


# Étape 1 : identifier les outliers
   bad <- as.character(out$outliers$SNP)
   ts(sprintf("  RadialMR: %d outlier(s): %s", length(bad), paste(bad, collapse = ", "))) # collapse = séparateur des rsID 


# Étape 2 : retirer les outliers


   clean <- dat[!dat$SNP %in% bad, ] # on retire tous les SNPs présents dans bad (outliers)
   if (nrow(clean) < MIN_IVS) return(modifyList(empty, list(n_out = length(bad)))) # pas assez de SNPs 

# Étape 3 : recalculer IVW sans les outliers


   r2 <- mr(clean, method_list = "mr_ivw") # re-run mr in twosampleMR for IVW after excluding outliers
   list(b = r2$b[1], se = r2$se[1], pval = r2$pval[1],
        nsnp = nrow(clean), n_out = length(bad)) #[1] on ne garde que le premier terme de chaque colonne (1ère méthode = ivW)
 }, error = function(e) { ts("  RadialMR error: ", conditionMessage(e)); empty })
}


# ── Concordance: do sensitivity analyses support the primary IVW? ─────────────
check_concordance <- function(ivw_b, ivw_p, eg_b, eg_p, wm_b, wm_p, a = 0.05) {
 issues <- character(0)
 if (!is.na(ivw_p) && ivw_p < a) {


   # ── MR-Egger ────────────────────────────────────────── #vérifie que MR-Egger a produit un résultat exploitable puis compare le signe de eg_b et ivw_b 
   if (!is.na(eg_b) && sign(eg_b) != sign(ivw_b))
     issues <- c(issues, "MR-Egger direction discordant")


   # ── Weighted Median ─────────────────────────────────── # on  compare le signe de wm_b et ivw_b  
   if (!is.na(wm_b) && sign(wm_b) != sign(ivw_b))         
   
     issues <- c(issues, "Weighted median direction discordant")


   if (!is.na(wm_p) && wm_p >= a)
     issues <- c(issues, "Weighted median non-significant") # vérifie que la p-value de WM est significative (hypthèse des 50% instrument valides)  
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


 # ── 1. Instrument selection ─────────────────────────────────────────────
 pv  <- exp_gwas[[ec$pval]]
 ivs <- exp_gwas[!is.na(pv) & pv < PVAL_IV, ] 
 ts(sprintf("  GW-sig (p < 5e-8): %d SNPs", nrow(ivs))) #on ne garde que les SNPS significatifs de l'exposure 


 if (nrow(ivs) < MIN_IVS) {
   ivs <- exp_gwas[!is.na(pv) & pv < 1e-6, ]
   ts(sprintf("  Relaxed (p < 1e-6): %d SNPs", nrow(ivs)))
 } # Si moins de 3 SNPs genome-wide significatifs → essaie un seuil plus souple de p value 
 if (nrow(ivs) < MIN_IVS) { ts("  ✗ Not enough IVs — skipping"); return(NULL) }


 f_all    <- (ivs[[ec$beta]] / ivs[[ec$se]])^2  # Calcule la F-statistique pour chaque SNP = mesure la force de chaque instrument
 f_median <- round(median(f_all, na.rm = TRUE), 1) #Calcule la médiane des F-stats — arrondie à 1 décimale, calculer une F‑stat pour chaque instrument (dans f_all), la médiane (force globale), la valeur minimale (instrument le plus faible), le nombre d’instruments avec F < 10 (instruments faibles),
 ts(sprintf("  F-stat: median = %.1f | min = %.1f | n(F < 10) = %d",
            f_median, min(f_all, na.rm = TRUE), sum(f_all < 10, na.rm = TRUE)))


 # ── Availability filter ────────────────────────────────────────────
 ts("  Checking IV availability in outcome GWAS ...")


 avail_rsid <- ivs[[ec$rsid]] %in% out_gwas[[oc$rsid]] #Pour chaque SNP instrument — est-il présent dans l'outcome ? on prend les rsid de ivs (snps significatifs) qu'on vérifie dans les rsid de l'outcome 
 n_avail    <- sum(avail_rsid) # Compte les SNPs disponibles 
 n_missing  <- nrow(ivs) - n_avail #on calcule le nb de SNPs retirés 


 ts(sprintf("  rsID match         : %d / %d SNPs found in outcome  |  %d missing (%.1f%%)",
          n_avail, nrow(ivs), n_missing,
          100 * n_missing / nrow(ivs))) 


 if (n_avail < MIN_IVS) {
   ts(sprintf("  ✗ Only %d SNPs available in outcome (< MIN_IVS = %d) — skipping",
              n_avail, MIN_IVS))
   return(NULL)
 } #Si moins de 3 SNPs disponibles dans l'outcome → abandonne l'analyse 


 ivs <- ivs[avail_rsid, ] # crée un subgroupe et remplace ivs par ce subgroup qui ne garde que les SNPs présents dans l'outcome
 ts(sprintf("  %d SNPs retained → proceeding to LD clumping", nrow(ivs))) #Affiche combien de SNPs passent au clumping


# ── remove palindromes ────────────

ivs$is_palindromic <- check_palindromic(
   EA  = dat_mr$effect_allele.exposure,
   NEA = dat_mr$other_allele.exposure
 ) #on crée is_palindromic dans ivs, on check les palindromes 

n_palind <- sum(ivs$is_palindromic, na.rm = TRUE)
 ts(sprintf("  Palindrome  : %d palindromic SNPs in data set",
            n_palind)) #affiche les palindromes restants 
ivs <- ivs[!is.na(ivs$is_palindromic) & !ivs$is_palindromic, ]

ts(sprintf("  %d SNPs retained after palindrome removal → proceeding to LD clumping",
           nrow(ivs)))

           
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
   eaf_col           = ec$eaf,
   pval_col          = ec$pval,
   samplesize_col    = ec$n,
   chr_col           = ec$chr,
   pos_col           = ec$pos
 )
 if (!is.null(ec$ncase))    eargs$ncase_col    <- ec$ncase
 if (!is.null(ec$ncontrol)) eargs$ncontrol_col <- ec$ncontrol
 exp_fmt <- do.call(format_data, eargs)
 exp_fmt$exposure <- exp_name # pour que les tables soient bien labellisées 


# ── 3. LD clumping (EUR 1000G, r² < 0.001, 10 000 kb) ────────────────────
 ts("  Clumping ...")
 exp_c <- tryCatch(
   clump_data(exp_fmt, clump_r2 = CLUMP_R2, clump_kb = CLUMP_KB, pop = "EUR"),
   error = function(e) { ts("  ! API clumping failed: ", conditionMessage(e)); exp_fmt } #Si l'API est inaccessible → affiche l'erreur et retourne tous les SNPs non clumpés
 ) #paramètres définis au dessus 
 ts(sprintf("  %d independent IVs after clumping", nrow(exp_c))) #Affiche le nombre de SNPs indépendants après clumping :
 if (nrow(exp_c) < MIN_IVS) { ts("  ✗ Not enough IVs post-clump"); return(NULL) }   #Moins de 3 SNPs après clumping → abandon de cette direction


 # ── 4. Extract outcome SNPs — match on rsID, fallback to chr:pos ──────────
 # exp_c$SNP now contains rsIDs → match outcome on rsID column
 out_sub <- out_gwas[out_gwas[[oc$rsid]] %in% exp_c$SNP, ]   # ←  Cherche dans l'outcome GWAS les SNPs dont le rsID est dans exp_c$SNP, sachant qu'il est issu de exp_fmt qui contient ivs (clean, après filtrage matching)
 ts(sprintf("  Outcome match: %d / %d by rsID", nrow(out_sub), nrow(exp_c))) #Affiche combien de SNPs instruments ont été trouvés dans l'outcome :


#Si la colonne chr existe ET moins de 50% des SNPs trouvés par rsID → essaie le fallback chr:pos
 if (!is.null(oc$chr) && nrow(out_sub) < 0.5 * nrow(exp_c)) { 
   ts("  Trying chr:pos fallback ...")
   exp_cp <- paste0(sub("^chr", "", exp_c$chr.exposure), ":", exp_c$pos.exposure) #Crée des identifiants chr:pos pour les instruments
   out_cp <- paste0(sub("^chr", "", out_gwas[[oc$chr]]),  ":", out_gwas[[oc$pos]]) #Crée les mêmes identifiants chr:pos pour l'outcome GWAS
   idx    <- which(out_cp %in% exp_cp)   # indices des lignes d’outcome dont le chr:pos correspond à un instrument
   
   # si ce fallback récupère plus d’IV que le match par rsID initial, on le remplace
   if (length(idx) > nrow(out_sub)) {
     cpmap <- setNames(exp_c$SNP, exp_cp)   # chr:pos → rsID
     tmp   <- out_gwas[idx, ] #Extrait les lignes de l'outcome correspondant aux positions trouvées
     tmp[[oc$rsid]] <- cpmap[out_cp[idx]]   # ← stamp rsID into outcome rsID col
     ts(sprintf("  Chr:pos matched %d IVs", nrow(tmp)))
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
   snp_col          = oc$rsid,   # ← rsID, not SNPID
   beta_col         = oc$beta,
   se_col           = oc$se,
   effect_allele_col = oc$ea,
   other_allele_col = oc$oa,
   eaf_col          = oc$eaf,
   pval_col         = oc$pval,
   samplesize_col   = oc$n,
   chr_col          = oc$chr,
   pos_col          = oc$pos
 )
 if (!is.null(oc$ncase))    oargs$ncase_col    <- oc$ncase
 if (!is.null(oc$ncontrol)) oargs$ncontrol_col <- oc$ncontrol
 out_fmt <- do.call(format_data, oargs) #appel la fonction format_data et rentre les arguments qu'on a inscrit dans la list 
 out_fmt$outcome <- out_name # label l'outcome pour les tableaux 


# ── 6. Harmonise (action=3:,exclude ambiguous palindromic MAF 0.42–0.58) ────────────
 
 ts(" Harmonising (action = 3) ...")
 dat    <- harmonise_data(exp_c, out_fmt, action = 3) 
 dat_mr <- dat[dat$mr_keep, ] #mr_keep est un vecteur de la fonction harmonise data qui attribue à chaque SNP true or false à l'issue de l'harmonisation 
 ts(sprintf("  Total: %d | Kept: %d | Removed: %d",
            nrow(dat), nrow(dat_mr), sum(!dat$mr_keep))) #non mr_keep sont retirés (!mr_keep)  

#on regarde mes SNPs exclus, on garde les lignes où mr_keep est false dans le dataset complet avec remove true si impossible d'harmoniser (aligner) 
 if (any(!dat$mr_keep)) {
   dat %>% filter(!mr_keep) %>%
     count(palindromic, ambiguous, remove) %>% print()
 }
 if (nrow(dat_mr) < MIN_IVS) { ts("  ✗ Not enough SNPs post-harmonisation"); return(NULL) }

# ── 7. Steiger directionality test ──────────────────────────────────────
 ts("  Steiger directionality test ...")


 # Reconstruire samplesize si absent pour les traits binaires, si les colonnes existent et qu'elles ne sont pas vides 
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


 # ── Helper: compute r² (corrélation SNP-trait) contribution per SNP ─────────────────────────────
 compute_r <- function(beta, eaf, pval, n, ncase, ncontrol,
                       is_binary, prevalence, label) {


   n_snps <- length(beta)   # ← ajout nb de snps selon le nb de b 


   if (is_binary) { #is_binary issu de exp_binary défini dans traits (liste)
     # Binary trait: convert log-OR to r via liability-scale conversion
     if (is.null(ncase) || all(is.na(ncase)) ||
         is.null(ncontrol) || all(is.na(ncontrol))) {
       ts(sprintf("  WARNING: %s is binary but ncase/ncontrol absent — falling back to get_r_from_pn", label))
       pval_c <- pmax(pmin(pval, 1 - 1e-15), 1e-300)   # ← ajout : clamp p
       n_c    <- pmax(n, 2L)                             # ← ajout : clamp n
       r <- TwoSampleMR::get_r_from_pn(p = pval_c, n = n_c) #convertit p‑value + N en une corrélation $r$ approximative si absence de n_case et n_control 
     } else { #si ncase et control disponibles, lor = log-odds ratio 
       r <- TwoSampleMR::get_r_from_lor(
         lor        = beta,
         af         = eaf,
         ncase      = ncase,
         ncontrol   = ncontrol,
         prevalence = prevalence,
         model      = "logit",
         correction = FALSE
       )
     }
   } else { 
     # Continuous trait (is_binary false): convert p + N to r
     if (is.null(n) || all(is.na(n))) {                 # vérif n
       ts(sprintf("  WARNING: %s samplesize absent — r set to NA", label))
       return(rep(NA_real_, n_snps))
     }
     pval_c <- pmax(pmin(pval, 1 - 1e-15), 1e-300)     # ← clamp p = borner n 
     n_c    <- pmax(n, 2L)                               # ←clamp n = borner p 
     r <- TwoSampleMR::get_r_from_pn(p = pval_c, n = n_c)  #on obtient r à partir du calcul par TWOSAMPLEMR
   }


   #  vérif longueur, que r n'est pas vide ou a bien la même longueur que le nb de SNPs 
   if (length(r) == 0 || length(r) != n_snps) {
     ts(sprintf("  WARNING: %s compute_r length mismatch — r set to NA", label))
     return(rep(NA_real_, n_snps))
   }


   pmin(pmax(r, -0.9999), 0.9999)    # clamp/borner to valid correlation range
 }

#application pour les données exposure et outcome 
 dat_mr$r.exposure <- compute_r(
   beta       = dat_mr$beta.exposure,
   eaf        = dat_mr$eaf.exposure,
   pval       = dat_mr$pval.exposure,
   n          = dat_mr$samplesize.exposure,
   ncase      = if ("ncase.exposure"    %in% names(dat_mr)) dat_mr$ncase.exposure    else NULL,
   ncontrol   = if ("ncontrol.exposure" %in% names(dat_mr)) dat_mr$ncontrol.exposure else NULL,
   is_binary  = exp_binary,
   prevalence = exp_prevalence,
   label      = exp_name
 )


 dat_mr$r.outcome <- compute_r(
   beta       = dat_mr$beta.outcome,
   eaf        = dat_mr$eaf.outcome,
   pval       = dat_mr$pval.outcome,
   n          = dat_mr$samplesize.outcome,
   ncase      = if ("ncase.outcome"    %in% names(dat_mr)) dat_mr$ncase.outcome    else NULL,
   ncontrol   = if ("ncontrol.outcome" %in% names(dat_mr)) dat_mr$ncontrol.outcome else NULL,
   is_binary  = out_binary,
   prevalence = out_prevalence,
   label      = out_name
 )

#affiche la médiane de r.exposure t r.outcome, compte le nb de NA pour chaque et indique le chemin utilisé 

 ts(sprintf("  r.exposure: median = %.4f | NAs = %d  [%s]",
            median(dat_mr$r.exposure, na.rm = TRUE),
            sum(is.na(dat_mr$r.exposure)),
            if (exp_binary) "binary / get_r_from_lor" else "continuous / get_r_from_pn"))
 ts(sprintf("  r.outcome:  median = %.4f | NAs = %d  [%s]",
            median(dat_mr$r.outcome, na.rm = TRUE),
            sum(is.na(dat_mr$r.outcome)),
            if (out_binary) "binary / get_r_from_lor" else "continuous / get_r_from_pn"))


 # Steiger directionality test — aucun SNP retiré
 dir_res <- tryCatch(
   directionality_test(dat_mr),
   error = function(e) { ts("  ! directionality_test failed: ", conditionMessage(e)); NULL }
 )

#Fonction de sécurité : si dir_res est NULL, vide, ou sans la colonne demandée = retourne NA
# sinon, on prend la première valeur de cette colonne (dir_res)

 safe_col <- function(df, col) {
   if (is.null(df) || nrow(df) == 0 || !col %in% names(df)) return(NA)
   v <- df[[col]][1]
   if (length(v) == 0) NA else v
 }


 stg_dir  <- safe_col(dir_res, "correct_causal_direction") #renvoie true/false 
 stg_pval <- safe_col(dir_res, "steiger_pval") #renvoie la p-value du steiger 
 ts(sprintf("  Steiger directionality: correct = %s | p = %s",
            stg_dir, fmt_p(stg_pval)))


 dat_use <- dat_mr   


# ── 8. Primary MR ─────────────────────────────────────────────────────────
 ts("  Running MR ...")
 res <- mr(dat_use, method_list = c(
   "mr_ivw", # multiplicative random effects
   "mr_egger_regression",
   "mr_weighted_median"
 ))
# IVW = tous les instruments valides
# MR-Egger, intercept ≠ 0 → évidence de pléiotropie (INSIDE assumption = pléiotropie compensée ou indépendante de l'effet causal), si Q et Qf proches alors
# Weighted Median — méthode de sensibilité : 50% des instruments corrects


# ── 9. Heterogeneity (Cochran Q) & directional pleiotropy (Egger intercept) ───────────
 
 
 het   <- tryCatch(mr_heterogeneity(dat_use),  error = function(e) NULL)
 # normalement les SNPs donnent un effet similaire (dépendant de si on considère le fixed effect ou le random effect model)
 # Q mesure l'hétérogénéité entre les SNPs instruments, si Q petit = effets similaires des SNPs
 # Q_df = nombre de SNPs - 1


 pleio <- tryCatch(mr_pleiotropy_test(dat_use), error = function(e) NULL)
#Teste si l'intercept de MR-Egger est différent de 0 = pléiotropie directionnelle


# ── 10. Radial MR (outlier detection + IVW re-run) ────────────────────────
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
 fwrite(dat_use, sprintf("%s_dat_mr.tsv",     pfx), sep = "\t") #sprintf("%s_dat_mr.tsv", pfx) fabrique un nom de fichier à partir de pfx
 fwrite(res,     sprintf("%s_mr_results.tsv", pfx), sep = "\t")
 if (!is.null(dir_res)) fwrite(dir_res, sprintf("%s_steiger.tsv", pfx), sep = "\t") 
 if (!is.null(het))     fwrite(het,     sprintf("%s_het.tsv",     pfx), sep = "\t")
 if (!is.null(pleio))   fwrite(pleio,   sprintf("%s_pleio.tsv",   pfx), sep = "\t")
 ts("  Fichiers sauvegardés ✓")
}, error = function(e) {
 ts("  ! Erreur sauvegarde : ", conditionMessage(e))
})


# ── 12. Plots ─────────────────────────────────────────────────────────────
 tryCatch({
   ht  <- max(6, nrow(dat_use) * 0.35 + 2) #Calcule la hauteur des graphiques selon le nombre de SNPs :
   sng <- mr_singlesnp(dat_use) #Calcule l'effet MR pour chaque SNP individuellement
   loo <- mr_leaveoneout(dat_use) #Calcule l'effet MR en retirant un SNP à la fois
   ggsave(sprintf("%s_scatter.pdf", pfx), mr_scatter_plot(res, dat_use)[[1]], width=8, height=6) #effet SNP→exposition vs effet SNP→outcome 
   ggsave(sprintf("%s_forest.pdf",  pfx), mr_forest_plot(sng)[[1]],           width=8, height=ht) #effet de chaque SNP individuellement + estimé global
   ggsave(sprintf("%s_loo.pdf",     pfx), mr_leaveoneout_plot(loo)[[1]],      width=8, height=ht) #Leave-one-out plot — montre si le résultat dépend d'un seul SNP
   ggsave(sprintf("%s_funnel.pdf",  pfx), mr_funnel_plot(sng)[[1]],           width=6, height=6) #Funnel plot = détecte l'asymétrie (signe de pléiotropie)
 }, error = function(e) ts("  ! Plot error: ", conditionMessage(e)))


# ── 13. Extract results for summary table ─────────────────────────────────
 grp <- function(method_name) {
   r <- res[res$method == method_name, ]
   if (nrow(r) == 0) list(b = NA_real_, se = NA_real_, pval = NA_real_)
   else              list(b = r$b[1], se = r$se[1], pval = r$pval[1])
 } #Fonction locale — extrait b, se, pval pour une méthode donnée, si méthode absente → retourne NA, si présente → retourne les valeurs
#res = résultat de la MR 

 ivw <- grp("Inverse variance weighted (multiplicative random effects)")
 eg  <- grp("MR Egger")
 wm  <- grp("Weighted median")
 #Extrait les résultats des trois méthodes


 hi <- if (!is.null(het)) het[het$method == "Inverse variance weighted", ] else NULL
 he <- if (!is.null(het)) het[het$method == "MR Egger", ]                  else NULL
 #Extrait les statistiques Q pour IVW et Egger séparément


 cc <- check_concordance(ivw$b, ivw$pval, eg$b, eg$pval, wm$b, wm$pval)
 #Vérifie si les trois méthodes concordent entre elles 


 list(
   exposure = exp_name,  outcome = out_name,
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
 )

}