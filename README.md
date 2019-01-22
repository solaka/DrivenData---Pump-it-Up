# Pump it Up: Data Mining the Water Table
https://www.drivendata.org/competitions/7/pump-it-up-data-mining-the-water-table/
[<img src='https://s3.amazonaws.com:443/drivendata/comp_images/pumping.jpg'>]

## Goal
The objective of the competition is to predict the status of Tanzanian water wells based on information about their location, altitude, type, manufacturer, etc.  Each well is classified "functional", "functional needs repair", or "non functional".

## Data
The training data consists of X records each with Y features.  There are no data outright missing, but there are many zeroes.  Some of these clearly represent missing data (e.g. longitude and latitude) but others are less clear.  Zero elevation or population could be missing values, or they could simply be wells at sea level in an unpopulated area.  Some experimentation was required to see if the model performed better with data as-is or with "missing" values imputed.

## Approach
