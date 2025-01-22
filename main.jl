using Pkg
Pkg.activate("ThompsonSampling")
Pkg.instantiate()

using JuMP, Gurobi, Random, LinearAlgebra, Statistics, Distributions, LaTeXStrings, DataFrames, Plots, CSV, Dates, Query, ProgressBars, DelimitedFiles

const env = Gurobi.Env()
include("TS.jl")

#Setting Hyperparameters
I_n = 200
M = 1
T = 24
N = 10
K = 10
K_tcl = 2
K_ev = 3

###################################
### --- DEFINING SIGNATURES --- ###
###################################

# 1 = Morning base load flexibility
# 2 = Midday base load flexibility
# 3 = Evening base load flexibility
# 4 = PV
# 5 = Battery
# 6 = Heat pump small range
# 7 = Heat pump big range
# 8 = Electric Vehicle work day
# 9 = Electric Vehicle work day + hobby
# 10 = Electric Vehicle rush hour away

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

### !!! PLEASE NOTE !!! ###
# 1. the first 3 columns (Weights of load signatures) must sum to 1
# 2. the 4th column (PV capacity) can take any value above 0 and below 5
# 3. the 5th column is a battery should be 0 or 1
# 4. TCL loads are column 6 and 7. Between the 6th and 7th column, one should be 1 and the other should be 0
# 5. Between the 8th, 9th, and 10th column, one should be 1 and the others should be 0

#Setting the parameters for the gaussian white noise that will be added to the observations
variance = 0.5
noise = Normal(0,variance)

#####################################
### --- INPUT DATA PROCESSING --- ###
#####################################

### --- Spot Prices --- ###
# Reading spot prices from energidataservice.dk
prices_df = CSV.read("Data/Elspotprices.csv",DataFrame,delim=";",decimal=',')
# Convert the datetime column to DateTime format
prices_df.datetime = DateTime.(prices_df.HourDK, "yyyy-mm-dd HH:MM")
# Create an empty 365x24 matrix to store the prices
price_matrix = Array{Union{Missing,Float64}}(missing,365, 24)
# Loop over each row in the DataFrame and fill the matrix
for row in eachrow(prices_df)
    date = Date(row.datetime)  # Extract the date (YYYY-MM-DD)
    hour = Hour(row.datetime).value  # Extract the hour (0-23)
    # Calculate the day of the year (1-365)
    day_of_year = Dates.dayofyear(date)
    #adding elafgift to all hours and consumption
    elafgift = 0.9513
    # Fill the matrix at the appropriate (day, hour) position
    price_matrix[day_of_year, hour + 1] = max(row.SpotPriceDKK/1000,0) + elafgift# +1 since Julia is 1-based indexing
end
# Filling missing hour due to time change and setting it equal to previous hour
price_matrix[85,3] = price_matrix[85,2]
export_tariff = 0.0054

### --- PV Production --- ###
#Reading pv production data file from renewables.ninja
PV_df = CSV.read("Data/pv_production.csv",DataFrame,header=4)
#creating empty pv matrix
PV_matrix = Array{Union{Missing,Float64}}(missing,365, 24)
for row in eachrow(PV_df)
    date = Date.(row.time, "yyyy-mm-dd HH:MM")  # Extract the date (YYYY-MM-DD)
    hour = Hour(DateTime.(row.time, "yyyy-mm-dd HH:MM")).value  # Extract the hour (0-23)

    # Calculate the day of the year (1-365)
    day_of_year = Dates.dayofyear(date)

    # Fill the matrix at the appropriate (day, hour) position
    PV_matrix[day_of_year, hour + 1] = row.electricity# +1 since Julia is 1-based indexing
end

### --- Residential load --- ###
#Load profiles from CREST
load_df = CSV.read("Data/CREST profiles.csv", DataFrame,header=4,delim=';',skipto=7)
#x = load_df |> @filter(_.var"Dwelling index" == 1) |> DataFrame
D = zeros(N,T)
for j in 1:N
        J = @from i in load_df begin
                @where i.var"Dwelling index" == j
                @select {time = i.Time, demand = i.var"Net dwelling electricity demand"}
                @collect DataFrame
        end
        J.time = Time.(J.time, "HH.MM.SS p")
        hourly_demand = zeros(1,24)
        for i in 1:T
                Demand = J |> @filter(Hour.(_.time) == Hour(i-1)) |> DataFrame
                hourly_demand[i] = sum(Demand[!,"demand"]./(1000*60))
        end
        D[j,:] = hourly_demand
end

### --- Outdoor Temperature --- ###
temperature_df = CSV.read("Data/temperature.csv",DataFrame)
#creating empty temperature array
temp_matrix = Array{Union{Missing,Float64}}(missing,365,24)
# Loop over each row in the DataFrame and fill the matrix
for row in eachrow(temperature_df)
    date = Date(row.datetime)  # Extract the date (YYYY-MM-DD)
    hour = Hour(row.datetime).value  # Extract the hour (0-23)
    # Calculate the day of the year (1-365)
    day_of_year = Dates.dayofyear(date)
    # Fill the matrix at the appropriate (day, hour) position
    temp_matrix[day_of_year, hour + 1] = row.temperature
end

### --- EV presence signatures --- ###
patterns = [[1 1 1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 0 0 1 1 1 1 1];
            [1 1 1 1 1 1 0 0 0 0 0 0 0 0 0 1 1 1 1 0 0 0 1 1];
            [1 1 1 1 1 1 1 0 0 0 1 1 1 1 1 1 0 0 0 0 1 1 1 1]]

P_dr = 1    #hourly consumption while not connected

#Calculating average EV consumption if charging constantly while connected
EV = mean(((P_dr.*count(==(0), patterns, dims = 2))./count(==(1), patterns, dims = 2)).*patterns,dims=1) #total consumption spread over the hours in which the car is connected

################################
### RESULTS DICTS AND ARRAYS ###
################################

#Defining arrays and dicts
theta = Dict()

R = variance
#Making CSV files for saving results
observation_file = "Results/p25_observations_m=$(M)_i=$(I_n)_n=$(N)_r=$R.csv"
open(observation_file,"w") do io
    writedlm(io, ["M" "I" "N" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23], ",")
end

observation_pi_file = "Results/p25_observations_PI_m=$(M)_i=$(I_n)_n=$(N)_r=$R.csv"
open(observation_pi_file,"w") do io
    writedlm(io, ["M" "I" "N" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23], ",")
end

price_file = "Results/p25_prices_m=$(M)_i=$(I_n)_n=$(N)_r=$R.csv"
open(price_file,"w") do io
    writedlm(io, ["M" "I" "N" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23], ",")
end

price_pi_file = "Results/p25_prices_pi_m=$(M)_i=$(I_n)_n=$(N)_r=$R.csv"
open(price_pi_file,"w") do io
    writedlm(io, ["M" "I" "N" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23], ",")
end

signature_file = "Results/p25_signature_m=$(M)_i=$(I_n)_n=$(N)=.csv"
open(signature_file,"w") do io
    writedlm(io, ["M" "I" "N" "K" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23], ",")
end

signature_pi_file = "Results/p25_signature_pi_m=$(M)_i=$(I_n)_n=$(N)=.csv"
open(signature_pi_file,"w") do io
    writedlm(io, ["M" "I" "N" "K" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23], ",")
end

prediction_file = "Results/p25_prediction_m=$(M)_i=$(I_n)_n=$(N)=.csv"
open(prediction_file,"w") do io
    writedlm(io, ["M" "I" "N" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23], ",")
end

prediction_pi_file = "Results/p25_prediction_pi_m=$(M)_i=$(I_n)_n=$(N)=.csv"
open(prediction_pi_file,"w") do io
    writedlm(io, ["M" "I" "N" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23], ",")
end

limit_file = "Results/p25_P_limit_m=$(M)_i=$(I_n).csv"
open(limit_file,"w") do io
    writedlm(io, ["M" "I" 0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23], ",")
end

theta_file = "Results/p25_thetas_m=$(M)_i=$(I_n)_n=$(N).csv"
open(theta_file,"w") do io
    writedlm(io, ["M" "I" "N" "K" "mean" "variance"], ",")
end

##################
### SIMULATION ###
##################

for m in 1:M
    theta[m] = Dict()
    for n in 1:N
        theta[m][n] = Dict()
        theta[m][n]["mean"] = repeat([0.5],K)
        theta[m][n]["var"] = diagm(fill(0.15,K))
    end

    #Setting an initial temperature for the start of the run
    temp_initial = fill(20.0,K_tcl)

    for i in ProgressBar(1:I_n)
        #saving thetas
	    open(theta_file,"a") do io
            for n in 1:N
                for k in 1:K
                    writedlm(io, [m i n k theta[m][n]["mean"][k] theta[m][n]["var"][k,k]], ",")
                end
            end
        end
        #Defining prices for the day
        PV = transpose(PV_matrix[i,:])
        temperature = transpose(temp_matrix[i,:])
        DA_prices = price_matrix[i,:]
        if i <= 90 || i >= 273
            import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 0.4293, 1.2878, 1.2878, 1.2878, 1.2878, 0.4293, 0.4293, 0.4293]
        else
            import_tariff = [0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.1431, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.2146, 0.5580, 0.5580, 0.5580, 0.5580, 0.2146, 0.2146, 0.2146]
        end

        # BASELINE TCL PROFILE - consumption assuming a constant 21 degrees on the given day
        temp_opt = 21
        C = 13.5
        R_sim = 7
        ηᵀ = 4
        tcl_baseline_consumption = (temp_opt .- temperature)./(R_sim*ηᵀ)
        TCL = tcl_baseline_consumption

        # CAPACITY LIMIT - based on what assets are considered in our case study
        if K <= 3
            P_limit = fill(mean(sum(D[1:N,:],dims=1)),T)
        elseif K == 4 || K == 5
            P_limit = fill(mean(sum(D[1:N,:],dims=1) .- N*PV),T)
        elseif K == 6 || K == 7
            P_limit = fill(mean(sum(D[1:N,:],dims=1) .- N*PV .+ N*TCL),T)
        elseif K == 8 || K == 9 || K == 10
            P_limit = fill(mean(sum(D[1:N,:],dims=1) .- N*PV .+ N*TCL .+ N*EV),T)
        end

        open(limit_file,"a") do io
            writedlm(io, [m i transpose(P_limit)],",")
        end

        # Calculating Baseline Cost based daily temperature and price
        violation_penalty = 50
        if K <= 3
            Cᵉˣᵗ = D[1:N,:]*(DA_prices + import_tariff) + D[1:N,:]./sum(D[1:N,:],dims=1) * transpose(violation_penalty*max.(sum(D[1:N,:],dims=1)-reshape(P_limit,(1,24)),0))
        elseif K == 4 || K == 5
            Cᵉˣᵗ = (D[1:N,:] .- PV)*(DA_prices + import_tariff) + (D[1:N,:] .- PV)./sum((D[1:N,:] .- PV),dims=1) * transpose(violation_penalty*max.(sum((D[1:N,:] .- PV),dims=1)-reshape(P_limit,(1,24)),0))
        elseif K == 6 || K == 7
            Cᵉˣᵗ = (D[1:N,:] .- PV .+ TCL)*(DA_prices + import_tariff) + (D[1:N,:] .- PV .+ TCL)./sum((D[1:N,:] .- PV .+ TCL),dims=1) * transpose(violation_penalty*max.(sum((D[1:N,:] .- PV.+ TCL),dims=1)-reshape(P_limit,(1,24)),0))
        elseif K == 8 || K == 9 || K == 10
            Cᵉˣᵗ = (D[1:N,:] .- PV .+ TCL .+ EV)*(DA_prices + import_tariff) + (D[1:N,:] .- PV .+ TCL .+ EV)./sum((D[1:N,:] .- PV .+ TCL .+ EV),dims=1) * transpose(violation_penalty*max.(sum((D[1:N,:] .- PV .+ TCL .+ EV),dims=1)-reshape(P_limit,(1,24)),0))
        end

        # Sampling
        theta_sample = Array{Float64}(undef,N,K)
        for n in 1:N
            theta_sample[n,:] = sample(theta[m][n]["mean"],theta[m][n]["var"])
        end

        #for n in 1:N
        #    theta_sample[n,:] = rand(MvNormal(theta[m][n]["mean"],theta[m][n]["var"]))
        #end
    
        ################
        ### LEARNING ###
        ################

        ### PRICING WITH SAMPLE ###

        linear_results, signatures, temp_output = linear_pricing(theta_sample,T,N,K,K_tcl,K_ev,D,PV,DA_prices,import_tariff,export_tariff,P_limit,Cᵉˣᵗ,temperature, temp_initial, patterns)               #Prices determined by the linear model

        open(price_file,"a") do io
            for n in 1:N
                writedlm(io, [m i n transpose(value.(linear_results[:x][n,:]))], ",")
            end
        end

	    open(prediction_file,"a") do io
            for n in 1:N
                writedlm(io, [m i n transpose(signatures[n,:,:]*theta_sample[n,:])], ",")
            end
        end

        open(signature_file,"a") do io
            for n in 1:N
                for k in 1:K
                    writedlm(io, [m i n k transpose(signatures[n,:,k])], ",")
                end
            end
        end

        #model_results[m,i] = linear_results

        ### OBSERVATION FROM LEARNING ###

        observation = zeros(T,N)
        open(observation_file,"a") do io
            for n = 1:N
                observation[:,n] = signatures[n,:,:]*true_theta[n,1:K] + rand(noise,T)     #Using the power calculated in the pricing stage, but with the true theta values          
                writedlm(io, [m i n transpose(observation[:,n])],",")       
            end
        end

        ### PRICING WITH PERFECT INFORMATION ###
        linear_results_pi, signatures_pi, temp_output_pi = linear_pricing(true_theta[:,1:K],T,N,K,K_tcl,K_ev,D,PV,DA_prices,import_tariff,export_tariff,P_limit,Cᵉˣᵗ,temperature, temp_initial, patterns) 

        open(price_pi_file,"a") do io
            for n in 1:N
                writedlm(io, [m i n transpose(value.(linear_results_pi[:x][n,:]))], ",")
            end
        end

        open(prediction_pi_file,"a") do io
            for n in 1:N
                writedlm(io, [m i n transpose(signatures_pi[n,:,:]*true_theta[n,:])], ",")
            end
        end

        open(signature_pi_file,"a") do io
            for n in 1:N
                for k in 1:K
                    writedlm(io, [m i n k transpose(signatures_pi[n,:,k])], ",")
                end
            end
        end

        ### OBSERVATION WITH PERFECT INFORMATION ###
        observation_pi = zeros(T,N)
        open(observation_pi_file,"a") do io
            for n = 1:N
                observation_pi[:,n] = signatures_pi[n,:,:]*true_theta[n,1:K] + rand(noise,T)     #Using the power calculated in the pricing stage, but with the true theta values    
                writedlm(io,[m i n transpose(observation_pi[:,n])],",")             
            end
        end

        #Update
        R_update = diagm(repeat([variance],T)) #defining covariance matrix for the noise observed in the sample - assuming independence of all hours 
        for n in 1:N
            theta[m][n]["mean"],theta[m][n]["var"] = new_update(theta[m][n]["mean"],theta[m][n]["var"],signatures[n,:,:],R_update,observation[:,n])
        end

        temp_initial = temp_output
    end
    println("--- End of Run $m---")
end


### Theta comparison ###

println("Final Thetas")
for n in 1:N
    println(theta[1][n]["mean"])
    println(true_theta[n,:])
end
