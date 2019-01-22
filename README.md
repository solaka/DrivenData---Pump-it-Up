# Pump it Up: Data Mining the Water Table
https://www.drivendata.org/competitions/7/pump-it-up-data-mining-the-water-table/
[<img src='https://s3.amazonaws.com:443/drivendata/comp_images/pumping.jpg'>]

## Goal
The objective of the competition is to predict the status of Tanzanian water wells based on information about their location, altitude, type, manufacturer, etc.  Each well is classified "functional", "functional needs repair", or "non functional".

## Data
The training data consists of 59,400 records each with 40 features.  There are no data outright missing, but there are many zeroes.  Some of these clearly represent missing data (e.g. longitude and latitude) but others are less clear.  Zero elevation or population could be missing values, or they could simply be wells at sea level in an unpopulated area.  Some experimentation was required to see if the model performed better with data as-is or with "missing" values imputed.

Ultimately, I imputed zero longitude, latitude, and population values based on the geographic information provided.  There are categorical fields for (in decreasing level of granularity) subvillage, ward, lga, and region, so a simple and effective method of imputation involved checking whether another record from the same subvillage had population and location information and using that if so.  If not, then moving to the next level of granularity (ward), then the next (lga), etc.

Construction year also had a significant number of missing values, and for this I used R's MICE package.

## Feature engineering
Because so many of the features were categorical, the opportunities for creative feature engineering were somewhat limited.  Some of the fields had a very large number of levels -- hundreds or even thousands -- so I took the top n for these and rolled the rest up into "Other".  The n for each was somewhat subjective, but I also looked at variable importance coming from the model and altered my selections based in part on this.  In addition, some of the fields were entirely or almost entirely redundant, and I eliminated these.

In addition, I created fields to capture the age of the well at inspection, the month and year the inspection occurred.  I also used linear discriminant analysis to (pre-)predict functionality based only on longitude, latitude, and altitude and included the results as features.  Thank you to Zlatan Kremonic for this suggestion (https://zlatankr.github.io/posts/2017/01/23/pump-it-up).

## Modeling
After splitting the data 80/20 into training and validation subsets, I used a gradient boosted decision tree from R's XGBoost package for classification.  As ever, selecting the "best" hyperparameters for such a model is difficult.  The only thing unusual about the final parameters was that I ended up using fairly deep trees (max_depth = 16), possibly a result of the number of categorical variables and the relatively large number of levels for many of these.  Final selections were as follows:

Element | Selection
--- | ---
objective function | multi:softmax
booster | gbtree
eval_metric | merror
eta | 0.02
max_depth | 16
min_child_weight | 4
gamma | 0
subsample | 0.70
colsample_bytree | 0.70
colsample_bylevel | 0.70
alpha | 0
lambda | 0.40

## Result
After a few iterations, my final model produced an **81.99% classification rate** on the public test set, good for 399th out of 6219 entries **(top 7%)**.  With a little more effort, I think that score could be improved further, and I'd like to try a deep learning NN in Python/Keras to that end.  But no guarantees I'll find the time for that!
