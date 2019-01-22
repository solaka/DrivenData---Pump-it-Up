# Pump it Up: Data Mining the Water Table
https://www.drivendata.org/competitions/7/pump-it-up-data-mining-the-water-table/
[<img src='https://s3.amazonaws.com:443/drivendata/comp_images/pumping.jpg'>]

## Goal
The objective of the competition is to predict the status of Tanzanian water wells based on information about their location, altitude, type, manufacturer, etc.  Each well is classified "functional", "functional needs repair", or "non functional".

## Data
The training data consists of 59,400 records each with 40 features.  No data are outright missing, but there are many suspicious zeroes.  Some of these clearly represent missing data (e.g. longitude and latitude) but others are less clear.  Zero elevation or population could be missing values, or they could simply be wells at sea level in an unpopulated area.  Some experimentation was required to see if the model performed better with data as-is or with "missing" values imputed.

Ultimately, I imputed zero longitude, latitude, and population values based on the geographic information provided.  There are categorical fields for (in decreasing level of granularity) subvillage, ward, lga, and region, so a simple and effective method of imputation involved checking whether another record from the same subvillage had population and location information, and using that if available.  If not, the process repeats for the next level of geographic granularity (ward), then the next (lga), etc.

Construction year also had a significant number of missing values, and for this I used R's MICE package.

## Feature engineering
Because so many of the variables were categorical, the opportunities for creative feature engineering were somewhat limited.  Some of the fields had a very large number of levels -- hundreds or even thousands -- so I took the top n (by count) for these and rolled the rest up into "Other".  The n for each feature was somewhat subjective, but I looked at variable importance coming from early model versions and adjusted my selections based in part on this.  In addition, some of the fields were entirely or almost entirely redundant, and I eliminated these from further consideration.

I created fields to capture the age of the well at inspection, as well as the month and year the inspection occurred.  I also used linear discriminant analysis to (pre-)predict functionality based only on longitude, latitude, and altitude and included the results as additional features.  Thank you to Zlatan Kremonic for this suggestion (https://zlatankr.github.io/posts/2017/01/23/pump-it-up)!

## Modeling
After splitting the data 80/20 into training and validation subsets, I used a gradient boosted decision tree from R's XGBoost package for classification.  As ever, selecting the "best" hyperparameters for such a model is difficult.  The only thing noteworthy about the final parameters is that I ended up using fairly deep trees (max_depth = 16), probably a result of the number of categorical variables and the relatively large number of levels for many of these.  Final selections were as follows:

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
The chart below shows the relative importance of the various predictors, with the most important (Quantity) at the bottom.  You can see that the conclusions from the LDA analysis proved fairly helpful, though longitude and latitude remained very important predictors.  Interestingly, the ID field proved to have some predictive value -- glad I didn't remove it!
[<img src='https://ze6nnw.by.files.1drv.com/y4mrYy6k6sOx_ydCmT_swWoiRJDQLKNXfwg0cKlFnqDXba0xDyKSbsGZ1me8bRrP4g-AHfASS_zQ0qbg0esqQFuXssiK32TCemXUy5xj47SkDHZBK-3UnNAJLVWt2j9hVS3Fh0bPvpxfCUW7sDfUl_RmD8gXqVF3_0gk-fZTa3xzmNUG0kJGjNVy_NarzkIR0LNY-MY_rpdQALcXxq7HkGDYQ?width=782&height=454&cropmode=none'>]

The final model produced an **81.99% classification rate** on the public test set, good for 399th out of 6220 entries **(top 7%)** as of 1/22/19.  With a little more effort, I think that score could be improved further, and I'd like to try a deep learning NN in Python/Keras to that end.  But no guarantees I'll find the time for that!
