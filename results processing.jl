using CSV, DataFrames, Statistics, Plots, LaTeXStrings, Distributions, StatsPlots, Dates, Pkg
#Pkg.instantiate()
pgfplotsx()

true_theta =   [0.5 0.0 0.5 0.0 0.0 0.0 0.0 1.0 0.0 0.0; 
                0.5 0.5 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 0.0 1.0 2.0 0.0 1.0 0.0 0.0 0.0 0.0; 
                0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.3 0.3 0.4 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.8 0.2 0.0 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.3 0.2 0.5 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.4 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.5 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                0.2 0.4 0.4 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.9 0.1 0.0 3.0 1.0 0.0 1.0 0.0 1.0 0.0; 
                1.0 0.0 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 1.0 0.0 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.1 0.7 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.6 0.2 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.1 0.8 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.6 0.2 0.2 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.0 0.8 0.2 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.7 0.0 0.3 0.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.2 0.3 0.5 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.7 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0; 
                0.5 0.5 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 0.0 1.0 2.0 0.0 1.0 0.0 0.0 0.0 0.0; 
                0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.3 0.3 0.4 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.8 0.2 0.0 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.3 0.2 0.5 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.4 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.5 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                0.2 0.4 0.4 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.9 0.1 0.0 3.0 1.0 0.0 1.0 0.0 1.0 0.0; 
                1.0 0.0 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 1.0 0.0 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.1 0.7 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.6 0.2 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.1 0.8 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.6 0.2 0.2 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.0 0.8 0.2 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.7 0.0 0.3 0.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.2 0.3 0.5 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.7 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0;
                0.5 0.0 0.5 0.0 0.0 0.0 0.0 1.0 0.0 0.0; 
                0.5 0.5 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 0.0 1.0 2.0 0.0 1.0 0.0 0.0 0.0 0.0; 
                0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.3 0.3 0.4 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.8 0.2 0.0 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.3 0.2 0.5 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.4 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.5 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                0.2 0.4 0.4 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.9 0.1 0.0 3.0 1.0 0.0 1.0 0.0 1.0 0.0; 
                1.0 0.0 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 1.0 0.0 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.1 0.7 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.6 0.2 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.1 0.8 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.6 0.2 0.2 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.0 0.8 0.2 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.7 0.0 0.3 0.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.2 0.3 0.5 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.7 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0; 
                0.5 0.5 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 0.0 1.0 2.0 0.0 1.0 0.0 0.0 0.0 0.0; 
                0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.3 0.3 0.4 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.8 0.2 0.0 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.3 0.2 0.5 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.4 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.5 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                0.2 0.4 0.4 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.9 0.1 0.0 3.0 1.0 0.0 1.0 0.0 1.0 0.0; 
                1.0 0.0 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 1.0 0.0 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.1 0.7 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.6 0.2 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.1 0.8 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.6 0.2 0.2 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.0 0.8 0.2 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.7 0.0 0.3 0.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.2 0.3 0.5 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.7 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0]

true_theta_new=[0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 1.0 0.0; 
                0.5 0.5 0.0 0.0 1.0 0.0 1.0 0.0 0.0 1.0; 
                0.0 0.0 1.0 2.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.3 0.3 0.4 1.0 1.0 0.0 0.0 0.0 1.0 0.0; 
                0.8 0.2 0.0 0.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.3 0.2 0.5 1.0 1.0 0.0 0.0 0.0 1.0 0.0; 
                0.1 0.4 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.5 0.3 0.0 0.0 1.0 0.0 0.0 0.0 0.0; 
                0.2 0.4 0.4 1.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.9 0.1 0.0 3.0 1.0 1.0 0.0 1.0 0.0 0.0; 
                1.0 0.0 0.0 0.0 1.0 0.0 1.0 0.0 0.0 1.0; 
                0.0 1.0 0.0 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.1 0.7 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.6 0.2 1.0 1.0 0.0 0.0 1.0 0.0 0.0; 
                0.1 0.1 0.8 0.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.6 0.2 0.2 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.0 0.8 0.2 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.7 0.0 0.3 0.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.2 0.3 0.5 1.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.7 0.3 0.0 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.5 0.5 0.0 0.0 1.0 0.0 0.0 1.0 0.0 1.0; 
                0.0 0.0 1.0 2.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.3 0.3 0.4 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.8 0.2 0.0 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.3 0.2 0.5 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.4 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.5 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                0.2 0.4 0.4 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.9 0.1 0.0 3.0 1.0 0.0 1.0 0.0 1.0 0.0; 
                1.0 0.0 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 1.0 0.0 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.1 0.7 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.6 0.2 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.1 0.8 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.6 0.2 0.2 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.0 0.8 0.2 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.7 0.0 0.3 0.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.2 0.3 0.5 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.7 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0;
                0.5 0.0 0.5 0.0 0.0 0.0 0.0 1.0 0.0 0.0; 
                0.5 0.5 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 0.0 1.0 2.0 0.0 1.0 0.0 0.0 0.0 0.0; 
                0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.3 0.3 0.4 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.8 0.2 0.0 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.3 0.2 0.5 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.4 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.5 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                0.2 0.4 0.4 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.9 0.1 0.0 3.0 1.0 0.0 1.0 0.0 1.0 0.0; 
                1.0 0.0 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 1.0 0.0 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.1 0.7 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.6 0.2 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.1 0.8 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.6 0.2 0.2 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.0 0.8 0.2 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.7 0.0 0.3 0.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.2 0.3 0.5 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.7 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0; 
                0.5 0.5 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 0.0 1.0 2.0 0.0 1.0 0.0 0.0 0.0 0.0; 
                0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.3 0.3 0.4 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.8 0.2 0.0 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.3 0.2 0.5 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.4 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.5 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                0.2 0.4 0.4 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.9 0.1 0.0 3.0 1.0 0.0 1.0 0.0 1.0 0.0; 
                1.0 0.0 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 1.0 0.0 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.1 0.7 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.6 0.2 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.1 0.8 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.6 0.2 0.2 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.0 0.8 0.2 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.7 0.0 0.3 0.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.2 0.3 0.5 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.7 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0]


### MATRICES ###
o_matrix = Array{Float64}(undef,20,365,25,24)
o_pi_matrix = Array{Float64}(undef,20,365,25,24)
signatures_matrix = Array{Float64}(undef,20,365,25,10,24)
signatures_pi_matrix = Array{Float64}(undef,20,365,25,10,24)
prices_matrix = Array{Float64}(undef,20,365,25,24)
prices_pi_matrix = Array{Float64}(undef,20,365,25,24)
predictions_matrix = Array{Float64}(undef,20,365,25,24)
predictions_pi_matrix = Array{Float64}(undef,20,365,25,24)
thetas_mean_matrix = Array{Float64}(undef,20,365,25,10)
thetas_var_matrix = Array{Float64}(undef,20,365,25,10)
p_limit_matrix = Array{Float64}(undef,20,365,24)

### --- Spot Prices --- ###
# Reading spot prices from energidataservice.dk
DA_prices_df = CSV.read("Data/Elspotprices.csv",DataFrame,delim=";",decimal=',')
# Convert the datetime column to DateTime format
DA_prices_df.datetime = DateTime.(DA_prices_df.HourDK, "yyyy-mm-dd HH:MM")
# Create an empty 365x24 matrix to store the prices
DA_price_matrix = Array{Union{Missing,Float64}}(missing,365, 24)
# Loop over each row in the DataFrame and fill the matrix
for row in eachrow(DA_prices_df)
    date = Date(row.datetime)  # Extract the date (YYYY-MM-DD)
    hour = Hour(row.datetime).value  # Extract the hour (0-23)
    # Calculate the day of the year (1-365)
    day_of_year = Dates.dayofyear(date)
    #adding elafgift to all hours and consumption
    elafgift = 0.9513
    # Fill the matrix at the appropriate (day, hour) position
    DA_price_matrix[day_of_year, hour + 1] = max(row.SpotPriceDKK/1000,0) + elafgift# +1 since Julia is 1-based indexing
end
# Filling missing hour due to time change and setting it equal to previous hour
DA_price_matrix[85,3] = DA_price_matrix[85,2]
export_tariff = 0.0054
penalty = 50

println("Reading CSVs")

for p in 1:20
    println(p)
    o_df = CSV.read("New Results/p$(p)_observations_m=1_i=365_n=25_r=0.5.csv",DataFrame)
    for row in eachrow(o_df)
        for t in 0:23
            if Int64(row.M) == 1
                o_matrix[p-1 + Int64(row.M),Int64(row.I),Int64(row.N),t+1] = row[string(t)]
            end
        end
    end

    o_pi_df = CSV.read("New Results/p$(p)_observations_PI_m=1_i=365_n=25_r=0.5.csv",DataFrame)    
    for row in eachrow(o_pi_df)
        for t in 0:23
            if Int64(row.M) == 1
                o_pi_matrix[p-1 + Int64(row.M),Int64(row.I),Int64(row.N),t+1] = row[string(t)]
            end
        end
    end

    signatures_df = CSV.read("New Results/p$(p)_signature_m=1_i=365_n=25=.csv",DataFrame)
    for row in eachrow(signatures_df)
        for t in 1:24
            if Int64(row.M) == 1
                signatures_matrix[p-1 + Int64(row.M),Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
            end
        end
    end

    signatures_pi_df = CSV.read("New Results/p$(p)_signature_pi_m=1_i=365_n=25=.csv",DataFrame)
    for row in eachrow(signatures_pi_df)
        for t in 1:24
            if Int64(row.M) == 1
                signatures_pi_matrix[p-1 + Int64(row.M),Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
            end
        end
    end
    
    predictions_df = CSV.read("New Results/p$(p)_prediction_m=1_i=365_n=25=.csv",DataFrame)
    for row in eachrow(predictions_df)
        for t in 1:24
            if Int64(row.M) == 1
                predictions_matrix[p-1 + Int64(row.M),Int64(row.I),Int64(row.N),t] = row[string(t-1)]
            end
        end
    end

    predictions_pi_df = CSV.read("New Results/p$(p)_prediction_pi_m=1_i=365_n=25=.csv",DataFrame)
    for row in eachrow(predictions_pi_df)
        for t in 1:24
            if Int64(row.M) == 1
                predictions_pi_matrix[p-1 + Int64(row.M),Int64(row.I),Int64(row.N),t] = row[string(t-1)]
            end
        end
    end

    prices_df = CSV.read("New Results/p$(p)_prices_m=1_i=365_n=25_r=0.5.csv",DataFrame)
    for row in eachrow(prices_df)
        for t in 1:24
            if Int64(row.M) == 1
                predictions_matrix[p-1 + Int64(row.M),Int64(row.I),Int64(row.N),t] = row[string(t-1)]
            end
        end
    end

    prices_pi_df = CSV.read("New Results/p$(p)_prices_pi_m=1_i=365_n=25_r=0.5.csv",DataFrame)
    for row in eachrow(prices_pi_df)
        for t in 1:24
            if Int64(row.M) == 1
                predictions_pi_matrix[p-1 + Int64(row.M),Int64(row.I),Int64(row.N),t] = row[string(t-1)]
            end
        end
    end

    thetas_df = CSV.read("New Results/p$(p)_thetas_m=1_i=365_n=25.csv",DataFrame)
    for row in eachrow(thetas_df)
        if Int64(row.M) == 1
            thetas_mean_matrix[p-1 + Int64(row.M),Int64(row.I),Int64(row.N),Int64(row.K)] = row.mean
            thetas_var_matrix[p-1 + Int64(row.M),Int64(row.I),Int64(row.N),Int64(row.K)] = row.variance
        end
    end

    p_limit_df = CSV.read("New Results/p$(p)_P_limit_m=1_i=365.csv",DataFrame)
    for row in eachrow(p_limit_df)
        for t in 1:24
            if Int64(row.M) == 1
                p_limit_matrix[p-1 + Int64(row.M),Int64(row.I),t] = row[string(t-1)]
            end
        end
    end
end

########################
### INPUT DATA PLOTS ###
########################

#temperature data input
temperature_df = CSV.read("Data/temperature.csv",DataFrame)
temperatureplot = plot(temperature_df.temperature, xlabel = "Hour of year", ylabel = "Temperature [C]", xrange = (0,8760), label = false)

#price input data
prices_df = CSV.read("Data/Elspotprices.csv",DataFrame,delim=";",decimal=',')
# Convert the datetime column to DateTime format
prices_df.datetime = DateTime.(prices_df.HourDK, "yyyy-mm-dd HH:MM")
sort!(prices_df,:datetime)
priceplot=plot(max.(prices_df.SpotPriceDKK/1000,0), xlabel = "Hour of year", ylabel = "Spot price [DKK/kWh]", xrange = (0,8760), label = false)

#pv input data
PV_df = CSV.read("Data/pv_production.csv",DataFrame,header=4)
pvplot = plot(PV_df.electricity, xlabel = "Hour of year", ylabel = "Electricity production [kW]", xrange = (0,8760), label = false)

#making plots of this data
inputplot = plot(priceplot, temperatureplot, pvplot, layout = (1,3), size = (1200,300))
savefig(inputplot,"Figures/inputplot.tex")
##########################################
### COMMUNITY COST WITH AND WITHOUT PI ###
##########################################
y_tilde = Array{Float64}(undef,20,365,25,24)
p_im_tilde = Array{Float64}(undef,20,365,24)
p_ex_tilde = Array{Float64}(undef,20,365,24)
p_pen_tilde = Array{Float64}(undef,20,365,24)
cost_tilde = Array{Float64}(undef,20,365)
cumulative_cost_tilde = zeros(20,366)
for i in 1:20
    for d in 1:365
        DA_prices = DA_price_matrix[d,:]
        if d <= 90 || d >= 273
            import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 1.2878, 1.2878, 1.2878, 1.2878, 0.4293, 0.4293, 0.4293]
        else
            import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.5580, 0.5580, 0.5580, 0.5580, 0.2146, 0.2146, 0.2146]
        end
        for n in 1:25
            y_tilde[i,d,n,:] = transpose(signatures_matrix[i,d,n,:,:])*true_theta[n,:]
        end
        p_im_tilde[i,d,:] = max.(sum(y_tilde[i,d,:,:],dims=1),0)
        p_ex_tilde[i,d,:] = min.(sum(y_tilde[i,d,:,:],dims=1),0)
        p_pen_tilde[i,d,:] = max.(p_im_tilde[i,d,:]-p_limit_matrix[i,d,:],0)
        cost_tilde[i,d] = sum(p_im_tilde[i,d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_tilde[i,d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_tilde[i,d,t] for t in 1:24)
        cumulative_cost_tilde[i,d+1] = cumulative_cost_tilde[i,d] + cost_tilde[i,d]
    end
end

y_star = Array{Float64}(undef,20,365,25,24)
p_im_star = Array{Float64}(undef,20,365,24)
p_ex_star = Array{Float64}(undef,20,365,24)
p_pen_star = Array{Float64}(undef,20,365,24)
cost_star = Array{Float64}(undef,20,365)
cumulative_cost_star = zeros(20,366)
for i in 1:20
    for d in 1:365
        DA_prices = DA_price_matrix[d,:]
        if d <= 90 || d >= 273
            import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 1.2878, 1.2878, 1.2878, 1.2878, 0.4293, 0.4293, 0.4293]
        else
            import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.5580, 0.5580, 0.5580, 0.5580, 0.2146, 0.2146, 0.2146]
        end
        for n in 1:25
            y_star[i,d,n,:] = transpose(signatures_pi_matrix[i,d,n,:,:])*true_theta[n,:]
        end
        p_im_star[i,d,:] = max.(sum(y_star[i,d,:,:],dims=1),0)
        p_ex_star[i,d,:] = min.(sum(y_star[i,d,:,:],dims=1),0)
        p_pen_star[i,d,:] = max.(p_im_star[i,d,:]-p_limit_matrix[i,d,:],0)
        cost_star[i,d] = sum(p_im_star[i,d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_star[i,d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_star[i,d,t] for t in 1:24)
        cumulative_cost_star[i,d+1] = cumulative_cost_star[i,d] + cost_star[i,d]
    end
end

quantile_95 = Array{Float64}(undef,366)
quantile_05 = Array{Float64}(undef,366)
for d in 1:365
    quantile_95[d+1] = quantile(cumulative_cost_tilde[:,d] - cumulative_cost_star[:,d],0.95)
    quantile_05[d+1] = quantile(cumulative_cost_tilde[:,d] - cumulative_cost_star[:,d],0.05)
end

#Plotting
regretplot = plot(0:365,transpose(mean(cumulative_cost_tilde - cumulative_cost_star,dims=1)),xrange = (0,365),c=1,xlabel = "Day", ylabel = "Cumulative Regret [DKK]",label ="Mean", legend=:bottomright,title = "Unchanged Capacity limit")
plot!(0:365,quantile_95,linestyle =:dot,c =1, fillrange = quantile_05, fillalpha=0.3, label = false)
plot!(0:365,quantile_05,xrange = (0,365), label = "90% Confidence Bound", c=1 , linestyle=:dot)
plot!(0:365,quantile_95,xrange = (0,365), label = false, c= 1,linestyle=:dot)
savefig(regretplot,"Figures/Community Cost Regret.tex")

#######################
### VIOLATION PLOTS ###
#######################

buffer = maximum(sum(o_pi_matrix, dims = 3)[:,:,1,:] - p_limit_matrix[:,:,:])

day1 = plot(0:23,transpose(mean(p_limit_matrix[:,1,:],dims=1)),title = "Day 1", ylabel = "Power [kW]", xlabel = "Time-of-day [h]", yrange = (0,90), xrange = (0,23), legend = :topright, color = 1, label = "Capacity Limit")
#plot!(0:23,transpose(mean(p_limit_matrix[:,1,:],dims=1)) .+ buffer, color = 1, linestyle = :dot, fillrange = transpose(mean(p_limit_matrix[:,1,:],dims=1)), fillcolor = 1, fillalpha = 0.2, label = "Noise Tolerance")
plot!(0:23,transpose(mean(sum(o_matrix, dims = 3)[:,1,1,:],dims=1)), c = 2, fillrange = zeros(24), fillcolor = 2, fillalpha = 0.2, label = "TS")
plot!(0:23,transpose(mean(sum(o_pi_matrix, dims = 3)[:,1,1,:],dims=1)), c = 3, fillrange = zeros(24), fillcolor = 3, fillalpha = 0.2, label = "PI")

day2 = plot(0:23,transpose(mean(p_limit_matrix[:,5,:],dims=1)),title = "Day 5",ylabel = "Power [kW]", xlabel = "Time-of-day [h]", yrange = (0,90), xrange = (0,23), legend = false)
#plot!(0:23,transpose(mean(p_limit_matrix[:,5,:],dims=1)) .+ buffer, color = 1, linestyle = :dot, fillrange = transpose(mean(p_limit_matrix[:,2,:],dims=1)), fillcolor = 1, fillalpha = 0.2, label = "Noise Tolerance")
plot!(0:23,transpose(mean(sum(o_matrix, dims = 3)[:,5,1,:],dims=1)), c = 2, fillrange = zeros(24), fillcolor = 2, fillalpha = 0.2, label = "TS")
plot!(0:23,transpose(mean(sum(o_pi_matrix, dims = 3)[:,5,1,:],dims=1)), c = 3, fillrange = zeros(24), fillcolor = 3, fillalpha = 0.2, label = "PI")


day5 = plot(0:23,transpose(mean(p_limit_matrix[:,25,:],dims=1)),title = "Day 25",ylabel = "Power [kW]", xlabel = "Time-of-day [h]", yrange = (0,90), xrange = (0,23), legend = false)
#plot!(0:23,transpose(mean(p_limit_matrix[:,5,:],dims=1)) .+ buffer, color = 1, linestyle = :dot, fillrange = transpose(mean(p_limit_matrix[:,5,:],dims=1)), fillcolor = 1, fillalpha = 0.2, label = "Noise Tolerance")
plot!(0:23,transpose(mean(sum(o_matrix, dims = 3)[:,25,1,:],dims=1)), c = 2, fillrange = zeros(24), fillcolor = 2, fillalpha = 0.2, label = "TS")
plot!(0:23,transpose(mean(sum(o_pi_matrix, dims = 3)[:,25,1,:],dims=1)), c = 3, fillrange = zeros(24), fillcolor = 3, fillalpha = 0.2, label = "PI")


day10 = plot(0:23,transpose(mean(p_limit_matrix[:,100,:],dims=1)),title = "Day 100",ylabel = "Power [kW]", xlabel = "Time-of-day [h]", yrange = (0,90), xrange = (0,23), legend = false)
#plot!(0:23,transpose(mean(p_limit_matrix[:,10,:],dims=1)) .+ buffer, color = 1, linestyle = :dot, fillrange = transpose(mean(p_limit_matrix[:,10,:],dims=1)), fillcolor = 1, fillalpha = 0.2, label = "Noise Tolerance")
plot!(0:23,transpose(mean(sum(o_matrix, dims = 3)[:,100,1,:],dims=1)), c = 2, fillrange = zeros(24), fillcolor = 2, fillalpha = 0.2, label = "TS")
plot!(0:23,transpose(mean(sum(o_pi_matrix, dims = 3)[:,100,1,:],dims=1)), c = 3, fillrange = zeros(24), fillcolor = 3, fillalpha = 0.2, label = "PI")


violationplots = plot(day1,day2,day5,day10, layout = (1,4), size = (1200,300))
savefig(violationplots,"Figures/violation plots.tex")


###############################
### INDIVIDUAL REGRET PLOTS ###
###############################
#=
individual_regret = Array{Float64}(undef,20,365,25)
min_individual_regret = Array{Float64}(undef,365,25)
max_individual_regret = Array{Float64}(undef,365,25)

for n in 1:25
    individual_regret[:,:,n] = sum(sqrt.((predictions_matrix[:,:,n,:] - o_matrix[:,:,n,:]).^2),dims=3)
    min_individual_regret[:,n] = minimum(sum(sqrt.((predictions_matrix[:,:,n,:] - o_matrix[:,:,n,:]).^2),dims=3),dims=1)
    max_individual_regret[:,n] = maximum(sum(sqrt.((predictions_matrix[:,:,n,:] - o_matrix[:,:,n,:]).^2),dims=3),dims=1)
end
=#
days = [1 2 5 10 25 50 100 365]
prosumers = [1 12 25]
theta_sim = zeros(length(days),length(prosumers),10,500)

for (index_i,i) in enumerate(days)
    for (index_n,n) in enumerate(prosumers)
        for k in 1:10
            if k == 4
                theta_sim[index_i,index_n,k,:] = rand(Normal(mean(thetas_mean_matrix[:,i,n,k],dims=1)[1],mean(thetas_var_matrix[:,i,n,k],dims=1)[1]),500)/3
            else
                theta_sim[index_i,index_n,k,:] = rand(Normal(mean(thetas_mean_matrix[:,i,n,k],dims=1)[1],mean(thetas_var_matrix[:,i,n,k],dims=1)[1]),500)
            end
        end
    end
end

#Calculation of theta values
size(mean(thetas_mean_matrix,dims=1)[1,:,:,:])
for n in prosumers
    for d in [1 5 25 100]
        println("Day $d, Prosumer $n: LW = ", round.((mean(thetas_mean_matrix,dims=1)[1,d,n,:] - 2.6980*mean(thetas_var_matrix,dims=1)[1,d,n,:]) ./ [1, 1, 1, 3, 1, 1, 1, 1, 1, 1], digits=4))
        println("Day $d, Prosumer $n: LQ = ", round.((mean(thetas_mean_matrix,dims=1)[1,d,n,:] - 0.6745*mean(thetas_var_matrix,dims=1)[1,d,n,:]) ./ [1, 1, 1, 3, 1, 1, 1, 1, 1, 1], digits=4))
        println("Day $d, Prosumer $n: AV = ", round.(mean(thetas_mean_matrix,dims=1)[1,d,n,:] ./ [1, 1, 1, 3, 1, 1, 1, 1, 1, 1], digits=4))
        println("Day $d, Prosumer $n: UQ = ", round.((mean(thetas_mean_matrix,dims=1)[1,d,n,:] + 0.6745*mean(thetas_var_matrix,dims=1)[1,d,n,:]) ./ [1, 1, 1, 3, 1, 1, 1, 1, 1, 1], digits = 4))
        println("Day $d, Prosumer $n: UW = ", round.((mean(thetas_mean_matrix,dims=1)[1,d,n,:] + 2.698*mean(thetas_var_matrix,dims=1)[1,d,n,:]) ./ [1, 1, 1, 3, 1, 1, 1, 1, 1, 1], digits = 4))
        println("")
    end
    println("------------------------------------------------------------")
end

#=
#Prosumer 1
day1n1= plot(title = "Day 1", legend = false, ylims=(-0.05,1.05),xticks = 1:10, ylabel = "Theta value")
violin!(transpose(theta_sim[1,1,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]/3; true_theta[1,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]; true_theta[1,k]],color =:red, lw = 2)
    end
end
savefig(day1n1,"Figures/day1n1.tex")

day2n1 = plot(title = "Day 2", legend = false, ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[2,1,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]/3; true_theta[1,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]; true_theta[1,k]],color =:red, lw = 2)
    end
end

day5n1 = plot(title = "Day 5", legend = false, ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[3,1,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]/3; true_theta[1,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]; true_theta[1,k]],color =:red, lw = 2)
    end
end

day10n1 = plot(title = "Day 10", legend = false, ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[4,1,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]/3; true_theta[1,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]; true_theta[1,k]],color =:red, lw = 2)
    end
end

day20n1 = plot(title = "Day 25", legend = false, ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[5,1,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]/3; true_theta[1,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]; true_theta[1,k]],color =:red, lw = 2)
    end
end

day50n1 = plot(title = "Day 50", legend = false, ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[6,1,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]/3; true_theta[1,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]; true_theta[1,k]],color =:red, lw = 2)
    end
end

day100n1 = plot(title = "Day 100", legend = false, ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[7,1,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]/3; true_theta[1,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]; true_theta[1,k]],color =:red, lw = 2)
    end
end

day365n1 = plot(title = "Day 365", legend = false, ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[8,1,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]/3; true_theta[1,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[1,k]; true_theta[1,k]],color =:red, lw = 2)
    end
end

#=
n1regretcurve = plot(mean(individual_regret,dims=1)[1,:,1],title = "Learning regret", label = "Average regret", xrange = (1,50),legend=:topright)
plot!(min_individual_regret[:,1], fillrange=max_individual_regret[:,1], line = false, fillcolor = 1, fillalpha= 0.2, label ="Regret range")
plot!(min_individual_regret[:,1], linestyle=:dot, c=:red, label = "Minimum Regret")
plot!(max_individual_regret[:,1], linestyle=:dot, c=:green, label = "Maximum Regret")
=#
# Prosumer 12

day1n12= plot( legend = false, ylims=(-0.05,1.05),xticks = 1:10,ylabel = "Theta value")
violin!(transpose(theta_sim[1,2,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]/3; true_theta[12,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]; true_theta[12,k]],color =:red, lw = 2)
    end
end

day2n12 = plot( legend = false, ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[2,2,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]/3; true_theta[12,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]; true_theta[12,k]],color =:red, lw = 2)
    end
end

day5n12 = plot( legend = false, ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[3,2,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]/3; true_theta[12,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]; true_theta[12,k]],color =:red, lw = 2)
    end
end

day10n12 = plot( legend = false, ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[4,2,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]/3; true_theta[12,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]; true_theta[12,k]],color =:red, lw = 2)
    end
end

day20n12 = plot( legend = false,ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[5,2,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]/3; true_theta[12,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]; true_theta[12,k]],color =:red, lw = 2)
    end
end

day50n12 = plot( legend = false,ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[6,2,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]/3; true_theta[12,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]; true_theta[12,k]],color =:red, lw = 2)
    end
end

day100n12 = plot( legend = false,ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[7,2,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]/3; true_theta[12,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]; true_theta[12,k]],color =:red, lw = 2)
    end
end

day365n12 = plot( legend = false,ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[8,2,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]/3; true_theta[12,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[12,k]; true_theta[12,k]],color =:red, lw = 2)
    end
end

#=
n12regretcurve = plot(mean(individual_regret,dims=1)[1,:,1],title = "Learning regret", xrange = (1,50),legend = :topright)
plot!(min_individual_regret[:,12], fillrange=max_individual_regret[:,1], line = false, fillcolor = 1, fillalpha= 0.2, label ="Regret range")
plot!(min_individual_regret[:,12], linestyle=:dot, c=:red, label = "Minimum Regret")
plot!(max_individual_regret[:,12], linestyle=:dot, c=:green, label = "Maximum Regret")
=#

#Prosumer 25

day1n25= plot( legend = false, xlabel = "Theta",ylims=(-0.05,1.05),xticks = 1:10,ylabel = "Theta value")
violin!(transpose(theta_sim[1,3,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]/3; true_theta[25,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]; true_theta[25,k]],color =:red, lw = 2)
    end
end

day2n25 = plot( legend = false, xlabel = "Theta",ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[2,3,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]/3; true_theta[25,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]; true_theta[25,k]],color =:red, lw = 2)
    end
end

day5n25 = plot( legend = false, xlabel = "Theta",ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[3,3,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]/3; true_theta[25,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]; true_theta[25,k]],color =:red, lw = 2)
    end
end

day10n25 = plot(legend = false, xlabel = "Theta",ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[4,3,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]/3; true_theta[25,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]; true_theta[25,k]],color =:red, lw = 2)
    end
end

day20n25 = plot(legend = false, xlabel = "Theta",ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[5,3,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]/3; true_theta[25,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]; true_theta[25,k]],color =:red, lw = 2)
    end
end

day50n25 = plot(legend = false, xlabel = "Theta",ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[6,3,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]/3; true_theta[25,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]; true_theta[25,k]],color =:red, lw = 2)
    end
end

day100n25 = plot(legend = false, xlabel = "Theta",ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[7,3,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]/3; true_theta[25,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]; true_theta[25,k]],color =:red, lw = 2)
    end
end

day365n25 = plot(legend = false, xlabel = "Theta",ylims=(-0.05,1.05),xticks = 1:10)
violin!(transpose(theta_sim[8,3,:,:]))
for k in 1:10
    if k==4
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]/3; true_theta[25,k]/3],color =:red, lw = 2)
    else
        plot!([(0.5 + k - 1); (1.5 + k - 1)],[true_theta[25,k]; true_theta[25,k]],color =:red, lw = 2)
    end
end

#=
n25regretcurve = plot(mean(individual_regret,dims=1)[1,:,1], label = "Average regret", xrange = (1,50), legend =:topright)
plot!(min_individual_regret[:,25], fillrange=max_individual_regret[:,1], line = false, fillcolor = 1, fillalpha= 0.2, label ="Regret range")
plot!(min_individual_regret[:,25], linestyle=:dot, c=:red, label = "Minimum Regret")
plot!(max_individual_regret[:,25], linestyle=:dot, c=:green, label = "Maximum Regret")
=#

individualthetaplots = plot(day1n1, day5n1, day20n1, day100n1, day1n12, day5n12, day20n12, day100n12, day1n25, day5n25, day20n25, day100n25, layout = (3,4), size = (1500,900), grid=false)
savefig(individualthetaplots,"Figures/individual_theta_plots_draft.tex")
=#

####################################
### NON-STATIONARITY REGRET PLOT ###
####################################
true_theta_20 =[0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 1.0 0.0; 
                0.5 0.5 0.0 0.0 1.0 0.0 1.0 0.0 0.0 1.0; 
                0.0 0.0 1.0 2.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.3 0.3 0.4 1.0 1.0 0.0 0.0 0.0 1.0 0.0; 
                0.8 0.2 0.0 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.3 0.2 0.5 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.4 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.5 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                0.2 0.4 0.4 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.9 0.1 0.0 3.0 1.0 0.0 1.0 0.0 1.0 0.0; 
                1.0 0.0 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 1.0 0.0 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.1 0.7 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.6 0.2 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.1 0.8 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.6 0.2 0.2 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.0 0.8 0.2 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.7 0.0 0.3 0.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.2 0.3 0.5 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.7 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0; 
                0.5 0.5 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 0.0 1.0 2.0 0.0 1.0 0.0 0.0 0.0 0.0; 
                ]

p_limit_20 = CSV.read("Results/nonstat_20_P_limit_m=1_i=365.csv", DataFrame)
p_limit_20_matrix = Array{Float64}(undef,365,24)
for row in eachrow(p_limit_20)
    for t in 1:24
        p_limit_20_matrix[Int64(row.I),t] = row[string(t-1)]
    end
end

#Data
nonstat_20_signatures_df = CSV.read("Results/nonstat_20_signature_m=1_i=365_n=25=.csv",DataFrame)
nonstat_20_signatures_pi_df = CSV.read("Results/nonstat_20_signature_pi_m=1_i=365_n=25=.csv",DataFrame)

nonstat_20_signatures_matrix = Array{Float64}(undef,365,25,10,24)
for row in eachrow(nonstat_20_signatures_df)
    for t in 1:24
        nonstat_20_signatures_matrix[Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
    end
end
nonstat_20_signatures_pi_matrix = Array{Float64}(undef,365,25,10,24)
for row in eachrow(nonstat_20_signatures_pi_df)
    for t in 1:24
        nonstat_20_signatures_pi_matrix[Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
    end
end

y_20 =  Array{Float64}(undef,365,25,24)
y_20_pi = Array{Float64}(undef,365,25,24)

p_im_20 = Array{Float64}(undef,365,24)
p_im_20_pi = Array{Float64}(undef,365,24)

p_ex_20 = Array{Float64}(undef,365,24)
p_ex_20_pi = Array{Float64}(undef,365,24)

p_pen_20 = Array{Float64}(undef,365,24)
p_pen_20_pi = Array{Float64}(undef,365,24)

cost_20 = Array{Float64}(undef,365)
cost_20_pi = Array{Float64}(undef,365)

cumulative_cost_20 = zeros(366)
cumulative_cost_20_pi = zeros(366)

for d in 1:365
    DA_prices = DA_price_matrix[d,:]
    if d <= 90 || d >= 273
        import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 1.2878, 1.2878, 1.2878, 1.2878, 0.4293, 0.4293, 0.4293]
    else
        import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.5580, 0.5580, 0.5580, 0.5580, 0.2146, 0.2146, 0.2146]
    end
    if d <= 150
        for n in 1:25
            y_20[d,n,:] = transpose(nonstat_20_signatures_matrix[d,n,:,:])*true_theta[n,:]
            y_20_pi[d,n,:] = transpose(nonstat_20_signatures_pi_matrix[d,n,:,:])*true_theta[n,:]

        end
    else
        for n in 1:25
            y_20[d,n,:] = transpose(nonstat_20_signatures_matrix[d,n,:,:])*true_theta_20[n,:]
            y_20_pi[d,n,:] = transpose(nonstat_20_signatures_pi_matrix[d,n,:,:])*true_theta_20[n,:]

        end
    end
    p_im_20[d,:] = max.(sum(y_20[d,:,:],dims=1),0)
    p_im_20_pi[d,:] = max.(sum(y_20_pi[d,:,:],dims=1),0)
    p_ex_20[d,:] = min.(sum(y_20[d,:,:],dims=1),0)
    p_ex_20_pi[d,:] = min.(sum(y_20_pi[d,:,:],dims=1),0)
    p_pen_20[d,:] = max.(p_im_20[d,:]-p_limit_20_matrix[d,:],0)
    p_pen_20_pi[d,:] = max.(p_im_20_pi[d,:]-p_limit_20_matrix[d,:],0)

    cost_20[d] = sum(p_im_20[d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_20[d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_20[d,t] for t in 1:24)
    cost_20_pi[d] = sum(p_im_20_pi[d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_20_pi[d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_20_pi[d,t] for t in 1:24)

    cumulative_cost_20[d+1] = cumulative_cost_20[d] + cost_20[d]
    cumulative_cost_20_pi[d+1] = cumulative_cost_20_pi[d] + cost_20_pi[d]

end

##################
### 40 PERCENT ###
##################
true_theta_40 =[0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 1.0 0.0; 
                0.5 0.5 0.0 0.0 1.0 0.0 1.0 0.0 0.0 1.0; 
                0.0 0.0 1.0 2.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.3 0.3 0.4 1.0 1.0 0.0 0.0 0.0 1.0 0.0; 
                0.8 0.2 0.0 0.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.3 0.2 0.5 1.0 1.0 0.0 0.0 0.0 1.0 0.0; 
                0.1 0.4 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.5 0.3 0.0 0.0 1.0 0.0 0.0 0.0 0.0; 
                0.2 0.4 0.4 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.9 0.1 0.0 3.0 1.0 0.0 1.0 0.0 1.0 0.0; 
                1.0 0.0 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 1.0 0.0 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.1 0.7 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.6 0.2 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.1 0.8 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.6 0.2 0.2 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.0 0.8 0.2 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.7 0.0 0.3 0.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.2 0.3 0.5 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.7 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0; 
                0.5 0.5 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 0.0 1.0 2.0 0.0 1.0 0.0 0.0 0.0 0.0; 
                ]

p_limit_40 = CSV.read("Results/nonstat_40_P_limit_m=1_i=365.csv", DataFrame)
p_limit_40_matrix = Array{Float64}(undef,365,24)
for row in eachrow(p_limit_20)
    for t in 1:24
        p_limit_40_matrix[Int64(row.I),t] = row[string(t-1)]
    end
end

nonstat_40_signatures_df = CSV.read("Results/nonstat_40_signature_m=1_i=365_n=25=.csv",DataFrame)
nonstat_40_signatures_pi_df = CSV.read("Results/nonstat_40_signature_pi_m=1_i=365_n=25=.csv",DataFrame)

nonstat_40_signatures_matrix = Array{Float64}(undef,365,25,10,24)
for row in eachrow(nonstat_40_signatures_df)
    for t in 1:24
        nonstat_40_signatures_matrix[Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
    end
end
nonstat_40_signatures_pi_matrix = Array{Float64}(undef,365,25,10,24)
for row in eachrow(nonstat_40_signatures_pi_df)
    for t in 1:24
        nonstat_40_signatures_pi_matrix[Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
    end
end

y_40 =  Array{Float64}(undef,365,25,24)
y_40_pi = Array{Float64}(undef,365,25,24)

p_im_40 = Array{Float64}(undef,365,24)
p_im_40_pi = Array{Float64}(undef,365,24)

p_ex_40 = Array{Float64}(undef,365,24)
p_ex_40_pi = Array{Float64}(undef,365,24)

p_pen_40 = Array{Float64}(undef,365,24)
p_pen_40_pi = Array{Float64}(undef,365,24)

cost_40 = Array{Float64}(undef,365)
cost_40_pi = Array{Float64}(undef,365)

cumulative_cost_40 = zeros(366)
cumulative_cost_40_pi = zeros(366)

for d in 1:365
    DA_prices = DA_price_matrix[d,:]
    if d <= 90 || d >= 273
        import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 1.2878, 1.2878, 1.2878, 1.2878, 0.4293, 0.4293, 0.4293]
    else
        import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.5580, 0.5580, 0.5580, 0.5580, 0.2146, 0.2146, 0.2146]
    end
    if d <= 150
        for n in 1:25
            y_40[d,n,:] = transpose(nonstat_40_signatures_matrix[d,n,:,:])*true_theta[n,:]
            y_40_pi[d,n,:] = transpose(nonstat_40_signatures_pi_matrix[d,n,:,:])*true_theta[n,:]

        end
    else
        for n in 1:25
            y_40[d,n,:] = transpose(nonstat_40_signatures_matrix[d,n,:,:])*true_theta_40[n,:]
            y_40_pi[d,n,:] = transpose(nonstat_40_signatures_pi_matrix[d,n,:,:])*true_theta_40[n,:]

        end
    end
    p_im_40[d,:] = max.(sum(y_40[d,:,:],dims=1),0)
    p_im_40_pi[d,:] = max.(sum(y_40_pi[d,:,:],dims=1),0)
    p_ex_40[d,:] = min.(sum(y_40[d,:,:],dims=1),0)
    p_ex_40_pi[d,:] = min.(sum(y_40_pi[d,:,:],dims=1),0)
    p_pen_40[d,:] = max.(p_im_40[d,:]-p_limit_40_matrix[d,:],0)
    p_pen_40_pi[d,:] = max.(p_im_40_pi[d,:]-p_limit_40_matrix[d,:],0)

    cost_40[d] = sum(p_im_40[d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_40[d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_40[d,t] for t in 1:24)
    cost_40_pi[d] = sum(p_im_40_pi[d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_40_pi[d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_40_pi[d,t] for t in 1:24)

    cumulative_cost_40[d+1] = cumulative_cost_40[d] + cost_40[d]
    cumulative_cost_40_pi[d+1] = cumulative_cost_40_pi[d] + cost_40_pi[d]

end

##################
### 60 PERCENT ###
##################
true_theta_60 =[0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 1.0 0.0; 
                0.5 0.5 0.0 0.0 1.0 0.0 1.0 0.0 0.0 1.0; 
                0.0 0.0 1.0 2.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.3 0.3 0.4 1.0 1.0 0.0 0.0 0.0 1.0 0.0; 
                0.8 0.2 0.0 0.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.3 0.2 0.5 1.0 1.0 0.0 0.0 0.0 1.0 0.0; 
                0.1 0.4 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.5 0.3 0.0 0.0 1.0 0.0 0.0 0.0 0.0; 
                0.2 0.4 0.4 1.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.9 0.1 0.0 3.0 1.0 1.0 0.0 1.0 0.0 0.0; 
                1.0 0.0 0.0 0.0 1.0 0.0 1.0 0.0 0.0 1.0; 
                0.0 1.0 0.0 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.1 0.7 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.6 0.2 1.0 1.0 0.0 0.0 0.0 0.0 1.0; 
                0.1 0.1 0.8 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.6 0.2 0.2 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.0 0.8 0.2 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.7 0.0 0.3 0.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.2 0.3 0.5 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.7 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0; 
                0.5 0.5 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 0.0 1.0 2.0 0.0 1.0 0.0 0.0 0.0 0.0; 
                ]

p_limit_60 = CSV.read("Results/nonstat_60_P_limit_m=1_i=365.csv", DataFrame)
p_limit_60_matrix = Array{Float64}(undef,365,24)
for row in eachrow(p_limit_20)
    for t in 1:24
        p_limit_60_matrix[Int64(row.I),t] = row[string(t-1)]
    end
end

nonstat_60_signatures_df = CSV.read("Results/nonstat_60_signature_m=1_i=365_n=25=.csv",DataFrame)
nonstat_60_signatures_pi_df = CSV.read("Results/nonstat_60_signature_pi_m=1_i=365_n=25=.csv",DataFrame)

nonstat_60_signatures_matrix = Array{Float64}(undef,365,25,10,24)
for row in eachrow(nonstat_60_signatures_df)
    for t in 1:24
        nonstat_60_signatures_matrix[Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
    end
end
nonstat_60_signatures_pi_matrix = Array{Float64}(undef,365,25,10,24)
for row in eachrow(nonstat_60_signatures_pi_df)
    for t in 1:24
        nonstat_60_signatures_pi_matrix[Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
    end
end

y_60 =  Array{Float64}(undef,365,25,24)
y_60_pi = Array{Float64}(undef,365,25,24)

p_im_60 = Array{Float64}(undef,365,24)
p_im_60_pi = Array{Float64}(undef,365,24)

p_ex_60 = Array{Float64}(undef,365,24)
p_ex_60_pi = Array{Float64}(undef,365,24)

p_pen_60 = Array{Float64}(undef,365,24)
p_pen_60_pi = Array{Float64}(undef,365,24)

cost_60 = Array{Float64}(undef,365)
cost_60_pi = Array{Float64}(undef,365)

cumulative_cost_60 = zeros(366)
cumulative_cost_60_pi = zeros(366)

for d in 1:365
    DA_prices = DA_price_matrix[d,:]
    if d <= 90 || d >= 273
        import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 1.2878, 1.2878, 1.2878, 1.2878, 0.4293, 0.4293, 0.4293]
    else
        import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.5580, 0.5580, 0.5580, 0.5580, 0.2146, 0.2146, 0.2146]
    end
    if d <= 150
        for n in 1:25
            y_60[d,n,:] = transpose(nonstat_60_signatures_matrix[d,n,:,:])*true_theta[n,:]
            y_60_pi[d,n,:] = transpose(nonstat_60_signatures_pi_matrix[d,n,:,:])*true_theta[n,:]

        end
    else
        for n in 1:25
            y_60[d,n,:] = transpose(nonstat_60_signatures_matrix[d,n,:,:])*true_theta_60[n,:]
            y_60_pi[d,n,:] = transpose(nonstat_60_signatures_pi_matrix[d,n,:,:])*true_theta_60[n,:]

        end
    end
    p_im_60[d,:] = max.(sum(y_60[d,:,:],dims=1),0)
    p_im_60_pi[d,:] = max.(sum(y_60_pi[d,:,:],dims=1),0)
    p_ex_60[d,:] = min.(sum(y_60[d,:,:],dims=1),0)
    p_ex_60_pi[d,:] = min.(sum(y_60_pi[d,:,:],dims=1),0)
    p_pen_60[d,:] = max.(p_im_60[d,:]-p_limit_60_matrix[d,:],0)
    p_pen_60_pi[d,:] = max.(p_im_60_pi[d,:]-p_limit_60_matrix[d,:],0)

    cost_60[d] = sum(p_im_60[d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_60[d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_60[d,t] for t in 1:24)
    cost_60_pi[d] = sum(p_im_60_pi[d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_60_pi[d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_60_pi[d,t] for t in 1:24)

    cumulative_cost_60[d+1] = cumulative_cost_60[d] + cost_60[d]
    cumulative_cost_60_pi[d+1] = cumulative_cost_60_pi[d] + cost_60_pi[d]

end

##################
### 80 PERCENT ###
##################
true_theta_80 =[0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 1.0 0.0; 
                0.5 0.5 0.0 0.0 1.0 0.0 1.0 0.0 0.0 1.0; 
                0.0 0.0 1.0 2.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.3 0.3 0.4 1.0 1.0 0.0 0.0 0.0 1.0 0.0; 
                0.8 0.2 0.0 0.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.3 0.2 0.5 1.0 1.0 0.0 0.0 0.0 1.0 0.0; 
                0.1 0.4 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.5 0.3 0.0 0.0 1.0 0.0 0.0 0.0 0.0; 
                0.2 0.4 0.4 1.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.9 0.1 0.0 3.0 1.0 1.0 0.0 1.0 0.0 0.0; 
                1.0 0.0 0.0 0.0 1.0 0.0 1.0 0.0 0.0 1.0; 
                0.0 1.0 0.0 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.1 0.7 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.6 0.2 1.0 1.0 0.0 0.0 1.0 0.0 0.0; 
                0.1 0.1 0.8 0.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.6 0.2 0.2 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.0 0.8 0.2 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.7 0.0 0.3 0.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.2 0.3 0.5 1.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.7 0.3 0.0 0.0 0.0 1.0 0.0 0.0 0.0 1.0; 
                0.5 0.5 0.0 0.0 1.0 1.0 0.0 0.0 1.0 0.0; 
                0.0 0.0 1.0 2.0 0.0 1.0 0.0 0.0 0.0 0.0; 
                ]

p_limit_80 = CSV.read("Results/nonstat_80_P_limit_m=1_i=365.csv", DataFrame)
p_limit_80_matrix = Array{Float64}(undef,365,24)
for row in eachrow(p_limit_20)
    for t in 1:24
        p_limit_80_matrix[Int64(row.I),t] = row[string(t-1)]
    end
end

nonstat_80_signatures_df = CSV.read("Results/nonstat_80_signature_m=1_i=365_n=25=.csv",DataFrame)
nonstat_80_signatures_pi_df = CSV.read("Results/nonstat_80_signature_pi_m=1_i=365_n=25=.csv",DataFrame)


nonstat_80_signatures_matrix = Array{Float64}(undef,365,25,10,24)
for row in eachrow(nonstat_80_signatures_df)
    for t in 1:24
        nonstat_80_signatures_matrix[Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
    end
end
nonstat_80_signatures_pi_matrix = Array{Float64}(undef,365,25,10,24)
for row in eachrow(nonstat_80_signatures_pi_df)
    for t in 1:24
        nonstat_80_signatures_pi_matrix[Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
    end
end

y_80 =  Array{Float64}(undef,365,25,24)
y_80_pi = Array{Float64}(undef,365,25,24)

p_im_80 = Array{Float64}(undef,365,24)
p_im_80_pi = Array{Float64}(undef,365,24)

p_ex_80 = Array{Float64}(undef,365,24)
p_ex_80_pi = Array{Float64}(undef,365,24)

p_pen_80 = Array{Float64}(undef,365,24)
p_pen_80_pi = Array{Float64}(undef,365,24)

cost_80 = Array{Float64}(undef,365)
cost_80_pi = Array{Float64}(undef,365)

cumulative_cost_80 = zeros(366)
cumulative_cost_80_pi = zeros(366)

for d in 1:365
    DA_prices = DA_price_matrix[d,:]
    if d <= 90 || d >= 273
        import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 1.2878, 1.2878, 1.2878, 1.2878, 0.4293, 0.4293, 0.4293]
    else
        import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.5580, 0.5580, 0.5580, 0.5580, 0.2146, 0.2146, 0.2146]
    end
    if d <= 150
        for n in 1:25
            y_80[d,n,:] = transpose(nonstat_80_signatures_matrix[d,n,:,:])*true_theta[n,:]
            y_80_pi[d,n,:] = transpose(nonstat_80_signatures_pi_matrix[d,n,:,:])*true_theta[n,:]

        end
    else
        for n in 1:25
            y_80[d,n,:] = transpose(nonstat_80_signatures_matrix[d,n,:,:])*true_theta_80[n,:]
            y_80_pi[d,n,:] = transpose(nonstat_80_signatures_pi_matrix[d,n,:,:])*true_theta_80[n,:]

        end
    end
    p_im_80[d,:] = max.(sum(y_80[d,:,:],dims=1),0)
    p_im_80_pi[d,:] = max.(sum(y_80_pi[d,:,:],dims=1),0)
    p_ex_80[d,:] = min.(sum(y_80[d,:,:],dims=1),0)
    p_ex_80_pi[d,:] = min.(sum(y_80_pi[d,:,:],dims=1),0)
    p_pen_80[d,:] = max.(p_im_80[d,:]-p_limit_80_matrix[d,:],0)
    p_pen_80_pi[d,:] = max.(p_im_80_pi[d,:]-p_limit_80_matrix[d,:],0)

    cost_80[d] = sum(p_im_80[d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_80[d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_80[d,t] for t in 1:24)
    cost_80_pi[d] = sum(p_im_80_pi[d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_80_pi[d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_80_pi[d,t] for t in 1:24)

    cumulative_cost_80[d+1] = cumulative_cost_80[d] + cost_80[d]
    cumulative_cost_80_pi[d+1] = cumulative_cost_80_pi[d] + cost_80_pi[d]

end

###################
### 100 PERCENT ###
###################
true_theta_100=[0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 1.0 0.0; 
                0.5 0.5 0.0 0.0 1.0 0.0 1.0 0.0 0.0 1.0; 
                0.0 0.0 1.0 2.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                0.5 0.0 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.3 0.3 0.4 1.0 1.0 0.0 0.0 0.0 1.0 0.0; 
                0.8 0.2 0.0 0.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.3 0.2 0.5 1.0 1.0 0.0 0.0 0.0 1.0 0.0; 
                0.1 0.4 0.5 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.5 0.3 0.0 0.0 1.0 0.0 0.0 0.0 0.0; 
                0.2 0.4 0.4 1.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.9 0.1 0.0 3.0 1.0 1.0 0.0 1.0 0.0 0.0; 
                1.0 0.0 0.0 0.0 1.0 0.0 1.0 0.0 0.0 1.0; 
                0.0 1.0 0.0 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.1 0.7 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.2 0.6 0.2 1.0 1.0 0.0 0.0 1.0 0.0 0.0; 
                0.1 0.1 0.8 0.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.1 0.8 0.1 1.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.6 0.2 0.2 3.0 1.0 0.0 0.0 0.0 0.0 0.0; 
                0.0 0.8 0.2 0.0 0.0 0.0 0.0 0.0 0.0 0.0; 
                0.7 0.0 0.3 0.0 0.0 1.0 0.0 1.0 0.0 0.0; 
                0.2 0.3 0.5 1.0 0.0 0.0 1.0 0.0 0.0 1.0; 
                0.7 0.3 0.0 0.0 0.0 0.0 1.0 0.0 1.0 0.0; 
                0.5 0.5 0.0 0.0 1.0 0.0 0.0 1.0 0.0 1.0; 
                0.0 0.0 1.0 2.0 0.0 0.0 1.0 0.0 0.0 0.0; 
                ]

p_limit_100 = CSV.read("Results/nonstat_100_P_limit_m=1_i=365.csv", DataFrame)
p_limit_100_matrix = Array{Float64}(undef,365,24)
for row in eachrow(p_limit_20)
    for t in 1:24
        p_limit_100_matrix[Int64(row.I),t] = row[string(t-1)]
    end
end

nonstat_100_signatures_df = CSV.read("Results/nonstat_100_signature_m=1_i=365_n=25=.csv",DataFrame)
nonstat_100_signatures_pi_df = CSV.read("Results/nonstat_100_signature_pi_m=1_i=365_n=25=.csv",DataFrame)

nonstat_100_signatures_matrix = Array{Float64}(undef,365,25,10,24)
for row in eachrow(nonstat_100_signatures_df)
    for t in 1:24
        nonstat_100_signatures_matrix[Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
    end
end

nonstat_100_signatures_pi_matrix = Array{Float64}(undef,365,25,10,24)
for row in eachrow(nonstat_100_signatures_pi_df)
    for t in 1:24
        nonstat_100_signatures_pi_matrix[Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
    end
end

y_100 =  Array{Float64}(undef,365,25,24)
y_100_pi = Array{Float64}(undef,365,25,24)

p_im_100 = Array{Float64}(undef,365,24)
p_im_100_pi = Array{Float64}(undef,365,24)

p_ex_100 = Array{Float64}(undef,365,24)
p_ex_100_pi = Array{Float64}(undef,365,24)

p_pen_100 = Array{Float64}(undef,365,24)
p_pen_100_pi = Array{Float64}(undef,365,24)

cost_100 = Array{Float64}(undef,365)
cost_100_pi = Array{Float64}(undef,365)

cumulative_cost_100 = zeros(366)
cumulative_cost_100_pi = zeros(366)

for d in 1:365
    DA_prices = DA_price_matrix[d,:]
    if d <= 90 || d >= 273
        import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 1.2878, 1.2878, 1.2878, 1.2878, 0.4293, 0.4293, 0.4293]
    else
        import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.5580, 0.5580, 0.5580, 0.5580, 0.2146, 0.2146, 0.2146]
    end
    if d <= 150
        for n in 1:25
            y_100[d,n,:] = transpose(nonstat_100_signatures_matrix[d,n,:,:])*true_theta[n,:]
            y_100_pi[d,n,:] = transpose(nonstat_100_signatures_pi_matrix[d,n,:,:])*true_theta[n,:]

        end
    else
        for n in 1:25
            y_100[d,n,:] = transpose(nonstat_100_signatures_matrix[d,n,:,:])*true_theta_100[n,:]
            y_100_pi[d,n,:] = transpose(nonstat_100_signatures_pi_matrix[d,n,:,:])*true_theta_100[n,:]

        end
    end
    p_im_100[d,:] = max.(sum(y_100[d,:,:],dims=1),0)
    p_im_100_pi[d,:] = max.(sum(y_100_pi[d,:,:],dims=1),0)
    p_ex_100[d,:] = min.(sum(y_100[d,:,:],dims=1),0)
    p_ex_100_pi[d,:] = min.(sum(y_100_pi[d,:,:],dims=1),0)
    p_pen_100[d,:] = max.(p_im_100[d,:]-p_limit_100_matrix[d,:],0)
    p_pen_100_pi[d,:] = max.(p_im_100_pi[d,:]-p_limit_100_matrix[d,:],0)

    cost_100[d] = sum(p_im_100[d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_100[d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_100[d,t] for t in 1:24)
    cost_100_pi[d] = sum(p_im_100_pi[d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_100_pi[d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_100_pi[d,t] for t in 1:24)

    cumulative_cost_100[d+1] = cumulative_cost_100[d] + cost_100[d]
    cumulative_cost_100_pi[d+1] = cumulative_cost_100_pi[d] + cost_100_pi[d]

end

#########################
### RESET 100 PERCENT ###
#########################
reset_nonstat_100_signatures_df = CSV.read("Results/reset_nonstat_100_signature_m=1_i=365_n=25=.csv",DataFrame)
reset_nonstat_100_signatures_pi_df = CSV.read("Results/reset_nonstat_100_signature_pi_m=1_i=365_n=25=.csv",DataFrame)

reset_nonstat_100_signatures_matrix = Array{Float64}(undef,365,25,10,24)
for row in eachrow(reset_nonstat_100_signatures_df)
    for t in 1:24
        reset_nonstat_100_signatures_matrix[Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
    end
end

reset_nonstat_100_signatures_pi_matrix = Array{Float64}(undef,365,25,10,24)
for row in eachrow(reset_nonstat_100_signatures_pi_df)
    for t in 1:24
        reset_nonstat_100_signatures_pi_matrix[Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
    end
end

y_100_reset =  Array{Float64}(undef,365,25,24)
y_100_reset_pi = Array{Float64}(undef,365,25,24)

p_im_100_reset = Array{Float64}(undef,365,24)
p_im_100_reset_pi = Array{Float64}(undef,365,24)

p_ex_100_reset = Array{Float64}(undef,365,24)
p_ex_100_reset_pi = Array{Float64}(undef,365,24)

p_pen_100_reset = Array{Float64}(undef,365,24)
p_pen_100_reset_pi = Array{Float64}(undef,365,24)

cost_100_reset = Array{Float64}(undef,365)
cost_100_reset_pi = Array{Float64}(undef,365)

cumulative_cost_100_reset = zeros(366)
cumulative_cost_100_reset_pi = zeros(366)

for d in 1:365
    DA_prices = DA_price_matrix[d,:]
    if d <= 90 || d >= 273
        import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 1.2878, 1.2878, 1.2878, 1.2878, 0.4293, 0.4293, 0.4293]
    else
        import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.5580, 0.5580, 0.5580, 0.5580, 0.2146, 0.2146, 0.2146]
    end
    if d <= 150
        for n in 1:25
            y_100_reset[d,n,:] = transpose(reset_nonstat_100_signatures_matrix[d,n,:,:])*true_theta[n,:]
            y_100_reset_pi[d,n,:] = transpose(reset_nonstat_100_signatures_pi_matrix[d,n,:,:])*true_theta[n,:]

        end
    else
        for n in 1:25
            y_100_reset[d,n,:] = transpose(reset_nonstat_100_signatures_matrix[d,n,:,:])*true_theta_100[n,:]
            y_100_reset_pi[d,n,:] = transpose(reset_nonstat_100_signatures_pi_matrix[d,n,:,:])*true_theta_100[n,:]

        end
    end
    p_im_100_reset[d,:] = max.(sum(y_100_reset[d,:,:],dims=1),0)
    p_im_100_reset_pi[d,:] = max.(sum(y_100_reset_pi[d,:,:],dims=1),0)
    p_ex_100_reset[d,:] = min.(sum(y_100_reset[d,:,:],dims=1),0)
    p_ex_100_reset_pi[d,:] = min.(sum(y_100_reset_pi[d,:,:],dims=1),0)
    p_pen_100_reset[d,:] = max.(p_im_100_reset[d,:]-p_limit_100_matrix[d,:],0)
    p_pen_100_reset_pi[d,:] = max.(p_im_100_reset_pi[d,:]-p_limit_100_matrix[d,:],0)

    cost_100_reset[d] = sum(p_im_100_reset[d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_100_reset[d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_100_reset[d,t] for t in 1:24)
    cost_100_reset_pi[d] = sum(p_im_100_reset_pi[d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_100_reset_pi[d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_100_reset_pi[d,t] for t in 1:24)

    cumulative_cost_100_reset[d+1] = cumulative_cost_100_reset[d] + cost_100_reset[d]
    cumulative_cost_100_reset_pi[d+1] = cumulative_cost_100_reset_pi[d] + cost_100_reset_pi[d]

end


pgfplotsx()
nonstatplot = plot(cumulative_cost_20 - cumulative_cost_20_pi)
plot!(cumulative_cost_40 - cumulative_cost_40_pi)
plot!(cumulative_cost_60 - cumulative_cost_60_pi)
plot!(cumulative_cost_80 - cumulative_cost_80_pi)
plot!(cumulative_cost_100 - cumulative_cost_100_pi)
plot!(cumulative_cost_100_reset - cumulative_cost_100_reset_pi)
savefig(nonstatplot,"Figures/Nonstationarity Plot.tex")
#lens!([1, 150], [0, 30000], inset = (1, bbox(0.1, 0.1, 0.4, 0.4)),ratio=1)

plot(cost_20 - cost_20_pi)
plot!(cost_40 - cost_40_pi)
plot!(cost_60 - cost_60_pi)
plot!(cost_80 - cost_80_pi)
plot!(cost_100 - cost_100_pi)
plot!(cost_100_reset - cost_100_reset_pi)


# nonstat_40_signatures_df = CSV.read("New Results/nonstat_100_signature_m=1_i=365_n=25=.csv",DataFrame)
# nonstat_40_signatures_matrix = Array{Float64}(undef,1,365,25,10,24)
# for row in eachrow(nonstat_40_signatures_df)
#     for t in 1:24
#         nonstat_40_signatures_matrix[Int64(row.M),Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
#     end
# end

# nonstat_100_signatures_df = CSV.read("New Results/nonstat_100_signature_m=1_i=365_n=25=.csv",DataFrame)
# nonstat_100_signatures_matrix = Array{Float64}(undef,1,365,25,10,24)
# for row in eachrow(nonstat_100_signatures_df)
#     for t in 1:24
#         nonstat_100_signatures_matrix[Int64(row.M),Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
#     end
# end

# nonstat_100_signatures_df = CSV.read("New Results/nonstat_100_signature_m=1_i=365_n=25=.csv",DataFrame)
# nonstat_100_signatures_matrix = Array{Float64}(undef,1,365,25,10,24)
# for row in eachrow(nonstat_100_signatures_df)
#     for t in 1:24
#         nonstat_100_signatures_matrix[Int64(row.M),Int64(row.I),Int64(row.N),Int64(row.K),t] = row[string(t-1)]
#     end
# end


# nonstat_20_y_tilde = Array{Float64}(undef,1,365,25,24)
# nonstat_40_y_tilde = Array{Float64}(undef,1,365,25,24)
# nonstat_60_y_tilde = Array{Float64}(undef,1,365,25,24)
# nonstat_80_y_tilde = Array{Float64}(undef,1,365,25,24)
# nonstat_100_y_tilde = Array{Float64}(undef,1,365,25,24)
# nonstat_100_reset_y_tilde = Array{Float64}(undef,1,365,25,24)

# nonstat_20_p_im_tilde = Array{Float64}(undef,1,365,24)
# nonstat_40_p_im_tilde = Array{Float64}(undef,1,365,24)
# nonstat_60_p_im_tilde = Array{Float64}(undef,1,365,24)
# nonstat_80_p_im_tilde = Array{Float64}(undef,1,365,24)
# nonstat_100_p_im_tilde = Array{Float64}(undef,1,365,24)
# nonstat_100_reset_p_im_tilde = Array{Float64}(undef,1,365,24)
# p_ex_tilde = Array{Float64}(undef,1,365,24)
# p_pen_tilde = Array{Float64}(undef,1,365,24)
# cost_tilde = Array{Float64}(undef,1,365)
# cumulative_cost_tilde = zeros(20,366)

# for i in 1:20
#     for d in 1:365
#         DA_prices = DA_price_matrix[d,:]
#         if d <= 90 || d >= 273
#             import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 1.2878, 1.2878, 1.2878, 1.2878, 0.4293, 0.4293, 0.4293]
#         else
#             import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.5580, 0.5580, 0.5580, 0.5580, 0.2146, 0.2146, 0.2146]
#         end
#         for n in 1:25
#             y_tilde[i,d,n,:] = transpose(signatures_matrix[i,d,n,:,:])*true_theta[n,:]
#         end
#         p_im_tilde[i,d,:] = max.(sum(y_tilde[i,d,:,:],dims=1),0)
#         p_ex_tilde[i,d,:] = min.(sum(y_tilde[i,d,:,:],dims=1),0)
#         p_pen_tilde[i,d,:] = max.(p_im_tilde[i,d,:]-p_limit_matrix[i,d,:],0)
#         cost_tilde[i,d] = sum(p_im_tilde[i,d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_tilde[i,d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_tilde[i,d,t] for t in 1:24)
#         cumulative_cost_tilde[i,d+1] = cumulative_cost_tilde[i,d] + cost_tilde[i,d]
#     end
# end


# o_nonstat_matrix = Array{Float64}(undef,1,365,25,24)
# o_nonstat_pi_matrix = Array{Float64}(undef,1,365,25,24)

# ### --- 20% --- ###
# o_nonstat_20_df = CSV.read("Results/nonstat_observations_m=20_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_20_df_1 = CSV.read("Results/nonstat_20_observations_m=1_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_20_df_2 = CSV.read("Results/nonstat_20_observations_m=2_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_20_df_3 = CSV.read("Results/nonstat_20_observations_m=3_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_20_df_4 = CSV.read("Results/nonstat_20_observations_m=4_i=100_n=25_r=0.5.csv",DataFrame)

# o_20_df = vcat(o_nonstat_20_df, o_nonstat_20_df_1, o_nonstat_20_df_2, o_nonstat_20_df_3, o_nonstat_20_df_4)
# o_20_matrix = zeros(5,100,25,24)

# for row in eachrow(o_20_df)
#     for t in 0:23
#         K = string(t)
#         if row.M == 20.0
#             o_20_matrix[5,Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         else
#             o_20_matrix[Int64(row.M),Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         end
#     end
# end

# ### --- 40% --- ###
# o_nonstat_40_df = CSV.read("Results/nonstat_observations_m=40_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_40_df_1 = CSV.read("Results/nonstat_40_observations_m=1_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_40_df_2 = CSV.read("Results/nonstat_40_observations_m=2_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_40_df_3 = CSV.read("Results/nonstat_40_observations_m=3_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_40_df_4 = CSV.read("Results/nonstat_40_observations_m=4_i=100_n=25_r=0.5.csv",DataFrame)

# o_40_df = vcat(o_nonstat_40_df, o_nonstat_40_df_1, o_nonstat_40_df_2, o_nonstat_40_df_3, o_nonstat_40_df_4)
# o_40_matrix = zeros(5,100,25,24)

# for row in eachrow(o_40_df)
#     for t in 0:23
#         K = string(t)
#         if row.M == 40.0
#             o_40_matrix[5,Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         else
#             o_40_matrix[Int64(row.M),Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         end
#     end
# end

# ### --- 60% --- ###
# o_nonstat_60_df = CSV.read("Results/nonstat_observations_m=60_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_60_df_1 = CSV.read("Results/nonstat_60_observations_m=1_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_60_df_2 = CSV.read("Results/nonstat_60_observations_m=2_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_60_df_3 = CSV.read("Results/nonstat_60_observations_m=3_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_60_df_4 = CSV.read("Results/nonstat_60_observations_m=4_i=100_n=25_r=0.5.csv",DataFrame)

# o_60_df = vcat(o_nonstat_60_df, o_nonstat_60_df_1, o_nonstat_60_df_2, o_nonstat_60_df_3, o_nonstat_60_df_4)
# o_60_matrix = zeros(5,100,25,24)

# for row in eachrow(o_60_df)
#     for t in 0:23
#         K = string(t)
#         if row.M == 60.0
#             o_60_matrix[5,Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         else
#             o_60_matrix[Int64(row.M),Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         end
#     end
# end

# ### --- 80% --- ###
# o_nonstat_80_df = CSV.read("Results/nonstat_observations_m=80_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_80_df_1 = CSV.read("Results/nonstat_80_observations_m=1_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_80_df_2 = CSV.read("Results/nonstat_80_observations_m=2_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_80_df_3 = CSV.read("Results/nonstat_80_observations_m=3_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_80_df_4 = CSV.read("Results/nonstat_80_observations_m=4_i=100_n=25_r=0.5.csv",DataFrame)

# o_80_df = vcat(o_nonstat_80_df, o_nonstat_80_df_1, o_nonstat_80_df_2, o_nonstat_80_df_3, o_nonstat_80_df_4)
# o_80_matrix = zeros(5,100,25,24)

# for row in eachrow(o_80_df)
#     for t in 0:23
#         K = string(t)
#         if row.M == 80.0
#             o_80_matrix[5,Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         else
#             o_80_matrix[Int64(row.M),Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         end
#     end
# end

# ### --- 100% --- ###
# o_nonstat_100_df = CSV.read("Results/nonstat_observations_m=1_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_100_df_1 = CSV.read("Results/nonstat_100_observations_m=1_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_100_df_2 = CSV.read("Results/nonstat_100_observations_m=2_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_100_df_3 = CSV.read("Results/nonstat_100_observations_m=3_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_100_df_4 = CSV.read("Results/nonstat_100_observations_m=4_i=100_n=25_r=0.5.csv",DataFrame)

# o_100_df = vcat(o_nonstat_100_df_1, o_nonstat_100_df_2, o_nonstat_100_df_3, o_nonstat_100_df_4)
# o_100_matrix = zeros(5,100,25,24)

# for row in eachrow(o_100_df)
#     for t in 0:23
#         K = string(t)
#         if row.M == 100.0
#             o_100_matrix[5,Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         else
#             o_100_matrix[Int64(row.M),Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         end
#     end
# end

# for row in eachrow(o_nonstat_100_df)
#     for t in 0:23
#         K = string(t)
#         o_100_matrix[5,Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#     end
# end
# ###########################
# ### PERFECT INFORMATION ###
# ###########################

# ### 20 PERCENT CHANGE ###
# o_nonstat_pi_20_df = CSV.read("Results/nonstat_observations_PI_m=20_i=100_n=25_r=0.5.csv",DataFrame) 
# o_nonstat_pi_20_df_1 = CSV.read("Results/nonstat_20_observations_PI_m=1_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_pi_20_df_2 = CSV.read("Results/nonstat_20_observations_PI_m=2_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_pi_20_df_3 = CSV.read("Results/nonstat_20_observations_PI_m=3_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_pi_20_df_4 = CSV.read("Results/nonstat_20_observations_PI_m=4_i=100_n=25_r=0.5.csv",DataFrame)

# o_20_pi_df = vcat(o_nonstat_pi_20_df, o_nonstat_pi_20_df_1, o_nonstat_pi_20_df_2, o_nonstat_pi_20_df_3, o_nonstat_pi_20_df_4)
# o_20_pi_matrix = zeros(5,100,25,24)

# for row in eachrow(o_20_pi_df)
#     for t in 0:23
#         K = string(t)
#         if row.M == 20.0
#             o_20_pi_matrix[5,Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         else
#             o_20_pi_matrix[Int64(row.M),Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         end
#     end
# end

# ### 40 PERCENT CHANGE ###
# o_nonstat_pi_40_df = CSV.read("Results/nonstat_observations_PI_m=40_i=100_n=25_r=0.5.csv",DataFrame) 
# o_nonstat_pi_40_df_1 = CSV.read("Results/nonstat_40_observations_PI_m=1_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_pi_40_df_2 = CSV.read("Results/nonstat_40_observations_PI_m=2_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_pi_40_df_3 = CSV.read("Results/nonstat_40_observations_PI_m=3_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_pi_40_df_4 = CSV.read("Results/nonstat_40_observations_PI_m=4_i=100_n=25_r=0.5.csv",DataFrame)

# o_40_pi_df = vcat(o_nonstat_pi_40_df, o_nonstat_pi_40_df_1, o_nonstat_pi_40_df_2, o_nonstat_pi_40_df_3, o_nonstat_pi_40_df_4)
# o_40_pi_matrix = zeros(5,100,25,24)

# for row in eachrow(o_40_pi_df)
#     for t in 0:23
#         K = string(t)
#         if row.M == 40.0
#             o_40_pi_matrix[5,Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         else
#             o_40_pi_matrix[Int64(row.M),Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         end
#     end
# end

# ### 60 PERCENT CHANGE ###
# o_nonstat_pi_60_df = CSV.read("Results/nonstat_observations_PI_m=60_i=100_n=25_r=0.5.csv",DataFrame) 
# o_nonstat_pi_60_df_1 = CSV.read("Results/nonstat_60_observations_PI_m=1_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_pi_60_df_2 = CSV.read("Results/nonstat_60_observations_PI_m=2_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_pi_60_df_3 = CSV.read("Results/nonstat_60_observations_PI_m=3_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_pi_60_df_4 = CSV.read("Results/nonstat_60_observations_PI_m=4_i=100_n=25_r=0.5.csv",DataFrame)

# o_60_pi_df = vcat(o_nonstat_pi_60_df, o_nonstat_pi_60_df_1, o_nonstat_pi_60_df_2, o_nonstat_pi_60_df_3, o_nonstat_pi_60_df_4)
# o_60_pi_matrix = zeros(5,100,25,24)

# for row in eachrow(o_60_pi_df)
#     for t in 0:23
#         K = string(t)
#         if row.M == 60.0
#             o_60_pi_matrix[5,Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         else
#             o_60_pi_matrix[Int64(row.M),Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         end
#     end
# end

# ### 80 PERCENT CHANGE ###
# o_nonstat_pi_80_df = CSV.read("Results/nonstat_observations_PI_m=80_i=100_n=25_r=0.5.csv",DataFrame) 
# o_nonstat_pi_80_df_1 = CSV.read("Results/nonstat_80_observations_PI_m=1_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_pi_80_df_2 = CSV.read("Results/nonstat_80_observations_PI_m=2_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_pi_80_df_3 = CSV.read("Results/nonstat_80_observations_PI_m=3_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_pi_80_df_4 = CSV.read("Results/nonstat_80_observations_PI_m=4_i=100_n=25_r=0.5.csv",DataFrame)

# o_80_pi_df = vcat(o_nonstat_pi_80_df, o_nonstat_pi_80_df_1, o_nonstat_pi_80_df_2, o_nonstat_pi_80_df_3, o_nonstat_pi_80_df_4)
# o_80_pi_matrix = zeros(5,100,25,24)

# for row in eachrow(o_80_pi_df)
#     for t in 0:23
#         K = string(t)
#         if row.M == 80.0
#             o_80_pi_matrix[5,Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         else
#             o_80_pi_matrix[Int64(row.M),Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         end
#     end
# end

# ### 100 PERCENT CHANGE ###
# o_nonstat_pi_100_df = CSV.read("Results/nonstat_observations_PI_m=1_i=100_n=25_r=0.5.csv",DataFrame) 
# o_nonstat_pi_100_df_1 = CSV.read("Results/nonstat_100_observations_PI_m=1_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_pi_100_df_2 = CSV.read("Results/nonstat_100_observations_PI_m=2_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_pi_100_df_3 = CSV.read("Results/nonstat_100_observations_PI_m=3_i=100_n=25_r=0.5.csv",DataFrame)
# o_nonstat_pi_100_df_4 = CSV.read("Results/nonstat_100_observations_PI_m=4_i=100_n=25_r=0.5.csv",DataFrame)

# o_100_pi_df = vcat(o_nonstat_pi_100_df_1, o_nonstat_pi_100_df_2, o_nonstat_pi_100_df_3, o_nonstat_pi_100_df_4)
# o_100_pi_matrix = zeros(5,100,25,24)

# for row in eachrow(o_100_pi_df)
#     for t in 0:23
#         K = string(t)
#         if row.M == 100.0
#             o_100_pi_matrix[5,Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         else
#             o_100_pi_matrix[Int64(row.M),Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#         end
#     end
# end

# for row in eachrow(o_nonstat_pi_100_df)
#     for t in 0:23
#         K = string(t)
#         o_100_pi_matrix[5,Int64(row.I),Int64(row.N),t+1] = row[string(t)]
#     end
# end

# ### REGRET CALCULATION ###
# nonstat_20_regret = mean(sum(sqrt.(sum(o_20_matrix - o_20_pi_matrix, dims = 3)[:,:,1,:].^2),dims=3)[:,:,1],dims = 1)[1,:,:]/25
# nonstat_40_regret = mean(sum(sqrt.(sum(o_40_matrix - o_40_pi_matrix, dims = 3)[:,:,1,:].^2),dims=3)[:,:,1],dims = 1)[1,:,:]/25
# nonstat_60_regret = mean(sum(sqrt.(sum(o_60_matrix - o_60_pi_matrix, dims = 3)[:,:,1,:].^2),dims=3)[:,:,1],dims = 1)[1,:,:]/25
# nonstat_80_regret = mean(sum(sqrt.(sum(o_80_matrix - o_80_pi_matrix, dims = 3)[:,:,1,:].^2),dims=3)[:,:,1],dims = 1)[1,:,:]/25
# nonstat_100_regret = mean(sum(sqrt.(sum(o_100_matrix - o_100_pi_matrix, dims = 3)[:,:,1,:].^2),dims=3)[:,:,1],dims = 1)[1,:,:]/25

# nonstatregretplot = plot([nonstat_20_regret,nonstat_40_regret,nonstat_60_regret,nonstat_80_regret,nonstat_100_regret])
# plot!(regret, color =:black)
# savefig(nonstatregretplot,"Figures/Nonstat Regret Reset.tex")


# nonstat_cumulative_regret = zeros(5,100)
# for i in 1:100
#     for (case_index, case) in enumerate([nonstat_20_regret,nonstat_40_regret,nonstat_60_regret,nonstat_80_regret,nonstat_100_regret])
#         if i == 1
#             nonstat_cumulative_regret[case_index,i] = case[i]
#         else
#             nonstat_cumulative_regret[case_index,i] = nonstat_cumulative_regret[case_index,i-1] + case[i]
#         end
#     end
# end
# nonstat_cumulative_regret
# nonstat_cumulative_regret = hcat(zeros(5),nonstat_cumulative_regret)

# nonstat_cumulativeregretplot = plot(transpose(nonstat_cumulative_regret), xrange = (1,100), yrange = (0,400))
# savefig(nonstat_cumulativeregretplot, "Figures/Cumulative Nonstat Regret Reset.tex")


# #=
# ##########################################################
# ### COMMUNITY COST INCLUDING NOISE WITH AND WITHOUT PI ###
# ##########################################################
# p_im_tilde_noise = Array{Float64}(undef,20,365,24)
# p_ex_tilde_noise = Array{Float64}(undef,20,365,24)
# p_pen_tilde_noise = Array{Float64}(undef,20,365,24)
# cost_tilde_noise = Array{Float64}(undef,20,365)
# cumulative_cost_tilde_noise = zeros(20,366)
# for i in 1:20
#     for d in 1:365
#         DA_prices = DA_price_matrix[d,:]
#         if d <= 90 || d >= 273
#             import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 1.2878, 1.2878, 1.2878, 1.2878, 0.4293, 0.4293, 0.4293]
#         else
#             import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.5580, 0.5580, 0.5580, 0.5580, 0.2146, 0.2146, 0.2146]
#         end
#         p_im_tilde_noise[i,d,:] = max.(sum(o_matrix[i,d,:,:],dims=1),0)
#         p_ex_tilde_noise[i,d,:] = min.(sum(o_matrix[i,d,:,:],dims=1),0)
#         p_pen_tilde_noise[i,d,:] = max.(p_im_tilde_noise[i,d,:]-p_limit_matrix[i,d,:],0)
#         cost_tilde_noise[i,d] = sum(p_im_tilde_noise[i,d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_tilde_noise[i,d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_tilde_noise[i,d,t] for t in 1:24)
#         cumulative_cost_tilde_noise[i,d+1] = cumulative_cost_tilde_noise[i,d] + cost_tilde_noise[i,d]
#     end
# end

# y_star_noise = Array{Float64}(undef,20,365,25,24)
# p_im_star_noise = Array{Float64}(undef,20,365,24)
# p_ex_star_noise = Array{Float64}(undef,20,365,24)
# p_pen_star_noise = Array{Float64}(undef,20,365,24)
# cost_star_noise = Array{Float64}(undef,20,365)
# cumulative_cost_star_noise = zeros(20,366)
# for i in 1:20
#     for d in 1:365
#         DA_prices = DA_price_matrix[d,:]
#         if d <= 90 || d >= 273
#             import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 1.2878, 1.2878, 1.2878, 1.2878, 0.4293, 0.4293, 0.4293]
#         else
#             import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.5580, 0.5580, 0.5580, 0.5580, 0.2146, 0.2146, 0.2146]
#         end
#         p_im_star_noise[i,d,:] = max.(sum(o_pi_matrix[i,d,:,:],dims=1),0)
#         p_ex_star_noise[i,d,:] = min.(sum(o_pi_matrix[i,d,:,:],dims=1),0)
#         p_pen_star_noise[i,d,:] = max.(p_im_star_noise[i,d,:]-p_limit_matrix[i,d,:],0)
#         cost_star_noise[i,d] = sum(p_im_star_noise[i,d,t]*(DA_prices[t] + import_tariff[t]) - p_ex_star_noise[i,d,t]*(DA_prices[t] - export_tariff) +  penalty*p_pen_star_noise[i,d,t] for t in 1:24)
#         cumulative_cost_star_noise[i,d+1] = cumulative_cost_star_noise[i,d] + cost_star_noise[i,d]
#     end
# end

# #Plotting
# regretplot_noise = plot(0:365,transpose(mean(cumulative_cost_tilde_noise - cumulative_cost_star_noise,dims=1)),xrange = (0,365),c=1,xlabel = "Day", ylabel = "Cumulative Regret [DKK]",label ="Mean")
# plot!(0:365,transpose(maximum(cumulative_cost_tilde_noise - cumulative_cost_star_noise,dims=1)),linestyle =:dot,c =1, fillrange = transpose(minimum(cumulative_cost_tilde_noise - cumulative_cost_star_noise,dims=1)), fillalpha=0.3, label = false)
# plot!(0:365,transpose(minimum(cumulative_cost_tilde_noise - cumulative_cost_star_noise,dims=1)),xrange = (0,365), label = "Min/Max regret", c=1 , linestyle=:dot)
# plot!(0:365,transpose(maximum(cumulative_cost_tilde_noise - cumulative_cost_star_noise,dims=1)),xrange = (0,365), label = false, c= 1,linestyle=:dot)
# savefig(regretplot,"Community Cost Regret Noise.png")

# ###################################
# ### REPONSE DISTANCE - ABSOLUTE ###
# ###################################

# response_distance = sum(abs.(sum(y_tilde, dims =3)[:,:,1,:] - sum(y_star,dims=3)[:,:,1,:]),dims=3)[:,:,1]
# cumulative_response_distance = zeros(20,366)
# for d in 1:365
#     cumulative_response_distance[:,d+1] = cumulative_response_distance[:,d] + response_distance[:,d]
# end

# plot(transpose(mean(sum(abs.(sum(y_tilde, dims =3)[:,:,1,:] - sum(y_star,dims=3)[:,:,1,:]),dims=3)[:,:,1],dims=1)))

# responsedistanceplot = plot(0:365,transpose(mean(cumulative_response_distance,dims=1)), xrange=(0,365),yrange=(0,175),xlabel = "Day", ylabel = "Response Distance [kW]", label = false)
# savefig(responsedistanceplot,"Responce Distance Regret.png")

# plot!(transpose(maximum(cumulative_response_distance,dims=1)))
# plot!(transpose(minimum(cumulative_response_distance,dims=1)))

# ###############################################
# ### VIOLATION OVER TIME WITH NOISE ###
# ###############################################

# violation_regret = sum(max.(sum(o_matrix, dims = 3)[:,:,1,:] .- p_limit_matrix,0),dims=3)[:,:,1] - sum(max.(sum(o_pi_matrix, dims = 3)[:,:,1,:] .- p_limit_matrix,0),dims=3)[:,:,1]
# max_v_regret = maximum(violation_regret,dims=1)[1,:]
# min_v_regret = minimum(violation_regret,dims=1)[1,:]

# vregretplot = plot(transpose(mean(violation_regret,dims=1)), c = 1, xlabel = "Iteration",ylabel = "Regret [kW]", label = "Mean regret", legend =:topright, xrange = (1,100))
# plot!(min_v_regret, line = false, fillrange = max_v_regret, fillcolor = 1, fillalpha= 0.2, label = false)
# plot!(min_v_regret, linestyle = :dot, c = :red, label = "Minimum regret")
# plot!(max_v_regret, linestyle = :dot, c = :green, label = "Maximum regret")

# cumulative_v_regret = zeros(20,100)
# cumulative_v_max_regret = zeros(100)
# cumulative_v_min_regret = zeros(100)
# for i in 1:365
#     if i == 1
#         cumulative_v_regret[:,i] = violation_regret[:,i]
#         cumulative_v_min_regret[i] = min_v_regret[i]
#         cumulative_v_max_regret[i] = max_v_regret[i]
#     else
#         cumulative_v_regret[:,i] = cumulative_v_regret[:,i-1] + violation_regret[:,i]
#         cumulative_v_min_regret[i] = mean(cumulative_v_regret[:,i-1]) + min_v_regret[i]
#         cumulative_v_max_regret[i] = mean(cumulative_v_regret[:,i-1]) + max_v_regret[i]
#     end
# end

# cumulative_v_regret = hcat(zeros(20),cumulative_v_regret)
# cum_min_regret = minimum(cumulative_v_regret,dims=1)[1,:]
# cum_max_regret = maximum(cumulative_v_regret,dims=1)[1,:]
# cumulative_v_min_regret = vcat(0,cumulative_v_min_regret)
# cumulative_v_max_regret = vcat(0,cumulative_v_max_regret)

# vcumulativeregretplot = plot(mean(transpose(cumulative_v_regret),dims=2), xrange = (1,365), yrange = (0,600), label = "Mean regret")
# plot!(cum_min_regret, line = false, fillrange = cum_max_regret, fillcolor = 1, fillalpha= 0.2, label = false)
# plot!(cum_min_regret, linestyle = :dot, c = 1, label = "Minimum/Maximum regret")
# plot!(cum_max_regret, linestyle = :dot, c = 1, label = false)

# savefig(cumulativeregretplot, "Figures/Cumulative Regret.tex")


# ############################
# ### COMBINED REGRET PLOT ###
# ############################
# violationregretplot = plot(0:365,mean(transpose(cumulative_v_regret),dims=2), c = 2, xrange = (0,100), yrange = (0,600), label = "Mean", xlabel = "Day", ylabel = "Cumulative Violation [kW]")
# plot!(0:365,cum_min_regret, linestyle=:dot, fillrange = cum_max_regret, fillcolor = 2, fillalpha= 0.2, label = false, xrange = (0,100), yrange = (0,600))
# plot!(0:365,cum_min_regret, linestyle = :dot, c = 2, label = "Min/Max", xrange = (0,100), yrange = (0,600))
# plot!(0:365,cum_max_regret, linestyle = :dot, c = 2, label = false, xrange = (0,100), yrange = (0,600))
# savefig(violationregretplot,"Violation Regret Plot.png")

# ############################################
# ### RESPONSE DISTANCE - INCORRECT REGRET ###
# ############################################

# #=
# regret = mean(sum(sqrt.(sum(o_matrix - o_pi_matrix, dims = 3)[:,:,1,:].^2),dims=3)[:,:,1],dims = 1)[1,:,:]/25
# min_regret = minimum(sum(sqrt.(sum(o_matrix - o_pi_matrix, dims = 3)[:,:,1,:].^2),dims=3)[:,:,1],dims=1)[1,:,:]/25
# max_regret = maximum(sum(sqrt.(sum(o_matrix - o_pi_matrix, dims = 3)[:,:,1,:].^2),dims=3)[:,:,1],dims=1)[1,:,:]/25

# regretplot = plot(regret, c = 1, xlabel = "Iteration",ylabel = "Regret [kW]", label = "Mean regret", legend =:topright, xrange = (1,100))
# plot!(min_regret, line = false, fillrange = max_regret, fillcolor = 1, fillalpha= 0.2, label = "Range of observed regret")
# plot!(min_regret, linestyle = :dot, c = :red, label = "Maximum regret")
# plot!(max_regret, linestyle = :dot, c = :green, label = "Minimum regret")
# savefig(regretplot,"Figures/Regret.tex")


# cumulative_regret = zeros(50,100)
# cumulative_min_regret = zeros(100)
# cumulative_max_regret = zeros(100)
# for i in 1:100
#     if i == 1
#         cumulative_regret[:,i] = sum(sqrt.(sum(o_matrix - o_pi_matrix, dims = 3)[:,:,1,:].^2),dims=3)[:,i,1]/25
#         cumulative_min_regret[i] = min_regret[i]
#         cumulative_max_regret[i] = max_regret[i]
#     else
#         cumulative_regret[:,i] = cumulative_regret[:,i-1] + sum(sqrt.(sum(o_matrix - o_pi_matrix, dims = 3)[:,:,1,:].^2),dims=3)[:,i,1]/25
#         cumulative_min_regret[i] = cumulative_min_regret[i-1] + min_regret[i]
#         cumulative_max_regret[i] = cumulative_max_regret[i-1] + max_regret[i]
#     end
# end
# cumulative_regret = hcat(zeros(20),cumulative_regret)
# cumulative_min_regret = vcat(0,cumulative_min_regret)
# cumulative_max_regret = vcat(0,cumulative_max_regret)

# cumulativeregretplot = plot(mean(transpose(cumulative_regret),dims=2), xrange = (1,100), yrange = (0,500), label = "Mean regret")
# plot!(cumulative_min_regret, line = false, fillrange = cumulative_max_regret, fillcolor = 1, fillalpha= 0.2, label = false)
# plot!(cumulative_min_regret, linestyle = :dot, c = :red, label = "Maximum regret")
# plot!(cumulative_max_regret, linestyle = :dot, c = :green, label = "Minimum regret")
# savefig(cumulativeregretplot, "Figures/Cumulative Regret.tex")
# =#
# =#

using StatsPlots
gr(leg = false, bg = :lightgrey)

# Create a filled contour and boxplot side by side.
plot(contourf(randn(10, 20)), boxplot(rand(1:4, 1000), randn(1000)))

# Add a histogram inset on the heatmap.
# We set the (optional) position relative to bottom-right of the 1st subplot.
# The call is `bbox(x, y, width, height, origin...)`, where numbers are treated as
# "percent of parent".
histogram!(
    randn(1000),
    inset = (1, bbox(0.05, 0.05, 0.5, 0.25, :bottom, :right)),
    ticks = nothing,
    subplot = 3,
    bg_inside = nothing
)