
library(caret)
library(MASS)
library(xgboost)
library(rockchalk)
library(tidyverse)
library(lubridate)
library(mice)

#################################################################################
###     FUNCTIONS      ##########################################################
#################################################################################

collapse.levels = function(df, field, n) {   # retains top n levels by count, collapses others into "myOther"
  topn = df %>% 
    count_(field) %>%
    arrange(desc(n)) %>%
    head(n) %>%
    select_(field) %>%
    as.data.frame()
  
  topn = as.character(topn[,1])
  
  all.levels = levels(df[,field])
  comb.levels = setdiff(all.levels, topn)
  combineLevels(df[,field], comb.levels, newLabel = "myOther")
}

#################################################################################

my.dir = "C:/Pump it Up/"

train = read.csv(paste0(my.dir, "train data.csv"), header=TRUE, stringsAsFactors = TRUE)
test = read.csv(paste0(my.dir, "test data.csv"), header=TRUE, stringsAsFactors = TRUE)

target = read.csv(paste0(my.dir, "train labels.csv"), header=TRUE, stringsAsFactors = TRUE)

train$type = "train"
test$type = "test"
all.data = rbind(train, test)

str(all.data)

##########################
### convert data types ###
##########################
all.data$date_recorded = ymd(as.character(all.data$date_recorded))

all.data$region_code = as.factor(all.data$region_code)
all.data$district_code = as.factor(all.data$district_code)


##########################
###    zero flags      ###
##########################
# these are numeric features where it isn't clear whether the zeroes are missing data or are truly zero
# at a minimum, need to establish a flag for zero values
all.data$amount_tsh_zero = as.factor(ifelse(all.data$amount_tsh == 0, 1, 0))
all.data$gps_height_zero = as.factor(ifelse(all.data$gps_height == 0, 1, 0))
all.data$num_private_zero = as.factor(ifelse(all.data$num_private == 0, 1, 0))
all.data$population_zero = as.factor(ifelse(all.data$population == 0, 1, 0))

########################################
###   impute longitude and latitude  ###
########################################
data.location = all.data %>% select(id, longitude, latitude, subvillage, ward, lga)
min.longitude = 29.330   # per https://www.worldatlas.com/af/tz/where-is-tanzania.html
max.latitude = -0.990

data.location$latitude = ifelse(data.location$latitude > max.latitude, NA, data.location$latitude)
data.location$longitude = ifelse(data.location$longitude < min.longitude, NA, data.location$longitude)

# set missing latitude and longitude based on mean by geogrphic location...starting with most granular (subvillage) and moving up
mean.lat.by.subvillage = data.location %>% group_by(subvillage) %>% summarise(mean_latitude = mean(latitude, na.rm=TRUE))
data.location[is.na(data.location$latitude),"latitude"] = 
  data.location %>%
  filter(is.na(latitude)) %>%
  select(subvillage) %>%
  left_join(mean.lat.by.subvillage, by="subvillage") %>%
  select(mean_latitude)

mean.lat.by.ward = data.location %>% group_by(ward) %>% summarise(mean_latitude = mean(latitude, na.rm=TRUE))
data.location[is.na(data.location$latitude),"latitude"] = 
  data.location %>%
  filter(is.na(latitude)) %>%
  select(ward) %>%
  left_join(mean.lat.by.ward, by="ward") %>%
  select(mean_latitude) 

mean.lat.by.lga = data.location %>% group_by(lga) %>% summarise(mean_latitude = mean(latitude, na.rm=TRUE))
data.location[is.na(data.location$latitude),"latitude"] = 
  data.location %>%
  filter(is.na(latitude)) %>%
  select(lga) %>%
  left_join(mean.lat.by.lga, by="lga") %>%
  select(mean_latitude) 

mean.long.by.subvillage = data.location %>% group_by(subvillage) %>% summarise(mean_longitude = mean(longitude, na.rm=TRUE))
data.location[is.na(data.location$longitude),"longitude"] = 
  data.location %>%
  filter(is.na(longitude)) %>%
  select(subvillage) %>%
  left_join(mean.long.by.subvillage, by="subvillage") %>%
  select(mean_longitude)

mean.long.by.ward = data.location %>% group_by(ward) %>% summarise(mean_longitude = mean(longitude, na.rm=TRUE))
data.location[is.na(data.location$longitude),"longitude"] = 
  data.location %>%
  filter(is.na(longitude)) %>%
  select(ward) %>%
  left_join(mean.long.by.ward, by="ward") %>%
  select(mean_longitude) 

mean.long.by.lga = data.location %>% group_by(lga) %>% summarise(mean_longitude = mean(longitude, na.rm=TRUE))
data.location[is.na(data.location$longitude),"longitude"] = 
  data.location %>%
  filter(is.na(longitude)) %>%
  select(lga) %>%
  left_join(mean.long.by.lga, by="lga") %>%
  select(mean_longitude) 

all.data$latitude_NA = ifelse(all.data$latitude > max.latitude, 1, 0)
all.data$longitude_NA = ifelse(all.data$longitude < min.longitude, 1, 0)

all.data$latitude_imp = data.location$latitude
all.data$longitude_imp = data.location$longitude

########################################
###   impute population  ###############
########################################
data.population = all.data %>% select(id, population, subvillage, ward, lga, region)

data.population$population = ifelse(data.population$population == 0, NA, data.population$population)

# set missing population based on mean by geographic location...starting with most granular (subvillage) and moving up
mean.pop.by.subvillage = data.population %>% group_by(subvillage) %>% summarise(mean_population = mean(population, na.rm=TRUE))
data.population[is.na(data.population$population),"population"] = 
  data.population %>%
  filter(is.na(population)) %>%
  select(subvillage) %>%
  left_join(mean.pop.by.subvillage, by="subvillage") %>%
  select(mean_population)

mean.pop.by.ward = data.population %>% group_by(ward) %>% summarise(mean_population = mean(population, na.rm=TRUE))
data.population[is.na(data.population$population),"population"] = 
  data.population %>%
  filter(is.na(population)) %>%
  select(ward) %>%
  left_join(mean.pop.by.ward, by="ward") %>%
  select(mean_population) 

mean.pop.by.lga = data.population %>% group_by(lga) %>% summarise(mean_population = mean(population, na.rm=TRUE))
data.population[is.na(data.population$population),"population"] = 
  data.population %>%
  filter(is.na(population)) %>%
  select(lga) %>%
  left_join(mean.pop.by.lga, by="lga") %>%
  select(mean_population) 

mean.pop.by.region = data.population %>% group_by(region) %>% summarise(mean_population = mean(population, na.rm=TRUE))
data.population[is.na(data.population$population),"population"] = 
  data.population %>%
  filter(is.na(population)) %>%
  select(region) %>%
  left_join(mean.pop.by.region, by="region") %>%
  select(mean_population) 

all.data$latitude_NA = ifelse(all.data$latitude > max.latitude, 1, 0)
all.data$longitude_NA = ifelse(all.data$longitude < min.longitude, 1, 0)

all.data$latitude_imp = data.location$latitude
all.data$longitude_imp = data.location$longitude

###############################################
### too many categories -- omit or condense ###
###############################################
all.data %>% count(funder) %>% arrange(desc(n)) %>% head(20)  
all.data$funder = collapse.levels(all.data, "funder", 30)

all.data %>% count(installer) %>% arrange(desc(n)) %>% head(20) 
all.data$installer = collapse.levels(all.data, "installer", 30)

all.data %>% count(wpt_name) %>% arrange(desc(n)) %>% head(20)  
all.data$wpt_name = collapse.levels(all.data, "wpt_name", 5)

all.data %>% count(subvillage) %>% arrange(desc(n)) %>% head(20)  
all.data$subvillage = collapse.levels(all.data, "subvillage", 5)

all.data %>% count(lga) %>% arrange(desc(n)) %>% head(20)  
all.data$lga = collapse.levels(all.data, "lga", 30)

all.data %>% count(ward) %>% arrange(desc(n)) %>% head(20)  
all.data$ward = collapse.levels(all.data, "ward", 5)

all.data %>% count(scheme_name) %>% arrange(desc(n)) %>% head(20)  
all.data$scheme_name = collapse.levels(all.data, "scheme_name", 20)

all.data %>% count(extraction_type) %>% arrange(desc(n)) %>% head(20)  # ELIMINATE -- rely on type_group (slightly summarized version of this category)
all.data %>% count(extraction_type_group) %>% arrange(desc(n)) %>% head(20)  # take top 10
all.data %>% count(extraction_type_class) %>% arrange(desc(n)) %>% head(20)  # take top 10
all.data = all.data %>% select(-extraction_type)

all.data %>% count(quantity) %>% arrange(desc(n)) %>% head(20)  
all.data %>% count(quantity_group) %>% arrange(desc(n)) %>% head(20)  # ELIMINATE -- identical to prior
all.data = all.data %>% select(-quantity_group)

all.data %>% count(waterpoint_type) %>% arrange(desc(n)) %>% head(20)  # use all
all.data %>% count(waterpoint_type_group) %>% arrange(desc(n)) %>% head(20)  # ELIMINATE -- trivial rollup of prior
all.data = all.data %>% select(-waterpoint_type_group)

all.data %>% count(recorded_by) %>% arrange(desc(n)) %>% head(20)   # 1 level...eliminate
all.data = all.data %>% select(-recorded_by)

###############################################
###   impute construction year    #############
###############################################
set.seed(123)

### impute construction year
data.conyear = all.data %>% select(construction_year, date_recorded, funder, installer, scheme_management, scheme_name)
data.conyear$construction_year = ifelse(data.conyear$construction_year == 0, NA, data.conyear$construction_year)

imputed.conyear = mice(data.conyear)
imputed.conyear = complete(imputed.conyear)

all.data$construction_year_NA = ifelse(all.data$construction_year == 0, 1, 0)
all.data$construction_year_imp = imputed.conyear$construction_year
all.data = all.data %>% select(-construction_year)

#####################################
###    add engineered fields    #####
#####################################

all.data$age_in_years = year(all.data$date_recorded) - all.data$construction_year_imp
all.data$month_recorded = month(all.data$date_recorded)
all.data$year_recorded = year(all.data$date_recorded)

# LDA to pre-predict functionality based on geographic location (as suggested here: https://zlatankr.github.io/posts/2017/01/23/pump-it-up)
data.lda = all.data %>% 
  filter(type == "train") %>%
  dplyr::select(latitude_imp, longitude_imp) %>%
  as.matrix()

data.lda.pred = all.data %>% 
  dplyr::select(latitude_imp, longitude_imp) %>%
  as.matrix()
  
mod.lda = lda(x = data.lda, grouping = target$status_group)
pred.lda = predict(mod.lda, newdata = data.lda.pred, method="plug-in")

all.data$lda_func = pred.lda$posterior[,1]
all.data$lda_fnr = pred.lda$posterior[,2]
all.data$lda_nfunc = pred.lda$posterior[,3]

###############################################################################
###    MODELING    ############################################################
###############################################################################

tr = all.data %>% filter(type == "train")
tr = tr %>% 
    select(-type) %>%
    data.matrix()

te = all.data %>% filter(type == "test")
te = te %>% 
    select(-type) %>%
    data.matrix()

set.seed(123)
val.pct = 0.20
val.index = sample(1:nrow(tr), val.pct*nrow(tr))
val = tr[val.index,]
tr = tr[-val.index,]

tr = xgb.DMatrix(data = tr, label=target[-val.index, "status_group"])
val = xgb.DMatrix(data = val, label=target[val.index, "status_group"])
te = xgb.DMatrix(data = te)

p <- list(objective = "multi:softmax",
          booster = "gbtree",
          eval_metric = "merror",
          num_class = 4,
          eta = 0.02,
          max_depth = 16,
          min_child_weight = 4,
          gamma = 0,
          subsample = 0.70,
          colsample_bytree = 0.70,
          colsample_bylevel = 0.70,
          alpha = 0,
          lambda = 0.40)

set.seed(0)
m_xgb <- xgb.train(p, tr, nrounds = 2000, list(val = val), print_every_n = 100, early_stopping_rounds = 300)

imp = xgb.importance(colnames(te), model=m_xgb)

####################################################################
###   PREDICT, WRITE TO LOG AND FILE   #############################
####################################################################

time.stamp = strftime(Sys.time() - dhours(0), format="%Y-%m-%d %H%M%S")

template = read.csv(paste0(my.dir, "SubmissionFormat.csv"), header=TRUE)
preds = predict(m_xgb, te)
preds = levels(target[,2])[preds]

output = template
output$status_group = preds

### write predictions to test file
write_csv(output, paste0(my.dir, "predictions/", 
                         "PIU merror-", m_xgb$best_score,
                         " time- ", time.stamp, ".csv"))

### write to log ###
comments = ""

for.log = data.frame(time = time.stamp,
                     best_iter = m_xgb$best_iteration,
                     num_iter = m_xgb$niter,
                     num_features = m_xgb$nfeatures,
                     merror = m_xgb$best_score,
                     p,
                     comments = comments,
                     row.names = NULL)

write_csv(for.log, paste0(my.dir, "predictions/", "Pump it Up - model results log.csv"), append=TRUE)
