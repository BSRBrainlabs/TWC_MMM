library(Robyn)
packageVersion("Robyn")

# Install readxl package if not already installed
#install.packages("readxl")

# Load the readxl package
library(readxl)
setwd("C:/Users/DeepakArun/Desktop/TWC/Robyn")
data <- read_excel("C:/Users/DeepakArun/Desktop/New Latest ADS data (Preprocessing).xlsx")
robyn_directory <- "~/Desktop"
#data <-data[is.na(data)] <- 0

adstock_selected = "weibull_pdf" # geometric, weibull_cdf or weibull_pdf.
iterations = 20000
trials = 5
train_val_test_split = c(0.9,0.95) # 0.9, 0.95

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
                   'US_Weather_Impact_Rating',
                   #'Positive_impact_on_community',
                   'Net_Trust',
                   'NPS',
                   #'Seen.as.experts_lag181d',
                   'OrganicSearch_Google_Position',
                   'EventsCamp.Vend_Campaign_Flag',
                   'Visits_Critical_Event_Flag'
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
                      'Programmatic_Bidease_Spend',
                      'Preload_Digital_Turbine_launches',
                      'Programmatic_Tapjoy_Clicks',
                      'SEM_Apple_Search_Ads_Impressions',
                      'Programmatic_LiftOff_Impressions',
                      'Programmatic_IronSource_Sonic_Impressions',
                      'Programmatic_Persona.ly_Clicks',
                      'Twitter_TikTok_Combined_Impressions',
                      'Influencer_Daily_Impressions',
                      #'Brand_Spend'),
                      'Brand_Impressions'), # mandatory.
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


# Getting best candidate model
best_candidate_model<-function(OutputFile){
  
  BestModel <- subset(OutputFile, top_sol == TRUE)
  
  columns_to_round <- c("rsq_test", "rsq_train", "nrmse_test", "decomp.rssd")
  BestModel[columns_to_round] <- lapply(BestModel[columns_to_round], function(x) signif(x, digits = 3))
  
  print("*****")
  print(unique(BestModel$rsq_test))
  print("*****")
  
  BestModel$rsq_diff <- abs(round((BestModel$rsq_test - BestModel$rsq_train), 3))
  
  print(BestModel$rsq_diff)
  
  BestModel <- subset(BestModel, rsq_test == max(BestModel$rsq_test))
  modelID_list <- unique(BestModel$solID)
  if(length(modelID_list) == 1){
    modelID <- modelID_list[1]
  }else{
    BestModel <- subset(BestModel, nrmse_test == min(BestModel$nrmse_test))
    modelID_list <- unique(BestModel$solID)
    if(length(modelID_list) == 1){
      modelID <- modelID_list[1]
    }else{
      BestModel <- subset(BestModel, decomp.rssd == min(BestModel$decomp.rssd))
      modelID_list <- unique(BestModel$solID)
      modelID <- modelID_list[1]
    }
  }
  
  BestModel <- subset(BestModel, solID == modelID)
  
  return(BestModel)
}

print("** Selecting Best Candidate Model **")
BestModel <- best_candidate_model(OutputFile)
modelID <- BestModel$solID[1]
print(modelID)
BestModel_df <- as.data.frame(BestModel)

current_timestamp <- Sys.time()
formatted_timestamp <- format(current_timestamp, "%Y%m%d")
file_name_model <- paste0('BestModel',"_",modelID,"_",InputCollect$adstock,"_",formatted_timestamp,".csv")
write.csv(BestModel_df, file = file_name_model, row.names = FALSE)


# Getting response curves
modelID <- '1_1368_3'
channel_list <- ch <- InputCollect$paid_media_spends

current_timestamp <- Sys.time()
formatted_timestamp <- format(current_timestamp, "%Y%m%d")
library(ggplot2)
print("** Generating response curves **")
response_df = data.frame(matrix(ncol = 8, nrow = 0))
colnames(response_df) = c('channel', 'date', 'spend_total', 'spend_carryover', 'spend_immediate', 'target_total', 'target_carryover', 'target_immediate')
for (ch in channel_list){
  response_ch <- robyn_response(InputCollect = InputCollect,
                                OutputCollect = OutputCollect,
                                select_model = modelID,
                                metric_name = ch)
  
  response_temp <- data.frame(channel = ch,
                              date = response_ch$date,
                              spend_total = response_ch$input_total,
                              spend_carryover = response_ch$input_carryover,
                              spend_immediate = response_ch$input_immediate,
                              target_total = response_ch$response_total,
                              target_carryover = response_ch$response_carryover,
                              target_immediate = response_ch$response_immediate)
  
  response_df <- rbind(response_df, response_temp)
  plot_response <- response_ch$plot
  file_response <- paste0(ch,"_",modelID,"_",InputCollect$adstock,"_",formatted_timestamp,"_plot_response.png")
  ggsave(file_response, plot = plot_response)
}

response_df <- response_df[order(response_df$channel, response_df$spend_total), ]
row.names(response_df) <- NULL



file_name_model <- paste0('ResponseCurve',"_",modelID,"_",InputCollect$adstock,"_",formatted_timestamp,".csv")
write.csv(response_df, file = file_name_model, row.names = FALSE)

print("** Saving Model **")
ExportedModel <- robyn_write(InputCollect, OutputCollect, modelID, export = TRUE, dir=robyn_directory)

# Saving One-Pager for Best Candidate Model
one_pager<-function(InputCollect, OutputCollect, modelID, file_one_pager){
  filename_temp <- file_one_pager
  myOnePager <- robyn_onepagers(InputCollect, OutputCollect, select_model = modelID , export = FALSE)
  ggsave(
    filename = filename_temp,
    plot = myOnePager[[modelID]], limitsize = FALSE,
    dpi = 400, width = 17, height = 19
  )
  print("** One-Pager Saved **")
}

file_one_pager <- paste0(ch,"_",modelID,"_",InputCollect$adstock,"_",formatted_timestamp,"_one_pager.png")

print("** Saving One-Pager for Selected Model **")
one_pager(InputCollect, OutputCollect, modelID, file_one_pager)
