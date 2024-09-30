# Running ecological niche models
# Bruno Carvalho
# GHR Tutorial 23 Jun 2023

# Load packages
library(raster)
library(dismo)
library(randomForest)
library(readr)
library(dplyr)

# load harmonized dataset
df <- read_csv("./output/01_harmonized_data.csv")

# load predictors dataset
predictors <- stack("./output/01_predictors.grd")


#### 1. Split data into train (70%) and test (30%) sets ####

# create ID column in the harmonized dataset
df <- df %>% 
  mutate(id = 1:nrow(df))

set.seed(123) # for reproducibility

# randomly sample 70% of records for model train
train_df <- df %>% 
  group_by(pa) %>% 
  slice_sample(prop = 0.7)

# select remaining 30% of records for model test
test_df <- df %>% 
  anti_join(train_df, by = "id")


#### 2. Run and evaluate models ####

# define model formula (for glm and rf)
model <- pa ~ bio1 + bio12 + bio15 + bio4

# run bioclim model
bc <- bioclim(x = predictors,
              p = train_df[train_df$pa == 1, c("lon", "lat")])

# evaluate against test set
evbc <- evaluate(p = test_df[test_df$pa == 1, c("lon", "lat")], 
                 a = test_df[test_df$pa == 0, c("lon", "lat")],
                 model = bc, 
                 x = predictors)

# check evaluation metrics
print(evbc)
plot(evbc, "ROC")


# run GLM - logistic regression model
gm <- glm(model, 
          data = train_df,
          family = binomial(link="logit"))

# evaluate against test set
evgm <- evaluate(p = test_df[test_df$pa == 1, c("lon", "lat")], 
                 a = test_df[test_df$pa == 0, c("lon", "lat")],
                 model = gm, 
                 x = predictors)

# check evaluation metrics
print(evgm)
plot(evgm, "ROC")

# run random forest model
rf <- randomForest(model, 
                   data = train_df,
                   na.action=na.omit) # skipping NAs in records

# evaluate against test set
evrf <- evaluate(p = test_df[test_df$pa == 1, c("lon", "lat")], 
                 a = test_df[test_df$pa == 0, c("lon", "lat")],
                 model = rf, 
                 x = predictors)

# check evaluation metrics
print(evrf)
plot(evrf, "ROC")


#### 3. Predict into the whole study area (country) ####

# bioclim
out_bc <- predict(predictors, bc, progress='text')

# GLM
out_gm <- predict(predictors, gm, type = "response", progress='text')

# random forest
out_rf <- predict(predictors, rf, progress='text')


# check predictive maps
plot(out_bc, main = "bioclim")
plot(out_gm, main = "GLM (logistic regression)")
plot(out_rf, main = "random forest")

# if you want you can run the next lines to 
# plot the test points right after each plot:
points(pull(filter(test_df, pa == 1), lon), 
       pull(filter(test_df, pa == 1), lat),
       pch = 20, cex = 0.5)


#### 4. Make binary predictions ####

# binarize predictions by using the threshold value 
# that maximizes both specificity and sensitivity 
# (estimated from the ROC curves)

# bioclim
out_bc_bin <- out_bc > threshold(evbc, "spec_sens")

# GLM
# we need to get the log-odds from the prediction
out_gm2 <- predict(predictors, gm) 
out_gm_bin <- out_gm2 > threshold(evgm, "spec_sens")

# random forest
out_rf_bin <- out_rf > threshold(evrf, "spec_sens")

# check predictive maps
plot(out_bc_bin, main = "bioclim")
plot(out_gm_bin, main = "GLM (logistic regression)")
plot(out_rf_bin, main = "random forest")

# plot the test points if you want:
points(pull(filter(test_df, pa == 1), lon), 
       pull(filter(test_df, pa == 1), lat),
       pch = 20, cex = 0.5)


#### BONUS! Ensemble predictive maps ####

# weighted average by AUC
ens <- weighted.mean(stack(out_bc, out_gm, out_rf), 
                     w = c(evbc@auc, evgm@auc, evrf@auc),
                     na.rm = FALSE)

# agreement between binary predictions (overlay)
ens_bin <- sum(out_bc_bin, out_gm_bin, out_rf_bin)


# see all predictions and ensemble
par(mfrow=c(2,2))
plot(out_bc, main = "bioclim")
plot(out_gm, main = "GLM (logistic regression)")
plot(out_rf, main = "random forest")
plot(ens, main = "ensemble (weighted by AUC)")
par(mfrow=c(1,1))

# now with the binary preditions
par(mfrow=c(2,2))
plot(out_bc_bin, main = "bioclim")
plot(out_gm_bin, main = "GLM (logistic regression)")
plot(out_rf_bin, main = "random forest")
plot(ens_bin, main = "ensemble (overlay)")
par(mfrow=c(1,1))

#### Saving outputs ####

# save summary evaluation table
mod_eval <- data.frame(species = unique(df$species),
                       model = c("bioclim", "glm", "random forest"),
                       auc = c(evbc@auc, evgm@auc, evrf@auc))

write_csv(mod_eval, "./output/02_model_evaluation.csv")

# saving final plots
png(file = "./output/02_continuous_predictions.png",
    width=600, height=800)
par(mfrow=c(2,2))
plot(out_bc, main = "bioclim")
plot(out_gm, main = "GLM (logistic regression)")
plot(out_rf, main = "random forest")
plot(ens, main = "ensemble (weighted by AUC)")
dev.off()

png(file = "./output/02_binary_predictions.png",
    width=600, height=800)
par(mfrow=c(2,2))
plot(out_bc_bin, main = "bioclim")
plot(out_gm_bin, main = "GLM (logistic regression)")
plot(out_rf_bin, main = "random forest")
plot(ens_bin, main = "ensemble (overlay)")
dev.off()

# save output ensemble rasters
writeRaster(ens, "./output/02_continuous_ensemble.grd", format = "raster", overwrite=TRUE)
writeRaster(ens_bin, "./output/02_binary_ensemble.grd", format = "raster", overwrite=TRUE)


#### OPTIONAL: running maxent models ####
# If you successfully installed maxent

# run model
mx <- maxent(x = predictors, 
             p = data.frame(train_df[train_df$pa == 1, c("lon", "lat")]), 
             a = data.frame(train_df[train_df$pa == 0, c("lon", "lat")]))

# evaluate
evmx <- evaluate(p = test_df[test_df$pa == 1, c("lon", "lat")], 
                 a = test_df[test_df$pa == 0, c("lon", "lat")],
                 model = rf, 
                 x = predictors)

# check results
print(evmx)
plot(evmx, "ROC")

# predict
out_mx <- predict(predictors, mx, progress='text')

# apply threshold
out_mx_bin <- out_mx > threshold(evmx, "spec_sens")

# check maps
plot(out_mx, main = "maxent")
plot(out_mx_bin, main = "maxent")
