library(Robyn)
packageVersion("Robyn")

# Install readxl package if not already installed
#install.packages("readxl")

# Load the readxl package
library(readxl)
setwd("C:/Users/DeepakArun/Desktop/TWC/Robyn")
data <- read_excel("C:/Users/DeepakArun/Desktop/Data/input.xlsx")
robyn_directory <- "~/Desktop"


adstock_selected = "weibull_pdf" # geometric, weibull_cdf or weibull_pdf.
iterations = 20000
trials = 5
train_val_test_split = c(0.9) # 0.9, 0.95

Sys.setenv(R_FUTURE_FORK_ENABLE = "true")
options(future.fork.enable = TRUE)

create_files <- TRUE

data("dt_prophet_holidays")
head(dt_prophet_holidays)

names(data) <- gsub(" ", "_", names(data))

InputCollect <- robyn_inputs(
  dt_input = data,
  dt_holidays = dt_prophet_holidays,
  date_var = "Date", # date format must be "2020-01-01"
  dep_var = "Overall_Web_Visits", # there should be only one dependent variable
  dep_var_type = "conversion", # "revenue" (ROI) or "conversion" (CPA)
  prophet_vars = c("trend", "season", "holiday"), # "trend","season", "weekday" & "holiday"
  prophet_country = "US",
  context_vars = c('Preference',
                   'US.Weather.Impact.Rating',
                   #'Positive_impact_on_community',
                   'Net.Trust',
                   'NPS',
                   #'Seen.as.experts_lag181d',
                   #'OrganicSearch_Google_Position',
                   'EventsCamp.Vend_Campaign_Flag',
                   'Visits_Critical_Event_Flag',
                   'OrganicSearch_Google_Clicks_Paid_Spend',
                   'SocialEng_Facebook_Estimated_Clicks_Paid_Spend',
                   'SocialEng_YouTube_Estimated_Clicks_Paid_Spend',
                   'SocialEng_Instagram_Estimated_Clicks_Paid_Spend',
                   'SocialEng_Twitter_Total_Engagements_Paid_Spend',
                   'SocialEng_LinkedIn_Impressions_Paid_Spend',
                   'SocialEng_TikTok_Impressions_Paid_Spend'
  ),
  paid_media_spends = c('SEM_Google_Spend',
                        'Preload_IronSource_Aura_Spend',
                        'Programmatic_Bidease_Spend',
                        'Preload_Digital_Turbine_Spend',
                        'Programmatic_Tapjoy_Spend',
                        'SEM_Apple_Search_Ads_Spend',
                        'Programmatic_LiftOff_Spend',
                        'Programmatic_IronSource_Sonic_Spend',
                        'Programmatic_Persona.ly_Spend',
                        'Twitter_TikTok_Combined_Spend',
                        'Brand_Spend',
                        'Influencer_Spend'),
  paid_media_vars = c('SEM_Google_Impressions',
                      'Preload_IronSource_Aura_impressions',
                      'Programmatic_Bidease_Clicks',
                      'Preload_Digital_Turbine_launches',
                      'Programmatic_Tapjoy_Clicks',
                      'SEM_Apple_Search_Ads_Impressions',
                      'Programmatic_LiftOff_Impressions',
                      'Programmatic_IronSource_Sonic_Impressions',
                      'Programmatic_Persona.ly_Clicks',
                      'Twitter_TikTok_Combined_Impressions',
                      #'Brand_Spend',
                      'Brand_Impressions',
                      'Influencer_Daily_Impressions'), # mandatory.
  # paid_media_vars must have same order as paid_media_spends. Use media exposure metrics like
  # impressions, GRP etc. If not applicable, use spend instead.
  organic_vars = c('OrganicSearch_Google_Clicks',
                   #'SocialEng_YouTube_Impressions',
                   #'SocialEng_Twitter_Estimated_Clicks',
                   #'SocialEng_Facebook_Impressions'
                   # 'OrganicSearch_Google_Position',
                   'SocialEng_Twitter_Total_Engagements',
                   #'SocialEng_Twitter_Impressions',
                   'SocialEng_Facebook_Estimated_Clicks',
                   #'SocialEng_Facebook_Total_Engagements',
                   #'SocialEng_Instagram_Impressions',
                   'SocialEng_LinkedIn_Impressions',
                   #'SocialEng_LinkedIn_Total_Engagements',
                   #'SocialEng_LinkedIn_Estimated_Clicks',
                   'SocialEng_TikTok_Impressions',
                   #'SocialEng_TikTok_Total_Engagements',
                   'SocialEng_YouTube_Estimated_Clicks',
                   'SocialEng_Instagram_Estimated_Clicks'
                   
  ),
  # factor_vars = c("events"), # force variables in context_vars or organic_vars to be categorical
  window_start = min(data$Date),#"2021-09-01", #min(data$Date),
  window_end = max(data$Date),
  adstock = adstock_selected
)

print(InputCollect)

# Function to generate hyperparameters for various media types for saturation effect (Hill function)
generate_hyperparameters_saturation_effect <- function(media_types) {
  
  # Define the list of media types and parameter ranges
  alpha_range <- c(0.5, 3)
  gamma_range <- c(0.3, 1)
  
  hyperparameters <- list()
  
  for (media in media_types) {
    range <- c()
    if (grepl("alphas", media)){
      range <- alpha_range
    } else if (grepl("gammas", media)){
      range <- gamma_range
    } else{
      next
    }
    hyperparameters[[media]] <- range
  }
  
  return(hyperparameters)
}

# Function to generate hyperparameters for various media types when adstock type selected is geometric
generate_hyperparameters_geometric_ads <- function(media_types, hyperparameters) {
  
  # Define the list of media types and parameter ranges
  theta_range_tv <-  c(0.3, 0.8)
  theta_range_radio <- c(0.1, 0.4)
  theta_range_digital <- c(0, 0.3)
  
  ch_typ_tv_list <- c('tv', 'television')
  ch_typ_tv_list <- paste(ch_typ_tv_list, collapse = "|")
  
  ch_typ_radio_list <- c('radio', 'fm', 'newsletter', 'print', 'ooh', 'outdoor', 'out of home', 'newspaper', 'magazine', 'flyer', 'catalog', 'brochure', 'postcard')
  ch_typ_radio_list <- paste(ch_typ_radio_list, collapse = "|")
  
  for (media in media_types) {
    range <- c()
    if (grepl("thetas", media)){
      if (grepl(ch_typ_tv_list, media)){
        range <- theta_range_tv
      } else if (grepl(ch_typ_radio_list, media)){
        range <- theta_range_radio
      } else{
        range <- theta_range_digital
      }
    } else{
      next
    }
    hyperparameters[[media]] <- range
  }
  
  return(hyperparameters)
}

# Function to generate hyperparameters for various media types when adstock type selected is weibull
generate_hyperparameters_weibull_ads <- function(media_types, hyperparameters, adstock_type) {
  
  # Define the list of media types and parameter ranges
  shape_range_CDF <- c(0.0001, 2)
  shape_range_PDF_AllShapes <- c(0.0001, 10)
  shape_range_PDF_StrongLagged <- c(2.0001, 10)
  scale_range <- c(0, 0.1)
  
  for (media in media_types) {
    range <- c()
    if (grepl("shapes", media)){
      
      if (adstock_type == 'weibull_cdf'){
        range <- shape_range_CDF
      } else if (adstock_type == 'weibull_pdf'){
        range <- shape_range_PDF_AllShapes
      } else if (adstock_type == 'weibull_pdf_strong_lagged'){
        range <- shape_range_PDF_StrongLagged
      }
    } else if (grepl("scales", media)){
      range <- scale_range
    } else{
      next
    }
    hyperparameters[[media]] <- range
  }
  
  return(hyperparameters)
}

hyper_names_list <- hyper_names(adstock = InputCollect$adstock, all_media = InputCollect$all_media)
print(hyper_names_list)

plot_adstock(plot = FALSE)
plot_saturation(plot = FALSE)

hyperparameters <- generate_hyperparameters_saturation_effect(hyper_names_list)

if (InputCollect$adstock == 'geometric'){
  # Generate hyperparameters based on the media types and ranges when adstock is geometric
  hyperparameters <- generate_hyperparameters_geometric_ads(hyper_names_list, hyperparameters)
} else{
  # Generate hyperparameters based on the media types and ranges when adstock is weibull cdf or weibull pdf
  hyperparameters <- generate_hyperparameters_weibull_ads(hyper_names_list, hyperparameters, InputCollect$adstock)
}

print(hyperparameters)

# data_temp = data
# data_temp$Date <- as.Date(data_temp$Date)
# subset_df <- subset(data_temp, Date <= as.Date('2023-09-30'))
# num_rows_train <- nrow(subset_df)
# num_rows_test <- nrow(data_temp) - num_rows_train
# rows_train_per = num_rows_train/nrow(data_temp)

# Hyperparameter for training, validation and testing
hyperparameters[['train_size']] = train_val_test_split

print(hyperparameters)

print("** Robyn Input with Hyperparameters **")
InputCollect <- robyn_inputs(InputCollect = InputCollect, hyperparameters = hyperparameters)

robyn_model_run<-function(InputCollect, iterations, trials){
  
  OutputModels <- robyn_run(
    InputCollect = InputCollect,
    cores = NULL,
    iterations = iterations,
    trials = trials,
    ts_validation = TRUE,
    add_penalty_factor = FALSE # If using experimental feature
  )
  
  return(OutputModels)
}

print("** Robyn Model Running **")
# Model Building for Robyn MMM
OutputModels <- robyn_model_run(InputCollect, iterations, trials)
print("** Robyn Model Output **")
print(OutputModels)

OutputCollect <- robyn_outputs(
  InputCollect, OutputModels,
  pareto_fronts = "auto", # automatically pick how many pareto-fronts to fill min_candidates (100)
  # min_candidates = 100, # top pareto models for clustering. Default to 100
  # calibration_constraint = 0.1, # range c(0.01, 0.1) & default at 0.1
  csv_out = "pareto", # "pareto", "all", or NULL (for none)
  clusters = TRUE, # Set to TRUE to cluster similar models by ROAS. See ?robyn_clusters
  export = create_files, # this will create files locally
  plot_folder = robyn_directory, # path for plots exports and files creation
  plot_pareto = create_files # Set to FALSE to deactivate plotting and saving model one-pagers
)
print(OutputCollect)

print("** Generating Output File **")
OutputFile <- OutputCollect$xDecompAgg
#print(OutputFile)