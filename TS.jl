using JuMP, Gurobi, Random, LinearAlgebra, Distributions, LaTeXStrings

function sample(theta_mean,theta_variance)
    theta_distribution = MvNormal(theta_mean,theta_variance)
    theta_sample = rand(theta_distribution,1)
    return round.(theta_sample, digits = 2)
end

function update(theta_mean,theta_variance,H,R,observation)
    theta_variance -= round.(theta_variance * transpose(H) * inv(H * theta_variance * transpose(H) + R) * H * theta_variance, digits = 10)
    theta_mean += round.(theta_variance * transpose(H) * inv(R) * (observation - H*theta_mean), digits = 10)
    return theta_mean, theta_variance
end

function new_update(theta_prior,sigma_prior,H,R,y) 
    theta_post = round.(theta_prior + sigma_prior * transpose(H) * inv(H * sigma_prior * transpose(H) + R) * (y - H * theta_prior), digits = 10)
    sigma_post = round.(sigma_prior - sigma_prior * transpose(H) * inv(H * sigma_prior * transpose(H) + R) * H * sigma_prior, digits = 10)
    return theta_post, sigma_post
end

function linear_pricing(theta_sample, T, N, K, K_tcl, K_ev, L, PV, DA_prices, γⁱᵐ, γᵉˣ, P̄ᴰˢᴼ,Cᵉˣᵗ,temperature,τ⁰,patterns)

    ### --- Creating Model and Giving Specs --- ###
    linear = Model(() -> Gurobi.Optimizer(env))
    set_optimizer_attribute(linear, "MIPGap", 1e-2)
    set_optimizer_attribute(linear, "OutputFlag", 0)
    set_time_limit_sec(linear, 1800.0)

    ################################
    ########## PARAMETERS ##########
    ################################

    ### --- Capacity Limitation Parameters --- ###
    α = 50      #penalty

    ### --- Individual Consumer Parameters --- ###
    #Flexible hour sets
    T_morning = 6:9
    T_day = 10:16
    T_evening = 17:22

    #Battery Parameters
    E̲ = 0    #Lower limit for state of energy
    E̅ = 5    #Upper limit for state of energy
    B̅ = E̅./2                                    #Upper limit for charging and discharging power
    B̲ = -B̅                                      #Lower limit for charging and discharging power
    η = 0.95                                    #Charging and discharging efficiency of the battery
    E⁰ = E̅./2 

    #TCL Parameters
    τ̲ =     [19, 16]
    τ̅ =     [21, 24]
    τᵉˣᵗ =  temperature
    P̅ᵀ =    9
    ηᵀ =    4
    C =     14
    R =     7

    τᵉⁿᵈ = zeros(K_tcl)
    for k in 1:K_tcl
        temp_noTCL = zeros(T)
        for t in 1:T
            if t == 1
                temp_noTCL[t] = τ⁰[k] - 1/(R*C)*(τ⁰[k] - τᵉˣᵗ[t])
            else
                temp_noTCL[t] = temp_noTCL[t-1] - 1/(R*C)*(temp_noTCL[t-1] - τᵉˣᵗ[t])
            end
        end
        τᵉⁿᵈ[k] = max(temp_noTCL[T],(τ̲[k]+τ̅[k])/2)
    end
    
    #EV Parameters
    Pᵈ = 1
    S̲ =     0
    S̅ =     40
    E̅V̅ =    S̅./3
    E̲V̲ =    -E̅V̅
    Uᴱⱽ =   patterns
    S⁰ =    0.5*S̅


    ### --- Reformulation Parameters --- ###
    Mˡ = 1000               #Big M value for load complementarities
    M_charging_min = 1000   #Big-M value for minimum battery charging 
    M_charging_max = 1000   #Big-M value for maximum battery charging 
    M_discharging = 1000    #Big-M value for battery discharging
    M_soc = 1000            #Big-M value for state of energy
    Mᵀ = 1000               #Big-M value for TCL
    Mᴱⱽ = 1000              #Big-M value for EV

    ###############################
    ########## VARIABLES ##########
    ###############################

    ### --- Upper Level Variables --- ###
    @variable(linear, 0 <= x[1:N,1:T] <= maximum(DA_prices+γⁱᵐ))    #Individual Dynamic Price
    @variable(linear, y[1:N,1:T])                                   #Response
    @variable(linear, pⁱᵐ[1:T] >= 0)                                #Imported Community Power
    @variable(linear, pᵉˣ[1:T] >= 0)                                #Exported Community Power
    @variable(linear, pᵖᵉⁿ[1:T] >= 0)                               #Penalized Power

    ### --- Lower Level Variables --- ###
    #Only variable that exists for all signatures
    @variable(linear, p[1:N,1:T,1:K])                               #power from grid for consumer n at time t

    if K >= 1
    ### Signature 1 ###
    @variable(linear, l⁻¹[1:N,1:T])                                 #load for consumer n
    @variable(linear, μ̲ˡ⁻¹[1:N,1:T] >= 0)                           #dual variable for minimum load inequality
    @variable(linear, μ̅ˡ⁻¹[1:N,1:T] >= 0)                           #dual variable for maximum load inequality
    @variable(linear, λ¹⁻¹[1:N,1:T])                                #Dual for power balance in signature 1
    @variable(linear, λ²⁻¹[1:N,setdiff(1:T,T_morning)])             #Dual for load matching in signature 1
    @variable(linear, λ³⁻¹[1:N])                                    #Dual for load flexibility in signature 1

    @variable(linear, u̲ˡ⁻¹[1:N,1:T], Bin)                           #Binary for minimum load complementarity
    @variable(linear, u̅ˡ⁻¹[1:N,1:T], Bin)                           #Binary variable for maximum load complementarity
    end
    
    if K >= 2
    ### Signature 2 ###
    @variable(linear, l⁻²[1:N,1:T])                                 #load for consumer n
    @variable(linear, μ̲ˡ⁻²[1:N,1:T] >= 0)                           #dual variable for minimum load inequality
    @variable(linear, μ̅ˡ⁻²[1:N,1:T] >= 0)                           #dual variable for maximum load inequality
    @variable(linear, λ¹⁻²[1:N,1:T])                                #Dual for power balance in signature 2
    @variable(linear, λ²⁻²[1:N,setdiff(1:T,T_day)])                 #Dual for load matching in signature 2
    @variable(linear, λ³⁻²[1:N])                                    #Dual for load flexibility in signature 2

    @variable(linear, u̲ˡ⁻²[1:N,1:T], Bin)                           #Binary for minimum load complementarity
    @variable(linear, u̅ˡ⁻²[1:N,1:T], Bin)                           #Binary variable for maximum load complementarity
    end

    if K>= 3
    ### Signature 3 ###
    @variable(linear, l⁻³[1:N,1:T])                                 #load for consumer n
    @variable(linear, μ̲ˡ⁻³[1:N,1:T] >= 0)                           #dual variable for minimum load inequality
    @variable(linear, μ̅ˡ⁻³[1:N,1:T] >= 0)                           #dual variable for maximum load inequality
    @variable(linear, λ¹⁻³[1:N,1:T])                                #Dual for power balance in signature 3
    @variable(linear, λ²⁻³[1:N,setdiff(1:T,T_evening)])             #Dual for load matching in signature 3
    @variable(linear, λ³⁻³[1:N])                                    #Dual for load flexibility in signature 3

    @variable(linear, u̲ˡ⁻³[1:N,1:T], Bin)                           #Binary for minimum load complementarity
    @variable(linear, u̅ˡ⁻³[1:N,1:T], Bin)                           #Binary variable for maximum load complementarity
    end

    if K >= 4
        @variable(linear, λ¹³[1:N,1:T])
    end

    if K >= 5
        ### Signature 5 - Battery ###
        @variable(linear, b[1:N,1:T])                                  #battery charging/discharging power [kW]
        @variable(linear, e[1:N,1:T])                                  #state of energy of the battery [kWh]
        @variable(linear, λ⁴[1:N,1:T])                                 #dual of the power balance equation
        @variable(linear, λ⁵[1:N,1:T])                                 #dual of the battery balance constraint
        @variable(linear, λ⁶[1:N])                                     #dual of the initial and final battery balance
        @variable(linear, μ̲ᵇ[1:N,1:T] >= 0)                            #dual of the lower limit of charging/discharging power
        @variable(linear, μ̅ᵇ[1:N,1:T] >= 0)                            #dual of the upper limit of charging/discharging power
        @variable(linear, μ̲ᵉ[1:N,1:T] >= 0)                            #dual of the lower limit of state of energy
        @variable(linear, μ̅ᵉ[1:N,1:T] >= 0)                            #dual of the upper limit of state of energy
        #Binaries for complementarities
        @variable(linear, u̲ᵇ[1:N,1:T], Bin)                            #Binary variable for minimum battery charging/discharging
        @variable(linear, u̅ᵇ[1:N,1:T], Bin)                            #Binary variable for maximum battery charging/discharging
        @variable(linear, u̲ᵉ[1:N,1:T], Bin)                            #Binary variable for minimum state of energy 
        @variable(linear, u̅ᵉ[1:N,1:T], Bin)                            #Binary variable for maximum state of energy
    end
    
    if K>= 6
        ### Signature 6 - TCL small range###
        @variable(linear, pᵀ⁻ˢ[1:N,1:T] >= 0)
        @variable(linear, τ⁻ˢ[1:N,1:T])
        @variable(linear, λ⁷⁻ˢ[1:N,1:T])
        @variable(linear, λ⁸⁻ˢ[1:N,1:T])
        @variable(linear, λ⁹⁻ˢ[1:N])
        @variable(linear, μ̲ᵖᵀ⁻ˢ[1:N,1:T] >= 0)
        @variable(linear, μ̅ᵖᵀ⁻ˢ[1:N,1:T] >= 0)
        @variable(linear, μ̲ᵀ⁻ˢ[1:N,1:T] >= 0)
        @variable(linear, μ̅ᵀ⁻ˢ[1:N,1:T] >= 0)
        #Binaries for complementarities
        @variable(linear, u̲ᵖᵀ⁻ˢ[1:N,1:T], Bin)
        @variable(linear, u̅ᵖᵀ⁻ˢ[1:N,1:T], Bin)
        @variable(linear, u̲ᵀ⁻ˢ[1:N,1:T], Bin)
        @variable(linear, u̅ᵀ⁻ˢ[1:N,1:T], Bin)
    end

    if K>= 7
        ### Signature 7 - TCL big range ###
        @variable(linear, pᵀ⁻ᵇ[1:N,1:T] >= 0)
        @variable(linear, τ⁻ᵇ[1:N,1:T])
        @variable(linear, λ⁷⁻ᵇ[1:N,1:T])
        @variable(linear, λ⁸⁻ᵇ[1:N,1:T])
        @variable(linear, λ⁹⁻ᵇ[1:N])
        @variable(linear, μ̲ᵖᵀ⁻ᵇ[1:N,1:T] >= 0)
        @variable(linear, μ̅ᵖᵀ⁻ᵇ[1:N,1:T] >= 0)
        @variable(linear, μ̲ᵀ⁻ᵇ[1:N,1:T] >= 0)
        @variable(linear, μ̅ᵀ⁻ᵇ[1:N,1:T] >= 0)
        #Binaries for complementarities
        @variable(linear, u̲ᵖᵀ⁻ᵇ[1:N,1:T], Bin)
        @variable(linear, u̅ᵖᵀ⁻ᵇ[1:N,1:T], Bin)
        @variable(linear, u̲ᵀ⁻ᵇ[1:N,1:T], Bin)
        @variable(linear, u̅ᵀ⁻ᵇ[1:N,1:T], Bin)
    end
    
    if K >= 8
        ### Signature 8 - EV work day ###
        @variable(linear, ev⁻ʷ[1:N,1:T])
        #@variable(linear, ev⁺⁻ʷ[1:N,1:T])
        #@variable(linear, ev⁻⁻ʷ[1:N,1:T])
        @variable(linear, s⁻ʷ[1:N,1:T])
        @variable(linear, λ¹⁰⁻ʷ[1:N,1:T])
        @variable(linear, λ¹¹⁻ʷ[1:N,1:T])
        @variable(linear, λ¹²⁻ʷ[1:N])
        @variable(linear, μ̲ᵉᵛ⁻ʷ[1:N,1:T] >= 0)
        @variable(linear, μ̅ᵉᵛ⁻ʷ[1:N,1:T] >= 0)
        #@variable(linear, μ̲ᵉᵛ⁺⁻ʷ[1:N,1:T] >= 0)
        #@variable(linear, μ̅ᵉᵛ⁺⁻ʷ[1:N,1:T] >= 0)
        #@variable(linear, μ̲ᵉᵛ⁻⁻ʷ[1:N,1:T] >= 0)
        #@variable(linear, μ̅ᵉᵛ⁻⁻ʷ[1:N,1:T] >= 0)
        @variable(linear, μ̲ˢ⁻ʷ[1:N,1:T] >= 0)
        @variable(linear, μ̅ˢ⁻ʷ[1:N,1:T] >= 0)
        #Binaries for complementarities
        @variable(linear, u̲ᵉᵛ⁻ʷ[1:N,1:T], Bin)
        @variable(linear, u̅ᵉᵛ⁻ʷ[1:N,1:T], Bin)
        #@variable(linear, u̲ᵉᵛ⁺⁻ʷ[1:N,1:T], Bin)
        #@variable(linear, u̅ᵉᵛ⁺⁻ʷ[1:N,1:T], Bin)
        #@variable(linear, u̲ᵉᵛ⁻⁻ʷ[1:N,1:T], Bin)
        #@variable(linear, u̅ᵉᵛ⁻⁻ʷ[1:N,1:T], Bin)
        @variable(linear, u̲ˢ⁻ʷ[1:N,1:T], Bin)
        @variable(linear, u̅ˢ⁻ʷ[1:N,1:T], Bin)
    end

    if K >= 9
        ### Signature 9 - EV work day + hobby ###
        @variable(linear, ev⁻ʷʰ[1:N,1:T])
        #@variable(linear, ev⁺⁻ʷʰ[1:N,1:T])
        #@variable(linear, ev⁻⁻ʷʰ[1:N,1:T])
        @variable(linear, s⁻ʷʰ[1:N,1:T])
        @variable(linear, λ¹⁰⁻ʷʰ[1:N,1:T])
        @variable(linear, λ¹¹⁻ʷʰ[1:N,1:T])
        @variable(linear, λ¹²⁻ʷʰ[1:N])
        @variable(linear, μ̲ᵉᵛ⁻ʷʰ[1:N,1:T] >= 0)
        @variable(linear, μ̅ᵉᵛ⁻ʷʰ[1:N,1:T] >= 0)
        #@variable(linear, μ̲ᵉᵛ⁺⁻ʷʰ[1:N,1:T] >= 0)
        #@variable(linear, μ̅ᵉᵛ⁺⁻ʷʰ[1:N,1:T] >= 0)
        #@variable(linear, μ̲ᵉᵛ⁻⁻ʷʰ[1:N,1:T] >= 0)
        #@variable(linear, μ̅ᵉᵛ⁻⁻ʷʰ[1:N,1:T] >= 0)
        @variable(linear, μ̲ˢ⁻ʷʰ[1:N,1:T] >= 0)
        @variable(linear, μ̅ˢ⁻ʷʰ[1:N,1:T] >= 0)
        #Binaries for complementarities
        @variable(linear, u̲ᵉᵛ⁻ʷʰ[1:N,1:T], Bin)
        @variable(linear, u̅ᵉᵛ⁻ʷʰ[1:N,1:T], Bin)
        #@variable(linear, u̲ᵉᵛ⁺⁻ʷʰ[1:N,1:T], Bin)
        #@variable(linear, u̅ᵉᵛ⁺⁻ʷʰ[1:N,1:T], Bin)
        #@variable(linear, u̲ᵉᵛ⁻⁻ʷʰ[1:N,1:T], Bin)
        #@variable(linear, u̅ᵉᵛ⁻⁻ʷʰ[1:N,1:T], Bin)
        @variable(linear, u̲ˢ⁻ʷʰ[1:N,1:T], Bin)
        @variable(linear, u̅ˢ⁻ʷʰ[1:N,1:T], Bin)
    end

    if K >= 10
        ### Signature 10 - EV work day ###
        @variable(linear, ev⁻ʳ[1:N,1:T])
        #@variable(linear, ev⁺⁻ʳ[1:N,1:T])
        #@variable(linear, ev⁻⁻ʳ[1:N,1:T])
        @variable(linear, s⁻ʳ[1:N,1:T])
        @variable(linear, λ¹⁰⁻ʳ[1:N,1:T])
        @variable(linear, λ¹¹⁻ʳ[1:N,1:T])
        @variable(linear, λ¹²⁻ʳ[1:N])
        @variable(linear, μ̲ᵉᵛ⁻ʳ[1:N,1:T] >= 0)
        @variable(linear, μ̅ᵉᵛ⁻ʳ[1:N,1:T] >= 0)
        #@variable(linear, μ̲ᵉᵛ⁺⁻ʳ[1:N,1:T] >= 0)
        #@variable(linear, μ̅ᵉᵛ⁺⁻ʳ[1:N,1:T] >= 0)
        #@variable(linear, μ̲ᵉᵛ⁻⁻ʳ[1:N,1:T] >= 0)
        #@variable(linear, μ̅ᵉᵛ⁻⁻ʳ[1:N,1:T] >= 0)
        @variable(linear, μ̲ˢ⁻ʳ[1:N,1:T] >= 0)
        @variable(linear, μ̅ˢ⁻ʳ[1:N,1:T] >= 0)
        #Binaries for complementarities
        @variable(linear, u̲ᵉᵛ⁻ʳ[1:N,1:T], Bin)
        @variable(linear, u̅ᵉᵛ⁻ʳ[1:N,1:T], Bin)
        #@variable(linear, u̲ᵉᵛ⁺⁻ʳ[1:N,1:T], Bin)
        #@variable(linear, u̅ᵉᵛ⁺⁻ʳ[1:N,1:T], Bin)
        #@variable(linear, u̲ᵉᵛ⁻⁻ʳ[1:N,1:T], Bin)
        #@variable(linear, u̅ᵉᵛ⁻⁻ʳ[1:N,1:T], Bin)
        @variable(linear, u̲ˢ⁻ʳ[1:N,1:T], Bin)
        @variable(linear, u̅ˢ⁻ʳ[1:N,1:T], Bin)
    end

    #################################
    ########## CONSTRAINTS ##########
    #################################

    ### --- Upper Level Constraints --- ###
    @constraint(linear, response[n = 1:N], y[n,:] == p[n,:,:]*theta_sample[n,:])                       #Response prediction constraint using theta sample
    @constraint(linear, community_balance[t = 1:T], pⁱᵐ[t] - pᵉˣ[t] == sum(y[n,t] for n in 1:N))       #Power balance of the energy community
    @constraint(linear, penalty[t = 1:T], pᵖᵉⁿ[t] >= pⁱᵐ[t] - 0.95*P̄ᴰˢᴼ[t])                                      #Calculation of the power flowing within the community

    #Individual individual_rationality
    
    if K == 3
        @constraint(linear, individual_rationality[n=1:N], theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                            + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                            + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening)) 
                                                            <= Cᵉˣᵗ[n])
                                                      
        @constraint(linear, revenue_adequacy, sum(theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening)) for n in 1:N) 
                                                >= sum(pⁱᵐ[t]*(DA_prices[t] .+ γⁱᵐ[t]) - pᵉˣ[t]*(DA_prices[t] .- γᵉˣ)  for t in 1:T))
    elseif K == 4
        @constraint(linear, individual_rationality[n=1:N], theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                            + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                            + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening))
                                                            + theta_sample[n,4]*(-sum(λ¹³[n,t]*PV[t] for t in 1:T))
                                                            <= Cᵉˣᵗ[n])

        @constraint(linear, revenue_adequacy, sum(theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening))
                                                + theta_sample[n,4]*(sum(-λ¹³[n,t]*PV[t] for t in 1:T)) for n in 1:N)
                                                >= sum(pⁱᵐ[t]*(DA_prices[t] .+ γⁱᵐ[t]) - pᵉˣ[t]*(DA_prices[t] .- γᵉˣ) for t in 1:T))
    elseif K == 5
        @constraint(linear, individual_rationality[n=1:N], theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                            + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                            + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening))
                                                            + theta_sample[n,4]*(-sum(λ¹³[n,t]*PV[t] for t in 1:T))
                                                            + theta_sample[n,5]*(λ⁵[n,1]*E⁰ - λ⁶[n]*E⁰ + sum(μ̲ᵇ[n,t]*B̲ - μ̅ᵇ[n,t]*B̅ + μ̲ᵉ[n,t]*E̲ - μ̅ᵉ[n,t]*E̅ for t in 1:T))
                                                            <= Cᵉˣᵗ[n])

        @constraint(linear, revenue_adequacy, sum(theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening))
                                                + theta_sample[n,4]*(sum(-λ¹³[n,t]*PV[t] for t in 1:T))
                                                + theta_sample[n,5]*(λ⁵[n,1]*E⁰ - λ⁶[n]*E⁰ + sum(μ̲ᵇ[n,t]*B̲ - μ̅ᵇ[n,t]*B̅ + μ̲ᵉ[n,t]*E̲ - μ̅ᵉ[n,t]*E̅ for t in 1:T)) 
                                                for n in 1:N)
                                                >= sum(pⁱᵐ[t]*(DA_prices[t] .+ γⁱᵐ[t]) - pᵉˣ[t]*(DA_prices[t] .- γᵉˣ) for t in 1:T))
    elseif K == 6
        @constraint(linear, individual_rationality[n=1:N], theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                            + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                            + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening))
                                                            + theta_sample[n,4]*(sum(-λ¹³[n,t]*PV[t] for t in 1:T))
                                                            + theta_sample[n,5]*(λ⁵[n,1]*E⁰ - λ⁶[n]*E⁰ + sum(μ̲ᵇ[n,t]*B̲ - μ̅ᵇ[n,t]*B̅ + μ̲ᵉ[n,t]*E̲ - μ̅ᵉ[n,t]*E̅ for t in 1:T)) 
                                                            + theta_sample[n,6]*(-λ⁹⁻ˢ[n]*τᵉⁿᵈ[n] + λ⁸⁻ˢ[n,1]*τ⁰[n] - λ⁸⁻ˢ[n,1]*τ⁰[n]/(R*C) + sum(λ⁸⁻ˢ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ˢ[n,t]*τ̲[1] - μ̅ᵀ⁻ˢ[n,t]*τ̅[1] - μ̅ᵖᵀ⁻ˢ[n,t]*P̅ᵀ for t in 1:T)) 
                                                            <= Cᵉˣᵗ[n])

        @constraint(linear, revenue_adequacy, sum(theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening))
                                                + theta_sample[n,4]*(sum(-λ¹³[n,t]*PV[t] for t in 1:T))
                                                + theta_sample[n,5]*(λ⁵[n,1]*E⁰ - λ⁶[n]*E⁰ + sum(μ̲ᵇ[n,t]*B̲ - μ̅ᵇ[n,t]*B̅ + μ̲ᵉ[n,t]*E̲ - μ̅ᵉ[n,t]*E̅ for t in 1:T)) 
                                                + theta_sample[n,6]*(-λ⁹⁻ˢ[n]*τᵉⁿᵈ[n] + λ⁸⁻ˢ[n,1]*τ⁰[n] - λ⁸⁻ˢ[n,1]*τ⁰[n]/(R*C) + sum(λ⁸⁻ˢ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ˢ[n,t]*τ̲[1] - μ̅ᵀ⁻ˢ[n,t]*τ̅[1] - μ̅ᵖᵀ⁻ˢ[n,t]*P̅ᵀ for t in 1:T)) 
                                                for n in 1:N)
                                                >= sum(pⁱᵐ[t]*(DA_prices[t] .+ γⁱᵐ[t]) - pᵉˣ[t]*(DA_prices[t] .- γᵉˣ) for t in 1:T))
    elseif K == 7
        @constraint(linear, individual_rationality[n=1:N], theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                            + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                            + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening))
                                                            + theta_sample[n,4]*(sum(-λ¹³[n,t]*PV[t] for t in 1:T))
                                                            + theta_sample[n,5]*(λ⁵[n,1]*E⁰ - λ⁶[n]*E⁰ + sum(μ̲ᵇ[n,t]*B̲ - μ̅ᵇ[n,t]*B̅ + μ̲ᵉ[n,t]*E̲ - μ̅ᵉ[n,t]*E̅ for t in 1:T)) 
                                                            + theta_sample[n,6]*(-λ⁹⁻ˢ[n]*τᵉⁿᵈ[1] + λ⁸⁻ˢ[n,1]*τ⁰[1] - λ⁸⁻ˢ[n,1]*τ⁰[1]/(R*C) + sum(λ⁸⁻ˢ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ˢ[n,t]*τ̲[1] - μ̅ᵀ⁻ˢ[n,t]*τ̅[1] - μ̅ᵖᵀ⁻ˢ[n,t]*P̅ᵀ for t in 1:T)) 
                                                            + theta_sample[n,7]*(-λ⁹⁻ᵇ[n]*τᵉⁿᵈ[2] + λ⁸⁻ᵇ[n,1]*τ⁰[2] - λ⁸⁻ᵇ[n,1]*τ⁰[2]/(R*C) + sum(λ⁸⁻ᵇ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ᵇ[n,t]*τ̲[2] - μ̅ᵀ⁻ᵇ[n,t]*τ̅[2] - μ̅ᵖᵀ⁻ᵇ[n,t]*P̅ᵀ for t in 1:T))
                                                            <= Cᵉˣᵗ[n])

        @constraint(linear, revenue_adequacy, sum(theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening))
                                                + theta_sample[n,4]*(sum(-λ¹³[n,t]*PV[t] for t in 1:T))
                                                + theta_sample[n,5]*(λ⁵[n,1]*E⁰ - λ⁶[n]*E⁰ + sum(μ̲ᵇ[n,t]*B̲ - μ̅ᵇ[n,t]*B̅ + μ̲ᵉ[n,t]*E̲ - μ̅ᵉ[n,t]*E̅ for t in 1:T)) 
                                                + theta_sample[n,6]*(-λ⁹⁻ˢ[n]*τᵉⁿᵈ[1] + λ⁸⁻ˢ[n,1]*τ⁰[1] - λ⁸⁻ˢ[n,1]*τ⁰[1]/(R*C) + sum(λ⁸⁻ˢ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ˢ[n,t]*τ̲[1] - μ̅ᵀ⁻ˢ[n,t]*τ̅[1] - μ̅ᵖᵀ⁻ˢ[n,t]*P̅ᵀ for t in 1:T)) 
                                                + theta_sample[n,7]*(-λ⁹⁻ᵇ[n]*τᵉⁿᵈ[2] + λ⁸⁻ᵇ[n,1]*τ⁰[2] - λ⁸⁻ᵇ[n,1]*τ⁰[2]/(R*C) + sum(λ⁸⁻ᵇ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ᵇ[n,t]*τ̲[2] - μ̅ᵀ⁻ᵇ[n,t]*τ̅[2] - μ̅ᵖᵀ⁻ᵇ[n,t]*P̅ᵀ for t in 1:T))
                                                for n in 1:N)
                                                >= sum(pⁱᵐ[t]*(DA_prices[t] .+ γⁱᵐ[t]) - pᵉˣ[t]*(DA_prices[t] .- γᵉˣ) for t in 1:T))
    elseif K == 8
        @constraint(linear, individual_rationality[n=1:N], theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                            + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                            + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening))
                                                            + theta_sample[n,4]*(sum(-λ¹³[n,t]*PV[t] for t in 1:T))
                                                            + theta_sample[n,5]*(λ⁵[n,1]*E⁰ - λ⁶[n]*E⁰ + sum(μ̲ᵇ[n,t]*B̲ - μ̅ᵇ[n,t]*B̅ + μ̲ᵉ[n,t]*E̲ - μ̅ᵉ[n,t]*E̅ for t in 1:T))
                                                            #+ theta_sample[n,5]*(λ⁵[n,1]*E⁰ - λ⁶[n]*E⁰ + sum(μ̲ᵇ⁺[n,t]*B̲ - μ̅ᵇ⁺[n,t]*B̅ + μ̲ᵇ⁻[n,t]*B̲ - μ̅ᵇ⁻[n,t]*B̅ + μ̲ᵉ[n,t]*E̲ - μ̅ᵉ[n,t]*E̅ for t in 1:T)) 
                                                            + theta_sample[n,6]*(-λ⁹⁻ˢ[n]*τᵉⁿᵈ[1] + λ⁸⁻ˢ[n,1]*τ⁰[1] - λ⁸⁻ˢ[n,1]*τ⁰[1]/(R*C) + sum(λ⁸⁻ˢ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ˢ[n,t]*τ̲[1] - μ̅ᵀ⁻ˢ[n,t]*τ̅[1] - μ̅ᵖᵀ⁻ˢ[n,t]*P̅ᵀ for t in 1:T)) 
                                                            + theta_sample[n,7]*(-λ⁹⁻ᵇ[n]*τᵉⁿᵈ[2] + λ⁸⁻ᵇ[n,1]*τ⁰[2] - λ⁸⁻ᵇ[n,1]*τ⁰[2]/(R*C) + sum(λ⁸⁻ᵇ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ᵇ[n,t]*τ̲[2] - μ̅ᵀ⁻ᵇ[n,t]*τ̅[2] - μ̅ᵖᵀ⁻ᵇ[n,t]*P̅ᵀ for t in 1:T))
                                                            + theta_sample[n,8]*(-λ¹²⁻ʷ[n]*S⁰ - λ¹¹⁻ʷ[n,1]*S⁰ - sum(-λ¹¹⁻ʷ[n,t]*Pᵈ*(1-Uᴱⱽ[1,t]) + μ̲ᵉᵛ⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̲V̲ - μ̅ᵉᵛ⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̅V̅ + μ̲ˢ⁻ʷ[n,t]*S̲ - μ̅ˢ⁻ʷ[n,t]*S̅ for t in 1:T))
                                                            #=+ theta_sample[n,8]*(-λ¹²⁻ʷ[n]*S⁰ - sum(-λ¹¹⁻ʷ[n,t]*Pᵈ*(1-Uᴱⱽ[1,t]) + μ̲ᵉᵛ⁺⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̲V̲ - μ̅ᵉᵛ⁺⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̅V̅ + μ̲ᵉᵛ⁻⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̲V̲ - μ̅ᵉᵛ⁻⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̅V̅ + μ̲ˢ⁻ʷ[n,t]*S̲ - μ̅ᵉᵛ⁺⁻ʷ[n,t]*S̅ for t in 1:T))=# 
                                                            <= Cᵉˣᵗ[n])

        @constraint(linear, revenue_adequacy, sum(theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening))
                                                + theta_sample[n,4]*(sum(-λ¹³[n,t]*PV[t] for t in 1:T))
                                                + theta_sample[n,5]*(λ⁵[n,1]*E⁰ - λ⁶[n]*E⁰ + sum(μ̲ᵇ[n,t]*B̲ - μ̅ᵇ[n,t]*B̅ + μ̲ᵉ[n,t]*E̲ - μ̅ᵉ[n,t]*E̅ for t in 1:T)) 
                                                + theta_sample[n,6]*(-λ⁹⁻ˢ[n]*τᵉⁿᵈ[1] + λ⁸⁻ˢ[n,1]*τ⁰[1] - λ⁸⁻ˢ[n,1]*τ⁰[1]/(R*C) + sum(λ⁸⁻ˢ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ˢ[n,t]*τ̲[1] - μ̅ᵀ⁻ˢ[n,t]*τ̅[1] - μ̅ᵖᵀ⁻ˢ[n,t]*P̅ᵀ for t in 1:T)) 
                                                + theta_sample[n,7]*(-λ⁹⁻ᵇ[n]*τᵉⁿᵈ[2] + λ⁸⁻ᵇ[n,1]*τ⁰[2] - λ⁸⁻ᵇ[n,1]*τ⁰[2]/(R*C) + sum(λ⁸⁻ᵇ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ᵇ[n,t]*τ̲[2] - μ̅ᵀ⁻ᵇ[n,t]*τ̅[2] - μ̅ᵖᵀ⁻ᵇ[n,t]*P̅ᵀ for t in 1:T))
                                                + theta_sample[n,8]*(-λ¹²⁻ʷ[n]*S⁰ - λ¹¹⁻ʷ[n,1]*S⁰ - sum(-λ¹¹⁻ʷ[n,t]*Pᵈ*(1-Uᴱⱽ[1,t]) + μ̲ᵉᵛ⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̲V̲ - μ̅ᵉᵛ⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̅V̅ + μ̲ˢ⁻ʷ[n,t]*S̲ - μ̅ˢ⁻ʷ[n,t]*S̅ for t in 1:T))
                                                for n in 1:N)
                                                >= sum(pⁱᵐ[t]*(DA_prices[t] .+ γⁱᵐ[t]) - pᵉˣ[t]*(DA_prices[t] .- γᵉˣ) for t in 1:T))
    elseif K == 9
        @constraint(linear, individual_rationality[n=1:N], theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                            + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                            + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening))
                                                            + theta_sample[n,4]*(sum(-λ¹³[n,t]*PV[t] for t in 1:T))
                                                            + theta_sample[n,5]*(λ⁵[n,1]*E⁰ - λ⁶[n]*E⁰ + sum(μ̲ᵇ⁺[n,t]*B̲ - μ̅ᵇ⁺[n,t]*B̅ + μ̲ᵇ⁻[n,t]*B̲ - μ̅ᵇ⁻[n,t]*B̅ + μ̲ᵉ[n,t]*E̲ - μ̅ᵉ[n,t]*E̅ for t in 1:T)) 
                                                            + theta_sample[n,6]*(-λ⁹⁻ˢ[n]*τᵉⁿᵈ[1] + λ⁸⁻ˢ[n,1]*τ⁰[1] - λ⁸⁻ˢ[n,1]*τ⁰[1]/(R*C) + sum(λ⁸⁻ˢ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ˢ[n,t]*τ̲[1] - μ̅ᵀ⁻ˢ[n,t]*τ̅[1] - μ̅ᵖᵀ⁻ˢ[n,t]*P̅ᵀ for t in 1:T)) 
                                                            + theta_sample[n,7]*(-λ⁹⁻ᵇ[n]*τᵉⁿᵈ[2] + λ⁸⁻ᵇ[n,1]*τ⁰[2] - λ⁸⁻ᵇ[n,1]*τ⁰[2]/(R*C) + sum(λ⁸⁻ᵇ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ᵇ[n,t]*τ̲[2] - μ̅ᵀ⁻ᵇ[n,t]*τ̅[2] - μ̅ᵖᵀ⁻ᵇ[n,t]*P̅ᵀ for t in 1:T))
                                                            + theta_sample[n,8]*(-λ¹²⁻ʷ[n]*S⁰ - sum(-λ¹¹⁻ʷ[n,t]*Pᵈ*(1-Uᴱⱽ[1,t]) + μ̲ᵉᵛ⁺⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̲V̲ - μ̅ᵉᵛ⁺⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̅V̅ + μ̲ᵉᵛ⁻⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̲V̲ - μ̅ᵉᵛ⁻⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̅V̅ + μ̲ˢ⁻ʷ[n,t]*S̲ - μ̅ˢ⁻ʷ[n,t]*S̅ for t in 1:T)) 
                                                            + theta_sample[n,9]*(-λ¹²⁻ʷʰ[n]*S⁰ - sum(-λ¹¹⁻ʷʰ[n,t]*Pᵈ*(1-Uᴱⱽ[2,t]) + μ̲ᵉᵛ⁺⁻ʷʰ[n,t]*Uᴱⱽ[2,t]*E̲V̲ - μ̅ᵉᵛ⁺⁻ʷʰ[n,t]*Uᴱⱽ[2,t]*E̅V̅ + μ̲ᵉᵛ⁻⁻ʷʰ[n,t]*Uᴱⱽ[2,t]*E̲V̲ - μ̅ᵉᵛ⁻⁻ʷʰ[n,t]*Uᴱⱽ[2,t]*E̅V̅ + μ̲ˢ⁻ʷʰ[n,t]*S̲ - μ̅ˢ⁻ʷʰ[n,t]*S̅ for t in 1:T))
                                                            <= Cᵉˣᵗ[n])

        @constraint(linear, revenue_adequacy, sum(theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening))
                                                + theta_sample[n,4]*(sum(-λ¹³[n,t]*PV[t] for t in 1:T))
                                                + theta_sample[n,5]*(λ⁵[n,1]*E⁰ - λ⁶[n]*E⁰ + sum(μ̲ᵇ⁺[n,t]*B̲ - μ̅ᵇ⁺[n,t]*B̅ + μ̲ᵇ⁻[n,t]*B̲ - μ̅ᵇ⁻[n,t]*B̅ + μ̲ᵉ[n,t]*E̲ - μ̅ᵉ[n,t]*E̅ for t in 1:T)) 
                                                + theta_sample[n,6]*(-λ⁹⁻ˢ[n]*τᵉⁿᵈ[1] + λ⁸⁻ˢ[n,1]*τ⁰[1] - λ⁸⁻ˢ[n,1]*τ⁰[1]/(R*C) + sum(λ⁸⁻ˢ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ˢ[n,t]*τ̲[1] - μ̅ᵀ⁻ˢ[n,t]*τ̅[1] - μ̅ᵖᵀ⁻ˢ[n,t]*P̅ᵀ for t in 1:T)) 
                                                + theta_sample[n,7]*(-λ⁹⁻ᵇ[n]*τᵉⁿᵈ[2] + λ⁸⁻ᵇ[n,1]*τ⁰[2] - λ⁸⁻ᵇ[n,1]*τ⁰[2]/(R*C) + sum(λ⁸⁻ᵇ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ᵇ[n,t]*τ̲[2] - μ̅ᵀ⁻ᵇ[n,t]*τ̅[2] - μ̅ᵖᵀ⁻ᵇ[n,t]*P̅ᵀ for t in 1:T))
                                                + theta_sample[n,8]*(-λ¹²⁻ʷ[n]*S⁰ - sum(-λ¹¹⁻ʷ[n,t]*Pᵈ*(1-Uᴱⱽ[1,t]) + μ̲ᵉᵛ⁺⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̲V̲ - μ̅ᵉᵛ⁺⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̅V̅ + μ̲ᵉᵛ⁻⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̲V̲ - μ̅ᵉᵛ⁻⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̅V̅ + μ̲ˢ⁻ʷ[n,t]*S̲ - μ̅ˢ⁻ʷ[n,t]*S̅ for t in 1:T)) 
                                                + theta_sample[n,9]*(-λ¹²⁻ʷʰ[n]*S⁰ - sum(-λ¹¹⁻ʷʰ[n,t]*Pᵈ*(1-Uᴱⱽ[2,t]) + μ̲ᵉᵛ⁺⁻ʷʰ[n,t]*Uᴱⱽ[2,t]*E̲V̲ - μ̅ᵉᵛ⁺⁻ʷʰ[n,t]*Uᴱⱽ[2,t]*E̅V̅ + μ̲ᵉᵛ⁻⁻ʷʰ[n,t]*Uᴱⱽ[2,t]*E̲V̲ - μ̅ᵉᵛ⁻⁻ʷʰ[n,t]*Uᴱⱽ[2,t]*E̅V̅ + μ̲ˢ⁻ʷʰ[n,t]*S̲ - μ̅ˢ⁻ʷʰ[n,t]*S̅ for t in 1:T))
                                                for n in 1:N)
                                                >= sum(pⁱᵐ[t]*(DA_prices[t] .+ γⁱᵐ[t]) - pᵉˣ[t]*(DA_prices[t] .- γᵉˣ) for t in 1:T))
    elseif K == 10
        @constraint(linear, individual_rationality[n=1:N], theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                            + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                            + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening))
                                                            + theta_sample[n,4]*(sum(-λ¹³[n,t]*PV[t] for t in 1:T))
                                                            + theta_sample[n,5]*(λ⁵[n,1]*E⁰ - λ⁶[n]*E⁰ + sum(μ̲ᵇ[n,t]*B̲ - μ̅ᵇ[n,t]*B̅ + μ̲ᵉ[n,t]*E̲ - μ̅ᵉ[n,t]*E̅ for t in 1:T)) 
                                                            + theta_sample[n,6]*(-λ⁹⁻ˢ[n]*τᵉⁿᵈ[1] + λ⁸⁻ˢ[n,1]*τ⁰[1] - λ⁸⁻ˢ[n,1]*τ⁰[1]/(R*C) + sum(λ⁸⁻ˢ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ˢ[n,t]*τ̲[1] - μ̅ᵀ⁻ˢ[n,t]*τ̅[1] - μ̅ᵖᵀ⁻ˢ[n,t]*P̅ᵀ for t in 1:T)) 
                                                            + theta_sample[n,7]*(-λ⁹⁻ᵇ[n]*τᵉⁿᵈ[2] + λ⁸⁻ᵇ[n,1]*τ⁰[2] - λ⁸⁻ᵇ[n,1]*τ⁰[2]/(R*C) + sum(λ⁸⁻ᵇ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ᵇ[n,t]*τ̲[2] - μ̅ᵀ⁻ᵇ[n,t]*τ̅[2] - μ̅ᵖᵀ⁻ᵇ[n,t]*P̅ᵀ for t in 1:T))
                                                            + theta_sample[n,8]*(-λ¹²⁻ʷ[n]*S⁰ - λ¹¹⁻ʷ[n,1]*S⁰ - sum(-λ¹¹⁻ʷ[n,t]*Pᵈ*(1-Uᴱⱽ[1,t]) + μ̲ᵉᵛ⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̲V̲ - μ̅ᵉᵛ⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̅V̅ + μ̲ˢ⁻ʷ[n,t]*S̲ - μ̅ˢ⁻ʷ[n,t]*S̅ for t in 1:T))
                                                            + theta_sample[n,9]*(-λ¹²⁻ʷʰ[n]*S⁰ - λ¹¹⁻ʷʰ[n,1]*S⁰ - sum(-λ¹¹⁻ʷʰ[n,t]*Pᵈ*(1-Uᴱⱽ[2,t]) + μ̲ᵉᵛ⁻ʷʰ[n,t]*Uᴱⱽ[2,t]*E̲V̲ - μ̅ᵉᵛ⁻ʷʰ[n,t]*Uᴱⱽ[2,t]*E̅V̅ + μ̲ˢ⁻ʷʰ[n,t]*S̲ - μ̅ˢ⁻ʷʰ[n,t]*S̅ for t in 1:T))
                                                            + theta_sample[n,10]*(-λ¹²⁻ʳ[n]*S⁰ - λ¹¹⁻ʳ[n,1]*S⁰ - sum(-λ¹¹⁻ʳ[n,t]*Pᵈ*(1-Uᴱⱽ[3,t]) + μ̲ᵉᵛ⁻ʳ[n,t]*Uᴱⱽ[3,t]*E̲V̲ - μ̅ᵉᵛ⁻ʳ[n,t]*Uᴱⱽ[3,t]*E̅V̅ + μ̲ˢ⁻ʳ[n,t]*S̲ - μ̅ˢ⁻ʳ[n,t]*S̅ for t in 1:T))
                                                            <= Cᵉˣᵗ[n])

        @constraint(linear, revenue_adequacy, sum(theta_sample[n,1]*(sum(μ̲ˡ⁻¹[n,t]*minimum(L[n,:]) - μ̅ˡ⁻¹[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³⁻¹[n]*sum(L[n,t] for t in T_morning)) 
                                                + theta_sample[n,2]*(sum(μ̲ˡ⁻²[n,t]*minimum(L[n,:]) - μ̅ˡ⁻²[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³⁻²[n]*sum(L[n,t] for t in T_day)) 
                                                + theta_sample[n,3]*(sum(μ̲ˡ⁻³[n,t]*minimum(L[n,:]) - μ̅ˡ⁻³[n,t]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³⁻³[n]*sum(L[n,t] for t in T_evening))
                                                + theta_sample[n,4]*(sum(-λ¹³[n,t]*PV[t] for t in 1:T))
                                                + theta_sample[n,5]*(λ⁵[n,1]*E⁰ - λ⁶[n]*E⁰ + sum(μ̲ᵇ[n,t]*B̲ - μ̅ᵇ[n,t]*B̅ + μ̲ᵉ[n,t]*E̲ - μ̅ᵉ[n,t]*E̅ for t in 1:T)) 
                                                + theta_sample[n,6]*(-λ⁹⁻ˢ[n]*τᵉⁿᵈ[1] + λ⁸⁻ˢ[n,1]*τ⁰[1] - λ⁸⁻ˢ[n,1]*τ⁰[1]/(R*C) + sum(λ⁸⁻ˢ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ˢ[n,t]*τ̲[1] - μ̅ᵀ⁻ˢ[n,t]*τ̅[1] - μ̅ᵖᵀ⁻ˢ[n,t]*P̅ᵀ for t in 1:T)) 
                                                + theta_sample[n,7]*(-λ⁹⁻ᵇ[n]*τᵉⁿᵈ[2] + λ⁸⁻ᵇ[n,1]*τ⁰[2] - λ⁸⁻ᵇ[n,1]*τ⁰[2]/(R*C) + sum(λ⁸⁻ᵇ[n,t]*τᵉˣᵗ[t]/(R*C) for t in 1:T) + sum(μ̲ᵀ⁻ᵇ[n,t]*τ̲[2] - μ̅ᵀ⁻ᵇ[n,t]*τ̅[2] - μ̅ᵖᵀ⁻ᵇ[n,t]*P̅ᵀ for t in 1:T))
                                                + theta_sample[n,8]*(-λ¹²⁻ʷ[n]*S⁰ - λ¹¹⁻ʷ[n,1]*S⁰ - sum(-λ¹¹⁻ʷ[n,t]*Pᵈ*(1-Uᴱⱽ[1,t]) + μ̲ᵉᵛ⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̲V̲ - μ̅ᵉᵛ⁻ʷ[n,t]*Uᴱⱽ[1,t]*E̅V̅ + μ̲ˢ⁻ʷ[n,t]*S̲ - μ̅ˢ⁻ʷ[n,t]*S̅ for t in 1:T))
                                                + theta_sample[n,9]*(-λ¹²⁻ʷʰ[n]*S⁰ - λ¹¹⁻ʷʰ[n,1]*S⁰ - sum(-λ¹¹⁻ʷʰ[n,t]*Pᵈ*(1-Uᴱⱽ[2,t]) + μ̲ᵉᵛ⁻ʷʰ[n,t]*Uᴱⱽ[2,t]*E̲V̲ - μ̅ᵉᵛ⁻ʷʰ[n,t]*Uᴱⱽ[2,t]*E̅V̅ + μ̲ˢ⁻ʷʰ[n,t]*S̲ - μ̅ˢ⁻ʷʰ[n,t]*S̅ for t in 1:T))
                                                + theta_sample[n,10]*(-λ¹²⁻ʳ[n]*S⁰ - λ¹¹⁻ʳ[n,1]*S⁰ - sum(-λ¹¹⁻ʳ[n,t]*Pᵈ*(1-Uᴱⱽ[3,t]) + μ̲ᵉᵛ⁻ʳ[n,t]*Uᴱⱽ[3,t]*E̲V̲ - μ̅ᵉᵛ⁻ʳ[n,t]*Uᴱⱽ[3,t]*E̅V̅ + μ̲ˢ⁻ʳ[n,t]*S̲ - μ̅ˢ⁻ʳ[n,t]*S̅ for t in 1:T))
                                                for n in 1:N)
                                                >= sum(pⁱᵐ[t]*(DA_prices[t] .+ γⁱᵐ[t]) - pᵉˣ[t]*(DA_prices[t] .- γᵉˣ) for t in 1:T))
    end

    ### --- Lower Level Constraints --- ###
    if K >= 1
        ### Signature 1 ###
        @constraint(linear, KKT_flex_p_1[t=1:T,n=1:N], x[n,t] - λ¹⁻¹[n,t] == 0)                                                         #KKT for p in signature 1
        @constraint(linear, KKT_flex_l_1nonflex[t=setdiff(1:T,T_morning),n=1:N], λ¹⁻¹[n,t] + λ²⁻¹[n,t] - μ̲ˡ⁻¹[n,t] + μ̅ˡ⁻¹[n,t] == 0)    #KKT for l in nonflexible hours in signature 1
        @constraint(linear, KKT_flex_l_1flex[t=T_morning,n=1:N], λ¹⁻¹[n,t] + λ³⁻¹[n] - μ̲ˡ⁻¹[n,t] + μ̅ˡ⁻¹[n,t] == 0)                      #KKT for l in flexible hours in signature 1
        @constraint(linear, KKT_flex_lambda1_1[t=1:T,n=1:N], -p[n,t,1] + l⁻¹[n,t] == 0)                                       #KKT for λ¹ in signature 1
        @constraint(linear, KKT_flex_lambda2_1[t=setdiff(1:T,T_morning),n=1:N], l⁻¹[n,t] - L[n,t] == 0)                                 #KKT for λ² in signature 1
        @constraint(linear, KKT_flex_lambda3_1[n=1:N], sum(l⁻¹[n,t] - L[n,t] for t = T_morning) == 0)                                   #KKT for λ³ in signature 1
        @constraint(linear, KKT_flex_Lmin1[t=1:T,n=1:N], l⁻¹[n,t] >= minimum(L[n,:]))                                                  #Minimum load in signature 1
        @constraint(linear, KKT_flex_Lmax1[t=1:T,n=1:N], l⁻¹[n,t] <= maximum(L[n,:]))                                                  #Maximum load in signature 1
        #Complementarities for signature 1
        @constraint(linear, compl_μ̲ˡ_l_1[t=1:T,n=1:N], μ̲ˡ⁻¹[n,t] <= u̲ˡ⁻¹[n,t]*Mˡ)                                                      #Big-M constraint for dual variable in minimum load complementarity in signature 1
        @constraint(linear, compl_l_μ̲ˡ_1[t=1:T,n=1:N], l⁻¹[n,t] - minimum(L[n,:]) <= (1-u̲ˡ⁻¹[n,t])*Mˡ)                                 #Big-M constraint for load in minimum load complementarity in signature 1
        @constraint(linear, compl_μ̅ˡ_l_1[t=1:T,n=1:N], μ̅ˡ⁻¹[n,t] <= u̅ˡ⁻¹[n,t]*Mˡ)                                                      #Big-M constraint for dual variable in maximum load complementarity in signature 1
        @constraint(linear, compl_l_μ̅ˡ_1[t=1:T,n=1:N], maximum(L[n,:]) - l⁻¹[n,t] <= (1-u̅ˡ⁻¹[n,t])*Mˡ)                                 #Big-M constraint for load in maximum load complementarity in signature 1
    end

    if K >= 2
        ### Signature 2 ###
        @constraint(linear, KKT_flex_p_2[t=1:T,n=1:N], x[n,t] - λ¹⁻²[n,t] == 0)                                                         
        @constraint(linear, KKT_flex_l_2nonflex[t=setdiff(1:T,T_day),n=1:N], λ¹⁻²[n,t] + λ²⁻²[n,t] - μ̲ˡ⁻²[n,t] + μ̅ˡ⁻²[n,t] == 0)        
        @constraint(linear, KKT_flex_l_2flex[t=T_day,n=1:N], λ¹⁻²[n,t] + λ³⁻²[n] - μ̲ˡ⁻²[n,t] + μ̅ˡ⁻²[n,t] == 0)                         
        @constraint(linear, KKT_flex_lambda1_2[t=1:T,n=1:N], -p[n,t,2] + l⁻²[n,t] == 0)
        @constraint(linear, KKT_flex_lambda2_2[t=setdiff(1:T,T_day),n=1:N], l⁻²[n,t] - L[n,t] == 0)
        @constraint(linear, KKT_flex_lambda3_2[n=1:N], sum(l⁻²[n,t] - L[n,t] for t = T_day) == 0)
        @constraint(linear, KKT_flex_Lmin_2[t=1:T,n=1:N], l⁻²[n,t] >= minimum(L[n,:]))                                                  #Minimum load 
        @constraint(linear, KKT_flex_Lmax_2[t=1:T,n=1:N], l⁻²[n,t] <= maximum(L[n,:]))                                                  #Maximum load
        #Complementarities for signature 2
        @constraint(linear, compl_μ̲ˡ_l_2[t=1:T,n=1:N], μ̲ˡ⁻²[n,t] <= u̲ˡ⁻²[n,t]*Mˡ)                                                      #Big-M constraint for dual variable in minimum load complementarity 
        @constraint(linear, compl_l_μ̲ˡ_2[t=1:T,n=1:N], l⁻²[n,t] - minimum(L[n,:]) <= (1-u̲ˡ⁻²[n,t])*Mˡ)                                 #Big-M constraint for load in minimum load complementarity 
        @constraint(linear, compl_μ̅ˡ_l_2[t=1:T,n=1:N], μ̅ˡ⁻²[n,t] <= u̅ˡ⁻²[n,t]*Mˡ)                                                      #Big-M constraint for dual variable in maximum load complementarity 
        @constraint(linear, compl_l_μ̅ˡ_2[t=1:T,n=1:N], maximum(L[n,:]) - l⁻²[n,t] <= (1-u̅ˡ⁻²[n,t])*Mˡ)                                 #Big-M constraint for load in maximum load complementarity 
    end

    if K >= 3
        #Signature 3
        @constraint(linear, KKT_flex_p_3[t=1:T,n=1:N], x[n,t] - λ¹⁻³[n,t] == 0)
        @constraint(linear, KKT_flex_l_3nonflex[t=setdiff(1:T,T_evening),n=1:N], λ¹⁻³[n,t] + λ²⁻³[n,t] - μ̲ˡ⁻³[n,t] + μ̅ˡ⁻³[n,t] == 0)
        @constraint(linear, KKT_flex_l_3flex[t=T_evening,n=1:N], λ¹⁻³[n,t] + λ³⁻³[n] - μ̲ˡ⁻³[n,t] + μ̅ˡ⁻³[n,t] == 0)
        @constraint(linear, KKT_flex_lambda1_3[t=1:T,n=1:N], -p[n,t,3] + l⁻³[n,t] == 0)
        @constraint(linear, KKT_flex_lambda2_3[t=setdiff(1:T,T_evening),n=1:N], l⁻³[n,t] - L[n,t] == 0)
        @constraint(linear, KKT_flex_lambda3_3[n=1:N], sum(l⁻³[n,t] - L[n,t] for t = T_evening) == 0)
        @constraint(linear, KKT_flex_Lmin_3[t=1:T,n=1:N], l⁻³[n,t] >= minimum(L[n,:]))     #Minimum load 
        @constraint(linear, KKT_flex_Lmax_3[t=1:T,n=1:N], l⁻³[n,t] <= maximum(L[n,:]))     #Maximum load
        #Complementarities for signature 3
        @constraint(linear, compl_μ̲ˡ_l_3[t=1:T,n=1:N], μ̲ˡ⁻³[n,t] <= u̲ˡ⁻³[n,t]*Mˡ)                                                      #Big-M constraint for dual variable in minimum load complementarity 
        @constraint(linear, compl_l_μ̲ˡ_3[t=1:T,n=1:N], l⁻³[n,t] - minimum(L[n,:]) <= (1-u̲ˡ⁻³[n,t])*Mˡ)                                 #Big-M constraint for load in minimum load complementarity 
        @constraint(linear, compl_μ̅ˡ_l_3[t=1:T,n=1:N], μ̅ˡ⁻³[n,t] <= u̅ˡ⁻³[n,t]*Mˡ)                                                      #Big-M constraint for dual variable in maximum load complementarity 
        @constraint(linear, compl_l_μ̅ˡ_3[t=1:T,n=1:N], maximum(L[n,:]) - l⁻³[n,t] <= (1-u̅ˡ⁻³[n,t])*Mˡ)                                 #Big-M constraint for load in maximum load complementarity 
    end
    
    if K >= 4
        @constraint(linear, KKT_PV_p[n=1:N,t=1:T], x[n,t] - λ¹³[n,t] ==0)
        @constraint(linear, KKT_PV_λ¹³[n=1:N,t=1:T], - p[n,t,4] - PV[t] ==0)
    end

    if K >= 5
        #Signature 4
        @constraint(linear, KKT_battery_p[n=1:N,t=1:T], x[n,t] - λ⁴[n,t] == 0)
        @constraint(linear, KKT_battery_b[n=1:N,t=1:T], λ⁴[n,t] + λ⁵[n,t] - μ̲ᵇ[n,t] + μ̅ᵇ[n,t] == 0)
        @constraint(linear, KKT_battery_e[n=1:N,t=1:T-1], - λ⁵[n,t] + λ⁵[n,t+1] - μ̲ᵉ[n,t] + μ̅ᵉ[n,t] == 0)
        @constraint(linear, KKT_battery_e_24[n=1:N], - λ⁵[n,24] + λ⁶[n] - μ̲ᵉ[n,24] + μ̅ᵉ[n,24] == 0)
        @constraint(linear, KKT_battery_λ⁴[n=1:N,t=1:T], - p[n,t,5] + b[n,t] == 0)
        @constraint(linear, KKT_battery_λ⁵[n=1:N,t=2:T], e[n,t-1] - e[n,t] + b[n,t] == 0)
        @constraint(linear, KKT_battery_λ⁵_1[n=1:N], E⁰ - e[n,1] + b[n,1] == 0)
        @constraint(linear, KKT_battery_λ⁶[n=1:N], e[n,24] - E⁰ == 0)
        #Complementarities charging and discharging
        @constraint(linear, KKT_battery_b_min[t=1:T,n=1:N], b[n,t] >= B̲)
        @constraint(linear, KKT_battery_b_max[t=1:T,n=1:N], b[n,t] <= B̅)
        @constraint(linear, compl_μ̲ᵇ_b[t=1:T,n=1:N], μ̲ᵇ[n,t] <= u̲ᵇ[n,t]*M_charging_min)
        @constraint(linear, compl_b_μ̲ᵇ[t=1:T,n=1:N], b[n,t] - B̲ <= (1-u̲ᵇ[n,t])*M_charging_min)
        @constraint(linear, compl_μ̅ᵇ_b[t=1:T,n=1:N], μ̅ᵇ[n,t] <= u̅ᵇ[n,t]*M_charging_max)
        @constraint(linear, compl_b_μ̅ᵇ[t=1:T,n=1:N], B̅ - b[n,t] <= (1-u̅ᵇ[n,t])*M_charging_max)
        #Complementarities state of energy
        @constraint(linear, KKT_battery_e_min[t=1:T,n=1:N], e[n,t] >= E̲)
        @constraint(linear, KKT_battery_e_max[t=1:T,n=1:N], e[n,t] <= E̅)
        @constraint(linear, compl_μ̲ᵉ_e[t=1:T,n=1:N], μ̲ᵉ[n,t] <= u̲ᵉ[n,t]*M_soc)
        @constraint(linear, compl_e_μ̲ᵉ[t=1:T,n=1:N], e[n,t] - E̲ <= (1-u̲ᵉ[n,t])*M_soc)
        @constraint(linear, compl_μ̅ᵉ_e[t=1:T,n=1:N], μ̅ᵉ[n,t] <= u̅ᵉ[n,t]*M_soc)
        @constraint(linear, compl_e_μ̅ᵉ[t=1:T,n=1:N], E̅ - e[n,t] <= (1-u̅ᵉ[n,t])*M_soc)
    end

    if K >= 6
        #Signature 6 - small temperature range TCL
        @constraint(linear, KKT_TCL_p[n=1:N, t=1:T], x[n,t] - λ⁷⁻ˢ[n,t] == 0)
        @constraint(linear, KKT_TCL_pᵀ[n=1:N, t=1:T], λ⁷⁻ˢ[n,t] + ηᵀ*λ⁸⁻ˢ[n,t]/C - μ̲ᵖᵀ⁻ˢ[n,t] + μ̅ᵖᵀ⁻ˢ[n,t] == 0)
        @constraint(linear, KKT_τ[n=1:N, t=1:T-1], λ⁸⁻ˢ[n,t+1] - λ⁸⁻ˢ[n,t+1]/(R*C) - λ⁸⁻ˢ[n,t] - μ̲ᵀ⁻ˢ[n,t] + μ̅ᵀ⁻ˢ[n,t] == 0)
        @constraint(linear, KKT_τ_24[n=1:N], - λ⁸⁻ˢ[n,24] + λ⁹⁻ˢ[n] - μ̲ᵀ⁻ˢ[n,24] + μ̅ᵀ⁻ˢ[n,24] == 0)
        @constraint(linear, KKT_TCL_λ⁷[n=1:N, t=1:T], -p[n,t,6] + pᵀ⁻ˢ[n,t] == 0)
        @constraint(linear, KKT_TCL_λ⁸[n=1:N,t=2:T], τ⁻ˢ[n,t-1] - τ⁻ˢ[n,t] - 1/(R*C)*(τ⁻ˢ[n,t-1] - τᵉˣᵗ[t]) + ηᵀ/C*pᵀ⁻ˢ[n,t] == 0)
        @constraint(linear, KKT_TCL_λ⁸_1[n=1:N], τ⁰[1] - τ⁻ˢ[n,1] - 1/(R*C)*(τ⁰[1] - τᵉˣᵗ[1]) + ηᵀ/C*pᵀ⁻ˢ[n,1] == 0)
        @constraint(linear, KKT_TCL_λ⁹[n=1:N], τ⁻ˢ[n,24] == τᵉⁿᵈ[1])
        @constraint(linear, KKT_TCL_μ̅ᵖᵀ[n=1:N,t=1:T], pᵀ⁻ˢ[n,t] <= P̅ᵀ)
        @constraint(linear, KKT_TCL_μ̲ᵀ[n=1:N,t=1:T], τ⁻ˢ[n,t] >= τ̲[1])
        @constraint(linear, KKT_TCL_μ̅ᵀ[n=1:N,t=1:T], τ⁻ˢ[n,t] <= τ̅[1])
        #Complementarities 
        @constraint(linear, complementarity_μ̲ᵖᵀ[n=1:N,t=1:T ], μ̲ᵖᵀ⁻ˢ[n,t] <= u̲ᵖᵀ⁻ˢ[n,t]*Mᵀ)
        @constraint(linear, complementarity_pᵀ_min[n=1:N,t=1:T], pᵀ⁻ˢ[n,t] <= (1-u̲ᵖᵀ⁻ˢ[n,t])*Mᵀ)
        @constraint(linear, complementarity_μ̅ᵖᵀ[n=1:N,t=1:T], μ̅ᵖᵀ⁻ˢ[n,t] <= u̅ᵖᵀ⁻ˢ[n,t]*Mᵀ)
        @constraint(linear, complementarity_pᵀ_max[n=1:N,t=1:T], P̅ᵀ - pᵀ⁻ˢ[n,t] <= (1-u̅ᵖᵀ⁻ˢ[n,t])*Mᵀ)
        @constraint(linear, complementarity_μ̲ᵀ[n=1:N,t=1:T], μ̲ᵀ⁻ˢ[n,t] <= u̲ᵀ⁻ˢ[n,t]*Mᵀ)
        @constraint(linear, complementarity_τ_min[n=1:N,t=1:T], τ⁻ˢ[n,t] - τ̲[1] <= (1-u̲ᵀ⁻ˢ[n,t])*Mᵀ)
        @constraint(linear, complementarity_μ̅ᵀ[n=1:N,t=1:T], μ̅ᵀ⁻ˢ[n,t] <= u̅ᵀ⁻ˢ[n,t]*Mᵀ)
        @constraint(linear, complementarity_τ_max[n=1:N,t=1:T], τ̅[1] - τ⁻ˢ[n,t] <= (1-u̅ᵀ⁻ˢ[n,t])*Mᵀ)
    end

    if K >= 7
        #Signature 7- big temperature range TCL
        @constraint(linear, KKT_TCL_p_b[n=1:N, t=1:T], x[n,t] - λ⁷⁻ᵇ[n,t] == 0)
        @constraint(linear, KKT_TCL_pᵀ_b[n=1:N, t=1:T], λ⁷⁻ᵇ[n,t] + ηᵀ*λ⁸⁻ᵇ[n,t]/C - μ̲ᵖᵀ⁻ᵇ[n,t] + μ̅ᵖᵀ⁻ᵇ[n,t] == 0)
        @constraint(linear, KKT_τ_b[n=1:N, t=1:T-1], λ⁸⁻ᵇ[n,t+1] - λ⁸⁻ᵇ[n,t+1]/(R*C) - λ⁸⁻ᵇ[n,t] - μ̲ᵀ⁻ᵇ[n,t] + μ̅ᵀ⁻ᵇ[n,t] == 0)
        @constraint(linear, KKT_τ_24_b[n=1:N], - λ⁸⁻ᵇ[n,24] + λ⁹⁻ᵇ[n] - μ̲ᵀ⁻ᵇ[n,24] + μ̅ᵀ⁻ᵇ[n,24] == 0)
        @constraint(linear, KKT_TCL_λ⁷_b[n=1:N, t=1:T], -p[n,t,7] + pᵀ⁻ᵇ[n,t] == 0)
        @constraint(linear, KKT_TCL_λ⁸_b[n=1:N,t=2:T], τ⁻ᵇ[n,t-1] - τ⁻ᵇ[n,t] - 1/(R*C)*(τ⁻ᵇ[n,t-1] - τᵉˣᵗ[t]) + ηᵀ/C*pᵀ⁻ᵇ[n,t] == 0)
        @constraint(linear, KKT_TCL_λ⁸_1_b[n=1:N], τ⁰[2] - τ⁻ᵇ[n,1] - 1/(R*C)*(τ⁰[2] - τᵉˣᵗ[1]) + ηᵀ/C*pᵀ⁻ᵇ[n,1] == 0)
        @constraint(linear, KKT_TCL_λ⁹_b[n=1:N], τ⁻ᵇ[n,24] == τᵉⁿᵈ[2])
        @constraint(linear, KKT_TCL_μ̅ᵖᵀ_b[n=1:N,t=1:T], pᵀ⁻ᵇ[n,t] <= P̅ᵀ)
        @constraint(linear, KKT_TCL_μ̲ᵀ_b[n=1:N,t=1:T], τ⁻ᵇ[n,t] >= τ̲[2])
        @constraint(linear, KKT_TCL_μ̅ᵀ_b[n=1:N,t=1:T], τ⁻ᵇ[n,t] <= τ̅[2])
        #Complementarities 
        @constraint(linear, complementarity_μ̲ᵖᵀ_b[n=1:N,t=1:T ], μ̲ᵖᵀ⁻ᵇ[n,t] <= u̲ᵖᵀ⁻ᵇ[n,t]*Mᵀ)
        @constraint(linear, complementarity_pᵀ_b_min[n=1:N,t=1:T], pᵀ⁻ᵇ[n,t] <= (1-u̲ᵖᵀ⁻ᵇ[n,t])*Mᵀ)
        @constraint(linear, complementarity_μ̅ᵖᵀ_b[n=1:N,t=1:T], μ̅ᵖᵀ⁻ᵇ[n,t] <= u̅ᵖᵀ⁻ᵇ[n,t]*Mᵀ)
        @constraint(linear, complementarity_pᵀ_b_max[n=1:N,t=1:T], P̅ᵀ - pᵀ⁻ᵇ[n,t] <= (1-u̅ᵖᵀ⁻ᵇ[n,t])*Mᵀ)
        @constraint(linear, complementarity_μ̲ᵀ_b[n=1:N,t=1:T], μ̲ᵀ⁻ᵇ[n,t] <= u̲ᵀ⁻ᵇ[n,t]*Mᵀ)
        @constraint(linear, complementarity_τ_min_b[n=1:N,t=1:T], τ⁻ᵇ[n,t] - τ̲[2] <= (1-u̲ᵀ⁻ᵇ[n,t])*Mᵀ)
        @constraint(linear, complementarity_μ̅ᵀ_b[n=1:N,t=1:T], μ̅ᵀ⁻ᵇ[n,t] <= u̅ᵀ⁻ᵇ[n,t]*Mᵀ)
        @constraint(linear, complementarity_τ_max_b[n=1:N,t=1:T], τ̅[2] - τ⁻ᵇ[n,t] <= (1-u̅ᵀ⁻ᵇ[n,t])*Mᵀ)
    end


    if K >= 8
        #Signature 8 - EV away during work day
        @constraint(linear, KKT_EV_p[n=1:N,t=1:T], x[n,t] - λ¹⁰⁻ʷ[n,t] == 0)
        @constraint(linear, KKT_EV_ev[n=1:N,t=1:T], λ¹⁰⁻ʷ[n,t] + λ¹¹⁻ʷ[n,t] - μ̲ᵉᵛ⁻ʷ[n,t] + μ̅ᵉᵛ⁻ʷ[n,t] == 0)
        @constraint(linear, KKT_EV_s[n=1:N,t=1:T-1], -λ¹¹⁻ʷ[n,t] + λ¹¹⁻ʷ[n,t+1] - μ̲ˢ⁻ʷ[n,t] + μ̅ˢ⁻ʷ[n,t] == 0)
        @constraint(linear, KKT_EV_s24[n=1:N], -λ¹¹⁻ʷ[n,24] + λ¹²⁻ʷ[n] - μ̲ˢ⁻ʷ[n,24] + μ̅ˢ⁻ʷ[n,24] == 0)
        @constraint(linear, KKT_EV_λ¹⁰[n=1:N,t=1:T], - p[n,t,8] + ev⁻ʷ[n,t]== 0)
        @constraint(linear, KKT_EV_λ¹¹[n=1:N,t=2:T], s⁻ʷ[n,t-1] - s⁻ʷ[n,t] + ev⁻ʷ[n,t] - Pᵈ*(1-Uᴱⱽ[1,t])== 0)
        @constraint(linear, KKT_EV_λ¹¹_1[n=1:N], S⁰ - s⁻ʷ[n,1] + ev⁻ʷ[n,1] - Pᵈ*(1-Uᴱⱽ[1,1])== 0)
        @constraint(linear, KKT_EV_λ¹²[n=1:N], s⁻ʷ[n,24] == S⁰)
        @constraint(linear, KKT_EV_μ̲ᵉᵛ[n=1:N,t=1:T], ev⁻ʷ[n,t] >= Uᴱⱽ[1,t]*E̲V̲)
        @constraint(linear, KKT_EV_μ̅ᵉᵛ[n=1:N,t=1:T], ev⁻ʷ[n,t] <= Uᴱⱽ[1,t]*E̅V̅)
        @constraint(linear, KKT_EV_μ̲ˢ[n=1:N,t=1:T], s⁻ʷ[n,t] >= S̲)
        @constraint(linear, KKT_EV_μ̅ˢ[n=1:N,t=1:T], s⁻ʷ[n,t] <= S̅)
        #complementarities
        @constraint(linear, complementarity_μ̲ᵉᵛ[n=1:N,t=1:T], μ̲ᵉᵛ⁻ʷ[n,t] <= u̲ᵉᵛ⁻ʷ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev_min[n=1:N,t=1:T], ev⁻ʷ[n,t] - Uᴱⱽ[1,t]*E̲V̲ <= (1-u̲ᵉᵛ⁻ʷ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̅ᵉᵛ[n=1:N,t=1:T], μ̅ᵉᵛ⁻ʷ[n,t] <= u̅ᵉᵛ⁻ʷ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev_max[n=1:N,t=1:T], Uᴱⱽ[1,t]*E̅V̅ - ev⁻ʷ[n,t] <= (1-u̅ᵉᵛ⁻ʷ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̲ˢ[n=1:N,t=1:T], μ̲ˢ⁻ʷ[n,t] <= u̲ˢ⁻ʷ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_s_min[n=1:N,t=1:T], s⁻ʷ[n,t] - S̲ <= (1-u̲ˢ⁻ʷ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̅ˢ[n=1:N,t=1:T], μ̅ˢ⁻ʷ[n,t] <= u̅ˢ⁻ʷ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_s_max[n=1:N,t=1:T], S̅ - s⁻ʷ[n,t] <= (1-u̅ˢ⁻ʷ[n,t])*Mᴱⱽ)
    end

    if K >= 9
        #Signature 9 - EV away during work day and for a hobby
        @constraint(linear, KKT_EV_p_wh[n=1:N,t=1:T], x[n,t] - λ¹⁰⁻ʷʰ[n,t] == 0)
        @constraint(linear, KKT_EV_ev_wh[n=1:N,t=1:T], λ¹⁰⁻ʷʰ[n,t] + λ¹¹⁻ʷʰ[n,t] - μ̲ᵉᵛ⁻ʷʰ[n,t] + μ̅ᵉᵛ⁻ʷʰ[n,t] == 0)
        @constraint(linear, KKT_EV_s_wh[n=1:N,t=1:T-1], -λ¹¹⁻ʷʰ[n,t] + λ¹¹⁻ʷʰ[n,t+1] - μ̲ˢ⁻ʷʰ[n,t] + μ̅ˢ⁻ʷʰ[n,t] == 0)
        @constraint(linear, KKT_EV_s24_wh[n=1:N], -λ¹¹⁻ʷʰ[n,24] + λ¹²⁻ʷʰ[n] - μ̲ˢ⁻ʷʰ[n,24] + μ̅ˢ⁻ʷʰ[n,24] == 0)
        @constraint(linear, KKT_EV_λ¹⁰_wh[n=1:N,t=1:T], - p[n,t,9] + ev⁻ʷʰ[n,t]== 0)
        @constraint(linear, KKT_EV_λ¹¹_wh[n=1:N,t=2:T], s⁻ʷʰ[n,t-1] - s⁻ʷʰ[n,t] + ev⁻ʷʰ[n,t] - Pᵈ*(1-Uᴱⱽ[2,t])== 0)
        @constraint(linear, KKT_EV_λ¹¹_1_wh[n=1:N], S⁰ - s⁻ʷʰ[n,1] + ev⁻ʷʰ[n,1] - Pᵈ*(1-Uᴱⱽ[2,1])== 0)
        @constraint(linear, KKT_EV_λ¹²_wh[n=1:N], s⁻ʷʰ[n,24] == S⁰)
        @constraint(linear, KKT_EV_μ̲ᵉᵛ_wh[n=1:N,t=1:T], ev⁻ʷʰ[n,t] >= Uᴱⱽ[2,t]*E̲V̲)
        @constraint(linear, KKT_EV_μ̅ᵉᵛ_wh[n=1:N,t=1:T], ev⁻ʷʰ[n,t] <= Uᴱⱽ[2,t]*E̅V̅)
        @constraint(linear, KKT_EV_μ̲ˢ_wh[n=1:N,t=1:T], s⁻ʷʰ[n,t] >= S̲)
        @constraint(linear, KKT_EV_μ̅ˢ_wh[n=1:N,t=1:T], s⁻ʷʰ[n,t] <= S̅)
        #complementarities
        @constraint(linear, complementarity_μ̲ᵉᵛ_wh[n=1:N,t=1:T], μ̲ᵉᵛ⁻ʷʰ[n,t] <= u̲ᵉᵛ⁻ʷʰ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev_min_wh[n=1:N,t=1:T], ev⁻ʷʰ[n,t] - Uᴱⱽ[2,t]*E̲V̲ <= (1-u̲ᵉᵛ⁻ʷʰ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̅ᵉᵛ_wh[n=1:N,t=1:T], μ̅ᵉᵛ⁻ʷʰ[n,t] <= u̅ᵉᵛ⁻ʷʰ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev_max_wh[n=1:N,t=1:T], Uᴱⱽ[2,t]*E̅V̅ - ev⁻ʷʰ[n,t] <= (1-u̅ᵉᵛ⁻ʷʰ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̲ˢ_wh[n=1:N,t=1:T], μ̲ˢ⁻ʷʰ[n,t] <= u̲ˢ⁻ʷʰ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_s_min_wh[n=1:N,t=1:T], s⁻ʷʰ[n,t] - S̲ <= (1-u̲ˢ⁻ʷʰ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̅ˢ_wh[n=1:N,t=1:T], μ̅ˢ⁻ʷʰ[n,t] <= u̅ˢ⁻ʷʰ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_s_max_wh[n=1:N,t=1:T], S̅ - s⁻ʷʰ[n,t] <= (1-u̅ˢ⁻ʷʰ[n,t])*Mᴱⱽ)
    end

    if K >= 10
        #Signature 8 - EV away during work day
        @constraint(linear, KKT_EV_p_r[n=1:N,t=1:T], x[n,t] - λ¹⁰⁻ʳ[n,t] == 0)
        @constraint(linear, KKT_EV_ev_r[n=1:N,t=1:T], λ¹⁰⁻ʳ[n,t] + λ¹¹⁻ʳ[n,t] - μ̲ᵉᵛ⁻ʳ[n,t] + μ̅ᵉᵛ⁻ʳ[n,t] == 0)
        @constraint(linear, KKT_EV_s_r[n=1:N,t=1:T-1], -λ¹¹⁻ʳ[n,t] + λ¹¹⁻ʳ[n,t+1] - μ̲ˢ⁻ʳ[n,t] + μ̅ˢ⁻ʳ[n,t] == 0)
        @constraint(linear, KKT_EV_s24_r[n=1:N], -λ¹¹⁻ʳ[n,24] + λ¹²⁻ʳ[n] - μ̲ˢ⁻ʳ[n,24] + μ̅ˢ⁻ʳ[n,24] == 0)
        @constraint(linear, KKT_EV_λ¹⁰_r[n=1:N,t=1:T], - p[n,t,10] + ev⁻ʳ[n,t]== 0)
        @constraint(linear, KKT_EV_λ¹¹_r[n=1:N,t=2:T], s⁻ʳ[n,t-1] - s⁻ʳ[n,t] + ev⁻ʳ[n,t] - Pᵈ*(1-Uᴱⱽ[3,t])== 0)
        @constraint(linear, KKT_EV_λ¹¹_1_r[n=1:N], S⁰ - s⁻ʳ[n,1] + ev⁻ʳ[n,1] - Pᵈ*(1-Uᴱⱽ[3,1])== 0)
        @constraint(linear, KKT_EV_λ¹²_r[n=1:N], s⁻ʳ[n,24] == S⁰)
        @constraint(linear, KKT_EV_μ̲ᵉᵛ_r[n=1:N,t=1:T], ev⁻ʳ[n,t] >= Uᴱⱽ[3,t]*E̲V̲)
        @constraint(linear, KKT_EV_μ̅ᵉᵛ_r[n=1:N,t=1:T], ev⁻ʳ[n,t] <= Uᴱⱽ[3,t]*E̅V̅)
        @constraint(linear, KKT_EV_μ̲ˢ_r[n=1:N,t=1:T], s⁻ʳ[n,t] >= S̲)
        @constraint(linear, KKT_EV_μ̅ˢ_r[n=1:N,t=1:T], s⁻ʳ[n,t] <= S̅)
        #complementarities
        @constraint(linear, complementarity_μ̲ᵉᵛ_r[n=1:N,t=1:T], μ̲ᵉᵛ⁻ʳ[n,t] <= u̲ᵉᵛ⁻ʳ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev_min_r[n=1:N,t=1:T], ev⁻ʳ[n,t] - Uᴱⱽ[3,t]*E̲V̲ <= (1-u̲ᵉᵛ⁻ʳ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̅ᵉᵛ_r[n=1:N,t=1:T], μ̅ᵉᵛ⁻ʳ[n,t] <= u̅ᵉᵛ⁻ʳ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev_max_r[n=1:N,t=1:T], Uᴱⱽ[3,t]*E̅V̅ - ev⁻ʳ[n,t] <= (1-u̅ᵉᵛ⁻ʳ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̲ˢ_r[n=1:N,t=1:T], μ̲ˢ⁻ʳ[n,t] <= u̲ˢ⁻ʳ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_s_min_r[n=1:N,t=1:T], s⁻ʳ[n,t] - S̲ <= (1-u̲ˢ⁻ʳ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̅ˢ_r[n=1:N,t=1:T], μ̅ˢ⁻ʳ[n,t] <= u̅ˢ⁻ʳ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_s_max_r[n=1:N,t=1:T], S̅ - s⁻ʳ[n,t] <= (1-u̅ˢ⁻ʳ[n,t])*Mᴱⱽ)
    end

    ##################################
    ### --- OBJECTIVE FUNCTION --- ###
    ##################################

    #Capacity Limitation Objective Function
    @objective(linear,Min, sum(pⁱᵐ[t]*(DA_prices[t] .+ γⁱᵐ[t]) - pᵉˣ[t]*(DA_prices[t] .- γᵉˣ) + α*pᵖᵉⁿ[t] for t in 1:T))

    ####################################
    ### --- SOLVING AND PRINTING --- ###
    ####################################

    #println("Running model...")
    optimize!(linear)

    #println("Solve Time: ", solve_time(linear))
    #println("Termination Status: ", termination_status(linear))
    #println("Optimality Gap: ", MOI.get(linear, MOI.RelativeGap()))

    load_count = 0
    charging_count = 0
    discharging_count = 0
    soe_count = 0
    TCL_power_count = 0
    TCL_temp_count = 0
    ev_charging_count = 0
    ev_discharging_count = 0
    ev_soe_count = 0
    for n in 1:N
        for t in 1:T
            if K >= 1
                if (value.(μ̲ˡ⁻¹[n,t]) * (minimum(L[n,:]) - value.(l⁻¹[n,t])) >= 1e-2)|| (value.(μ̅ˡ⁻¹[n,t]) * (value.(l⁻¹[n,t]) - maximum(L[n,:])) >= 1e-2)
                    load_count += 1
                end
            end
            if K >= 2
                if (value.(μ̲ˡ⁻²[n,t]) * (minimum(L[n,:]) - value.(l⁻²[n,t])) >= 1e-2)|| (value.(μ̅ˡ⁻²[n,t]) * (value.(l⁻²[n,t]) - maximum(L[n,:])) >= 1e-2)
                    load_count += 1
                end
            end
            if K >= 3
                if (value.(μ̲ˡ⁻³[n,t]) * (minimum(L[n,:]) - value.(l⁻³[n,t])) >= 1e-2)|| (value.(μ̅ˡ⁻³[n,t]) * (value.(l⁻³[n,t]) - maximum(L[n,:])) >= 1e-2)
                    load_count += 1
                end
            end
            if K >= 5
                if (value.(μ̲ᵇ[n,t]) * (B̲ - value.(b[n,t])) >= 1e-2) || (value.(μ̅ᵇ[n,t]) * (value.(b[n,t]) - B̅)>= 1e-2)
                    charging_count += 1
                end
                if (value.(μ̲ᵉ[n,t]) * (E̲ - value.(e[n,t])) >= 1e-2) || (value.(μ̅ᵉ[n,t]) * (value.(e[n,t]) - E̅)>= 1e-2)
                    soe_count += 1
                end
            end
            if K >= 6
                if (value.(μ̲ᵖᵀ⁻ˢ[n,t])*value.(pᵀ⁻ˢ[n,t]) >= 1e-2) || (value.(μ̅ᵖᵀ⁻ˢ[n,t])*(P̅ᵀ - value.(pᵀ⁻ˢ[n,t])) >= 1e-2)
                    TCL_power_count += 1
                end
                if value.(μ̲ᵀ⁻ˢ[n,t]) * (value.(τ⁻ˢ[n,t]) - τ̲[1]) >= 1e-2 || value.(μ̅ᵀ⁻ˢ[n,t])*( τ̅[1] - value.(τ⁻ˢ[n,t])) >= 1e-2 
                    TCL_temp_count += 1
                end
            end
            if K >= 7
                if (value.(μ̲ᵖᵀ⁻ᵇ[n,t])*value.(pᵀ⁻ᵇ[n,t]) >= 1e-2) || (value.(μ̅ᵖᵀ⁻ᵇ[n,t])*(P̅ᵀ - value.(pᵀ⁻ᵇ[n,t])) >= 1e-2)
                    TCL_power_count += 1
                end
                if value.(μ̲ᵀ⁻ᵇ[n,t]) * (value.(τ⁻ᵇ[n,t]) - τ̲[2]) >= 1e-2 || value.(μ̲ᵀ⁻ᵇ[n,t])*( τ̅[2] - value.(τ⁻ᵇ[n,t])) >= 1e-2 
                    TCL_temp_count += 1
            end
            if K >= 8
                if (value.(μ̲ᵉᵛ⁻ʷ[n,t]) * (Uᴱⱽ[1,t]*E̲V̲ - value.(ev⁻ʷ[n,t])) >= 1e-2) || (value.(μ̅ᵉᵛ⁻ʷ[n,t]) * (value.(ev⁻ʷ[n,t]) - Uᴱⱽ[1,t]*E̅V̅)>= 1e-2)
                    ev_charging_count += 1
                end
                if (value.(μ̲ˢ⁻ʷ[n,t]) * (S̲ - value.(s⁻ʷ[n,t])) >= 1e-2) || (value.(μ̅ˢ⁻ʷ[n,t]) * (value.(s⁻ʷ[n,t]) - S̅)>= 1e-2)
                    ev_soe_count += 1
                end
            end
            if K >= 9
                if (value.(μ̲ᵉᵛ⁻ʷʰ[n,t]) * (Uᴱⱽ[2,t]*E̲V̲ - value.(ev⁻ʷʰ[n,t])) >= 1e-2) || (value.(μ̅ᵉᵛ⁻ʷʰ[n,t]) * (value.(ev⁻ʷʰ[n,t]) - Uᴱⱽ[2,t]*E̅V̅)>= 1e-2)
                    ev_charging_count += 1
                end
                if (value.(μ̲ˢ⁻ʷʰ[n,t]) * (S̲ - value.(s⁻ʷʰ[n,t])) >= 1e-2) || (value.(μ̅ˢ⁻ʷʰ[n,t]) * (value.(s⁻ʷʰ[n,t]) - S̅)>= 1e-2)
                    ev_soe_count += 1
                end
            end
            if K >= 10
                if (value.(μ̲ᵉᵛ⁻ʳ[n,t]) * (Uᴱⱽ[3,t]*E̲V̲ - value.(ev⁻ʳ[n,t])) >= 1e-2) || (value.(μ̅ᵉᵛ⁻ʳ[n,t]) * (value.(ev⁻ʳ[n,t]) - Uᴱⱽ[3,t]*E̅V̅)>= 1e-2)
                    ev_charging_count += 1
                end
                if (value.(μ̲ˢ⁻ʳ[n,t]) * (S̲ - value.(s⁻ʳ[n,t])) >= 1e-2) || (value.(μ̅ˢ⁻ʳ[n,t]) * (value.(s⁻ʳ[n,t]) - S̅)>= 1e-2)
                    ev_soe_count += 1
                end
            end

            end
        end
    end
    #=
    if load_count >= 1 || charging_count >= 1 || discharging_count >= 1 || soe_count >= 1 || TCL_power_count >= 1 || TCL_temp_count >= 1 || ev_charging_count >= 1 || ev_discharging_count >= 1 || ev_soe_count >= 1
        println("Load Complementarities Broken: ", load_count)
        println("Charging Complementarities Broken: ", charging_count)
        println("Discharging Complementarities Broken: ", discharging_count)
        println("SOE Complementarities Broken: ", soe_count)
        println("TCL Power Complementarities Broken: ", TCL_power_count)
        println("TCL Temperature Complementarities Broken: ", TCL_temp_count)
        println("EV Charging Complementarities Broken: ", ev_charging_count)
        println("EV Discharging Complementarities Broken: ", ev_discharging_count)
        println("EV SOE Complementarities Broken: ", ev_soe_count)
    end
    =#
    #=
    if K >= 4
        println("Battery Consumers")
        for n in 1:N
            println("Primal: ", sum(value.(p[n,t,4]).*value.(x[n,t]) for t in 1:T))
            println("Dual: ", value.(λ⁵[n,1])*E⁰ - value.(λ⁶[n])*E⁰ + sum(value.(μ̲ᵇ⁺[n,t])*B̲ - value.(μ̅ᵇ⁺[n,t])*B̅ + value.(μ̲ᵇ⁻[n,t])*B̲ - value.(μ̅ᵇ⁻[n,t])*B̅ + value.(μ̲ᵉ[n,t])*E̲ - value.(μ̅ᵉ[n,t])*E̅ for t in 1:T))
        end
        plot()
        for n in 1:N
            plot!(value.(b⁺[n,:])-value.(b⁻[n,:]), title = "Battery", xlabel = "Time [h]", ylabel = "Power [kW] / SOE [kWh]", label = "+/- for Consumer $n")
            plot!(value.(e[n,:]), label = "SOE for Consumer $n")
        end
        display(plot!())
    end
    if K >= 5
        println("TCL Consumers")
        for n in 1:N
            println("Primal: ", sum(value.(p[n,t,5]).*value.(x[n,t]) for t in 1:T))
            println("Dual: ", -value.(λ⁹)[n]*τᵉⁿᵈ[n] + value.(λ⁸[n,1])*τ⁰[n] - value.(λ⁸[n,1])*τ⁰[n]/(R[n]*C[n]) + sum(value.(λ⁸[n,t])*τᵉˣᵗ[t]/(R[n]*C[n]) for t in 1:T) + sum(value.(μ̲ᵀ[n,t])*τ̲[n] - value.(μ̅ᵀ[n,t])*τ̅[n] - value.(μ̅ᵖᵀ[n,t])*P̅ᵀ for t in 1:T))
        end
        plot()
        for n in 1:N
            plot!(value.(pᵀ[n,:]), title = "TCL", xlabel = "Time [h]", ylabel = "Power [kW]", label = "Consumer $n")
        end
        display(plot!())
        plot()
        for n in 1:N
            plot!(value.(τ[n,:]), title = "Temperature", xlabel = "Time [h]", ylabel = "Temperature [C]", label = "Consumer $n")
        end
        display(plot!())
    end
    if K >= 6
        println("EV consumers")
        for n in 1:N
            println("Primal: ", sum(value.(p[n,t,6]).*value.(x[n,t]) for t in 1:T))
            println("Dual: ", -value.(λ¹²[n])*S⁰[n] - sum(value.(-λ¹¹[n,t])*Pᵈ*(1-Uᴱⱽ[n,t]) + value.(μ̲ᵉᵛ⁺[n,t])*Uᴱⱽ[n,t]*E̲V̲[n] - value.(μ̅ᵉᵛ⁺[n,t])*Uᴱⱽ[n,t]*E̅V̅[n] + value.(μ̲ᵉᵛ⁻[n,t])*Uᴱⱽ[n,t]*E̲V̲[n] - value.(μ̅ᵉᵛ⁻[n,t])*Uᴱⱽ[n,t]*E̅V̅[n] + value.(μ̲ˢ[n,t])*S̲[n] - value.(μ̅ᵉᵛ⁺[n,t])*S̅[n] for t in 1:T))
        end
    end
    =#

    #=
    if K >= 5
        ### Signature 5 - Battery ###
        @variable(linear, b⁺[1:N,1:T])                                 #battery charging power [kW]
        @variable(linear, b⁻[1:N,1:T])                                 #battery discharging power [kW]
        @variable(linear, e[1:N,1:T])                                  #state of energy of the battery [kWh]
        @variable(linear, λ⁴[1:N,1:T])                                 #dual of the power balance equation
        @variable(linear, λ⁵[1:N,1:T])                                 #dual of the battery balance constraint
        @variable(linear, λ⁶[1:N])                                     #dual of the initial and final battery balance
        @variable(linear, μ̲ᵇ⁺[1:N,1:T] >= 0)                           #dual of the lower limit of charging power
        @variable(linear, μ̅ᵇ⁺[1:N,1:T] >= 0)                           #dual of the upper limit of charging power
        @variable(linear, μ̲ᵇ⁻[1:N,1:T] >= 0)                           #dual of the lower limit of discharging power
        @variable(linear, μ̅ᵇ⁻[1:N,1:T] >= 0)                           #dual of the upper limit of discharging power
        @variable(linear, μ̲ᵉ[1:N,1:T] >= 0)                            #dual of the lower limit of state of energy
        @variable(linear, μ̅ᵉ[1:N,1:T] >= 0)                            #dual of the upper limit of state of energy
        #Binaries for complementarities
        @variable(linear, u̲ᵇ⁺[1:N,1:T], Bin)                           #Binary variable for minimum battery charging
        @variable(linear, u̅ᵇ⁺[1:N,1:T], Bin)                           #Binary variable for maximum battery charging
        @variable(linear, u̲ᵇ⁻[1:N,1:T], Bin)                           #Binary variable for minimum battery discharging
        @variable(linear, u̅ᵇ⁻[1:N,1:T], Bin)                           #Binary variable for maximum battery discharging
        @variable(linear, u̲ᵉ[1:N,1:T], Bin)                            #Binary variable for minimum state of energy 
        @variable(linear, u̅ᵉ[1:N,1:T], Bin)                            #Binary variable for maximum state of energy
    end
    =#
        #=
    if K >= 5
        #Signature 4
        @constraint(linear, KKT_battery_p[n=1:N,t=1:T], x[n,t] - λ⁴[n,t] == 0)
        @constraint(linear, KKT_battery_b⁺[n=1:N,t=1:T], λ⁴[n,t]/η + λ⁵[n,t] - μ̲ᵇ⁺[n,t] + μ̅ᵇ⁺[n,t] == 0)
        @constraint(linear, KKT_battery_b⁻[n=1:N,t=1:T], - λ⁴[n,t]*η - λ⁵[n,t]  - μ̲ᵇ⁻[n,t] + μ̅ᵇ⁻[n,t] == 0)
        @constraint(linear, KKT_battery_e[n=1:N,t=1:T-1], - λ⁵[n,t] + λ⁵[n,t+1] - μ̲ᵉ[n,t] + μ̅ᵉ[n,t] == 0)
        @constraint(linear, KKT_battery_e_24[n=1:N], - λ⁵[n,24] + λ⁶[n] - μ̲ᵉ[n,24] + μ̅ᵉ[n,24] == 0)
        @constraint(linear, KKT_battery_λ⁴[n=1:N,t=1:T], - p[n,t,5] + b⁺[n,t]/η - η*b⁻[n,t] == 0)
        @constraint(linear, KKT_battery_λ⁵[n=1:N,t=2:T], e[n,t-1] - e[n,t] + b⁺[n,t] - b⁻[n,t] == 0)
        @constraint(linear, KKT_battery_λ⁵_1[n=1:N], E⁰ - e[n,1] + b⁺[n,1] - b⁻[n,1] == 0)
        @constraint(linear, KKT_battery_λ⁶[n=1:N], e[n,24] - E⁰ == 0)
        #Complementarities charging
        @constraint(linear, KKT_battery_b⁺_min[t=1:T,n=1:N], b⁺[n,t] >= B̲)
        @constraint(linear, KKT_battery_b⁺_max[t=1:T,n=1:N], b⁺[n,t] <= B̅)
        @constraint(linear, compl_μ̲ᵇ⁺_b⁺[t=1:T,n=1:N], μ̲ᵇ⁺[n,t] <= u̲ᵇ⁺[n,t]*M_charging_min)
        @constraint(linear, compl_b⁺_μ̲ᵇ⁺[t=1:T,n=1:N], b⁺[n,t] - B̲ <= (1-u̲ᵇ⁺[n,t])*M_charging_min)
        @constraint(linear, compl_μ̅ᵇ⁺_b⁺[t=1:T,n=1:N], μ̅ᵇ⁺[n,t] <= u̅ᵇ⁺[n,t]*M_charging_max)
        @constraint(linear, compl_b⁺_μ̅ᵇ⁺[t=1:T,n=1:N], B̅ - b⁺[n,t] <= (1-u̅ᵇ⁺[n,t])*M_charging_max)
        #Complementarities discharging
        @constraint(linear, KKT_battery_b⁻_min[t=1:T,n=1:N], b⁻[n,t] >= B̲)
        @constraint(linear, KKT_battery_b⁻_max[t=1:T,n=1:N], b⁻[n,t] <= B̅)
        @constraint(linear, compl_μ̲ᵇ⁻_b⁻[t=1:T,n=1:N], μ̲ᵇ⁻[n,t] <= u̲ᵇ⁻[n,t]*M_discharging)
        @constraint(linear, compl_b⁻_μ̲ᵇ⁻[t=1:T,n=1:N], b⁻[n,t] - B̲ <= (1-u̲ᵇ⁻[n,t])*M_discharging)
        @constraint(linear, compl_μ̅ᵇ⁻_b⁻[t=1:T,n=1:N], μ̅ᵇ⁻[n,t] <= u̅ᵇ⁻[n,t]*M_discharging)
        @constraint(linear, compl_b⁻_μ̅ᵇ⁻[t=1:T,n=1:N], B̅ - b⁻[n,t] <= (1-u̅ᵇ⁻[n,t])*M_discharging)
        #Complementarities state of energy
        @constraint(linear, KKT_battery_e_min[t=1:T,n=1:N], e[n,t] >= E̲)
        @constraint(linear, KKT_battery_e_max[t=1:T,n=1:N], e[n,t] <= E̅)
        @constraint(linear, compl_μ̲ᵉ_e[t=1:T,n=1:N], μ̲ᵉ[n,t] <= u̲ᵉ[n,t]*M_soc)
        @constraint(linear, compl_e_μ̲ᵉ[t=1:T,n=1:N], e[n,t] - E̲ <= (1-u̲ᵉ[n,t])*M_soc)
        @constraint(linear, compl_μ̅ᵉ_e[t=1:T,n=1:N], μ̅ᵉ[n,t] <= u̅ᵉ[n,t]*M_soc)
        @constraint(linear, compl_e_μ̅ᵉ[t=1:T,n=1:N], E̅ - e[n,t] <= (1-u̅ᵉ[n,t])*M_soc)
    end
    =#

     ### EV WITH EFFICIENCY LOSSES ###
    #=
    if K >= 8
        #Signature 8 - EV away during work day
        @constraint(linear, KKT_EV_p[n=1:N,t=1:T], x[n,t] - λ¹⁰⁻ʷ[n,t] == 0)
        @constraint(linear, KKT_EV_ev⁺[n=1:N,t=1:T], λ¹⁰⁻ʷ[n,t]/η + λ¹¹⁻ʷ[n,t] - μ̲ᵉᵛ⁺⁻ʷ[n,t] + μ̅ᵉᵛ⁺⁻ʷ[n,t] == 0)
        @constraint(linear, KKT_EV_ev⁻[n=1:N,t=1:T], -η*λ¹⁰⁻ʷ[n,t] - λ¹¹⁻ʷ[n,t] - μ̲ᵉᵛ⁻⁻ʷ[n,t] + μ̅ᵉᵛ⁻⁻ʷ[n,t] == 0)
        @constraint(linear, KKT_EV_s[n=1:N,t=1:T-1], -λ¹¹⁻ʷ[n,t] + λ¹¹⁻ʷ[n,t+1] - μ̲ˢ⁻ʷ[n,t] + μ̅ˢ⁻ʷ[n,t] == 0)
        @constraint(linear, KKT_EV_s24[n=1:N], -λ¹¹⁻ʷ[n,24] + λ¹¹⁻ʷ[n,1] + λ¹²⁻ʷ[n] - μ̲ˢ⁻ʷ[n,24] + μ̅ˢ⁻ʷ[n,24] == 0)
        @constraint(linear, KKT_EV_λ¹⁰[n=1:N,t=1:T], - p[n,t,8] + ev⁺⁻ʷ[n,t]/η - η*ev⁻⁻ʷ[n,t] == 0)
        @constraint(linear, KKT_EV_λ¹¹[n=1:N,t=2:T], s⁻ʷ[n,t-1] - s⁻ʷ[n,t] + ev⁺⁻ʷ[n,t] - ev⁻⁻ʷ[n,t] - Pᵈ*(1-Uᴱⱽ[1,t])== 0)
        @constraint(linear, KKT_EV_λ¹¹_1[n=1:N], S⁰ - s⁻ʷ[n,1] + ev⁺⁻ʷ[n,1] - ev⁻⁻ʷ[n,1] - Pᵈ*(1-Uᴱⱽ[1,1])== 0)
        @constraint(linear, KKT_EV_λ¹²[n=1:N], s⁻ʷ[n,24] == S⁰)
        @constraint(linear, KKT_EV_μ̲ᵉᵛ⁺[n=1:N,t=1:T], ev⁺⁻ʷ[n,t] >= E̲V̲)
        @constraint(linear, KKT_EV_μ̅ᵉᵛ⁺[n=1:N,t=1:T], ev⁺⁻ʷ[n,t] <= E̅V̅)
        @constraint(linear, KKT_EV_μ̲ᵉᵛ⁻[n=1:N,t=1:T], ev⁻⁻ʷ[n,t] >= E̲V̲)
        @constraint(linear, KKT_EV_μ̅ᵉᵛ⁻[n=1:N,t=1:T], ev⁻⁻ʷ[n,t] <= E̅V̅)
        @constraint(linear, KKT_EV_μ̲ˢ[n=1:N,t=1:T], s⁻ʷ[n,t] >= S̲)
        @constraint(linear, KKT_EV_μ̅ˢ[n=1:N,t=1:T], s⁻ʷ[n,t] <= S̅)
        #complementarities
        @constraint(linear, complementarity_μ̲ᵉᵛ⁺[n=1:N,t=1:T], μ̲ᵉᵛ⁺⁻ʷ[n,t] <= u̲ᵉᵛ⁺⁻ʷ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev⁺_min[n=1:N,t=1:T], ev⁺⁻ʷ[n,t] - E̲V̲ <= (1-u̲ᵉᵛ⁺⁻ʷ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̅ᵉᵛ⁺[n=1:N,t=1:T], μ̅ᵉᵛ⁺⁻ʷ[n,t] <= u̅ᵉᵛ⁺⁻ʷ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev⁺_max[n=1:N,t=1:T], E̅V̅ - ev⁺⁻ʷ[n,t] <= (1-u̅ᵉᵛ⁺⁻ʷ[n,t])*Mᴱⱽ)
        #@constraint(linear, complementarity_μ̲ᵉᵛ⁻[n=1:N,t=1:T], μ̲ᵉᵛ⁻⁻ʷ[n,t] <= u̲ᵉᵛ⁻⁻ʷ[n,t]*Mᴱⱽ)
        #@constraint(linear, complementarity_ev⁻_min[n=1:N,t=1:T], ev⁻⁻ʷ[n,t] - E̲V̲ <= (1-u̲ᵉᵛ⁻⁻ʷ[n,t])*Mᴱⱽ)
        #@constraint(linear, complementarity_μ̅ᵉᵛ⁻[n=1:N,t=1:T], μ̅ᵉᵛ⁻⁻ʷ[n,t] <= u̅ᵉᵛ⁻⁻ʷ[n,t]*Mᴱⱽ)
        #@constraint(linear, complementarity_ev⁻_max[n=1:N,t=1:T], E̅V̅ - ev⁻⁻ʷ[n,t] <= (1-u̅ᵉᵛ⁻⁻ʷ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̲ˢ[n=1:N,t=1:T], μ̲ˢ⁻ʷ[n,t] <= u̲ˢ⁻ʷ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_s_min[n=1:N,t=1:T], s⁻ʷ[n,t] - S̲ <= (1-u̲ˢ⁻ʷ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̅ˢ[n=1:N,t=1:T], μ̅ˢ⁻ʷ[n,t] <= u̅ˢ⁻ʷ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_s_max[n=1:N,t=1:T], S̅ - s⁻ʷ[n,t] <= (1-u̅ˢ⁻ʷ[n,t])*Mᴱⱽ)
    end
    
    if K >= 9
        #Signature 8 - EV away during work day and for a hobby in the evening
        @constraint(linear, KKT_EV_p_wh[n=1:N,t=1:T], x[n,t] - λ¹⁰⁻ʷʰ[n,t] == 0)
        @constraint(linear, KKT_EV_ev⁺_wh[n=1:N,t=1:T], λ¹⁰⁻ʷʰ[n,t]/η + λ¹¹⁻ʷʰ[n,t] - μ̲ᵉᵛ⁺⁻ʷʰ[n,t] + μ̅ᵉᵛ⁺⁻ʷʰ[n,t] == 0)
        @constraint(linear, KKT_EV_ev⁻_wh[n=1:N,t=1:T], -η*λ¹⁰⁻ʷʰ[n,t] - λ¹¹⁻ʷʰ[n,t] - μ̲ᵉᵛ⁻⁻ʷʰ[n,t] + μ̅ᵉᵛ⁻⁻ʷʰ[n,t] == 0)
        @constraint(linear, KKT_EV_s_wh[n=1:N,t=1:T-1], -λ¹¹⁻ʷʰ[n,t] + λ¹¹⁻ʷʰ[n,t+1] - μ̲ˢ⁻ʷʰ[n,t] + μ̅ˢ⁻ʷʰ[n,t] == 0)
        @constraint(linear, KKT_EV_s24_wh[n=1:N], -λ¹¹⁻ʷʰ[n,24] + λ¹¹⁻ʷʰ[n,1] + λ¹²⁻ʷʰ[n] - μ̲ˢ⁻ʷʰ[n,24] + μ̅ˢ⁻ʷʰ[n,24] == 0)
        @constraint(linear, KKT_EV_λ¹⁰_wh[n=1:N,t=1:T], - p[n,t,9] + ev⁺⁻ʷʰ[n,t]/η - η*ev⁻⁻ʷʰ[n,t] == 0)
        @constraint(linear, KKT_EV_λ¹¹_wh[n=1:N,t=2:T], s⁻ʷʰ[n,t-1] - s⁻ʷʰ[n,t] + ev⁺⁻ʷʰ[n,t] - ev⁻⁻ʷʰ[n,t] - Pᵈ*(1-Uᴱⱽ[2,t])== 0)
        @constraint(linear, KKT_EV_λ¹¹_1_wh[n=1:N], S⁰ - s⁻ʷʰ[n,1] + ev⁺⁻ʷʰ[n,1] - ev⁻⁻ʷʰ[n,1] - Pᵈ*(1-Uᴱⱽ[2,1])== 0)
        @constraint(linear, KKT_EV_λ¹²_wh[n=1:N], s⁻ʷʰ[n,24] == S⁰)
        @constraint(linear, KKT_EV_μ̲ᵉᵛ⁺_wh[n=1:N,t=1:T], ev⁺⁻ʷʰ[n,t] >= E̲V̲)
        @constraint(linear, KKT_EV_μ̅ᵉᵛ⁺_wh[n=1:N,t=1:T], ev⁺⁻ʷʰ[n,t] <= E̅V̅)
        @constraint(linear, KKT_EV_μ̲ᵉᵛ⁻_wh[n=1:N,t=1:T], ev⁻⁻ʷʰ[n,t] >= E̲V̲)
        @constraint(linear, KKT_EV_μ̅ᵉᵛ⁻_wh[n=1:N,t=1:T], ev⁻⁻ʷʰ[n,t] <= E̅V̅)
        @constraint(linear, KKT_EV_μ̲ˢ_wh[n=1:N,t=1:T], s⁻ʷʰ[n,t] >= S̲)
        @constraint(linear, KKT_EV_μ̅ˢ_wh[n=1:N,t=1:T], s⁻ʷʰ[n,t] <= S̅)
        #complementarities
        @constraint(linear, complementarity_μ̲ᵉᵛ⁺_wh[n=1:N,t=1:T], μ̲ᵉᵛ⁺⁻ʷʰ[n,t] <= u̲ᵉᵛ⁺⁻ʷʰ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev⁺_min_wh[n=1:N,t=1:T], ev⁺⁻ʷʰ[n,t] - E̲V̲ <= (1-u̲ᵉᵛ⁺⁻ʷʰ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̅ᵉᵛ⁺_wh[n=1:N,t=1:T], μ̅ᵉᵛ⁺⁻ʷʰ[n,t] <= u̅ᵉᵛ⁺⁻ʷʰ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev⁺_max_wh[n=1:N,t=1:T], E̅V̅ - ev⁺⁻ʷʰ[n,t] <= (1-u̅ᵉᵛ⁺⁻ʷʰ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̲ᵉᵛ⁻_wh[n=1:N,t=1:T], μ̲ᵉᵛ⁻⁻ʷʰ[n,t] <= u̲ᵉᵛ⁻⁻ʷʰ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev⁻_min_wh[n=1:N,t=1:T], ev⁻⁻ʷʰ[n,t] - E̲V̲ <= (1-u̲ᵉᵛ⁻⁻ʷʰ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̅ᵉᵛ⁻_wh[n=1:N,t=1:T], μ̅ᵉᵛ⁻⁻ʷʰ[n,t] <= u̅ᵉᵛ⁻⁻ʷʰ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev⁻_max_wh[n=1:N,t=1:T], E̅V̅ - ev⁻⁻ʷʰ[n,t] <= (1-u̅ᵉᵛ⁻⁻ʷʰ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̲ˢ_wh[n=1:N,t=1:T], μ̲ˢ⁻ʷʰ[n,t] <= u̲ˢ⁻ʷʰ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_s_min_wh[n=1:N,t=1:T], s⁻ʷʰ[n,t] - S̲ <= (1-u̲ˢ⁻ʷʰ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̅ˢ_wh[n=1:N,t=1:T], μ̅ˢ⁻ʷʰ[n,t] <= u̅ˢ⁻ʷʰ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_s_max_wh[n=1:N,t=1:T], S̅ - s⁻ʷʰ[n,t] <= (1-u̅ˢ⁻ʷʰ[n,t])*Mᴱⱽ)
    end
   
    if K >= 10
        #Signature 8 - EV away during rush hours
        @constraint(linear, KKT_EV_p_r[n=1:N,t=1:T], x[n,t] - λ¹⁰⁻ʳ[n,t] == 0)
        @constraint(linear, KKT_EV_ev⁺_r[n=1:N,t=1:T], λ¹⁰⁻ʳ[n,t]/η + λ¹¹⁻ʳ[n,t] - μ̲ᵉᵛ⁺⁻ʳ[n,t] + μ̅ᵉᵛ⁺⁻ʳ[n,t] == 0)
        @constraint(linear, KKT_EV_ev⁻_r[n=1:N,t=1:T], -η*λ¹⁰⁻ʳ[n,t] - λ¹¹⁻ʳ[n,t] - μ̲ᵉᵛ⁻⁻ʳ[n,t] + μ̅ᵉᵛ⁻⁻ʳ[n,t] == 0)
        @constraint(linear, KKT_EV_s_r[n=1:N,t=1:T-1], -λ¹¹⁻ʳ[n,t] + λ¹¹⁻ʳ[n,t+1] - μ̲ˢ⁻ʳ[n,t] + μ̅ˢ⁻ʳ[n,t] == 0)
        @constraint(linear, KKT_EV_s24_r[n=1:N], -λ¹¹⁻ʳ[n,24] + λ¹¹⁻ʳ[n,1] + λ¹²⁻ʳ[n] - μ̲ˢ⁻ʳ[n,24] + μ̅ˢ⁻ʳ[n,24] == 0)
        @constraint(linear, KKT_EV_λ¹⁰_r[n=1:N,t=1:T], - p[n,t,10] + ev⁺⁻ʳ[n,t]/η - η*ev⁻⁻ʳ[n,t] == 0)
        @constraint(linear, KKT_EV_λ¹¹_r[n=1:N,t=2:T], s⁻ʳ[n,t-1] - s⁻ʳ[n,t] + ev⁺⁻ʳ[n,t] - ev⁻⁻ʳ[n,t] - Pᵈ*(1-Uᴱⱽ[3,t])== 0)
        @constraint(linear, KKT_EV_λ¹¹_1_r[n=1:N], S⁰ - s⁻ʳ[n,1] + ev⁺⁻ʳ[n,1] - ev⁻⁻ʳ[n,1] - Pᵈ*(1-Uᴱⱽ[3,1])== 0)
        @constraint(linear, KKT_EV_λ¹²_r[n=1:N], s⁻ʳ[n,24] == S⁰)
        @constraint(linear, KKT_EV_μ̲ᵉᵛ⁺_r[n=1:N,t=1:T], ev⁺⁻ʳ[n,t] >= E̲V̲)
        @constraint(linear, KKT_EV_μ̅ᵉᵛ⁺_r[n=1:N,t=1:T], ev⁺⁻ʳ[n,t] <= E̅V̅)
        @constraint(linear, KKT_EV_μ̲ᵉᵛ⁻_r[n=1:N,t=1:T], ev⁻⁻ʳ[n,t] >= E̲V̲)
        @constraint(linear, KKT_EV_μ̅ᵉᵛ⁻_r[n=1:N,t=1:T], ev⁻⁻ʳ[n,t] <= E̅V̅)
        @constraint(linear, KKT_EV_μ̲ˢ_r[n=1:N,t=1:T], s⁻ʳ[n,t] >= S̲)
        @constraint(linear, KKT_EV_μ̅ˢ_r[n=1:N,t=1:T], s⁻ʳ[n,t] <= S̅)
        #complementarities
        @constraint(linear, complementarity_μ̲ᵉᵛ⁺_r[n=1:N,t=1:T], μ̲ᵉᵛ⁺⁻ʳ[n,t] <= u̲ᵉᵛ⁺⁻ʳ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev⁺_min_r[n=1:N,t=1:T], ev⁺⁻ʳ[n,t] - E̲V̲ <= (1-u̲ᵉᵛ⁺⁻ʳ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̅ᵉᵛ⁺_r[n=1:N,t=1:T], μ̅ᵉᵛ⁺⁻ʳ[n,t] <= u̅ᵉᵛ⁺⁻ʳ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev⁺_max_r[n=1:N,t=1:T], E̅V̅ - ev⁺⁻ʳ[n,t] <= (1-u̅ᵉᵛ⁺⁻ʳ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̲ᵉᵛ⁻_r[n=1:N,t=1:T], μ̲ᵉᵛ⁻⁻ʳ[n,t] <= u̲ᵉᵛ⁻⁻ʳ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev⁻_min_r[n=1:N,t=1:T], ev⁻⁻ʳ[n,t] - E̲V̲ <= (1-u̲ᵉᵛ⁻⁻ʳ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̅ᵉᵛ⁻_r[n=1:N,t=1:T], μ̅ᵉᵛ⁻⁻ʳ[n,t] <= u̅ᵉᵛ⁻⁻ʳ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_ev⁻_max_r[n=1:N,t=1:T], E̅V̅ - ev⁻⁻ʳ[n,t] <= (1-u̅ᵉᵛ⁻⁻ʳ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̲ˢ_r[n=1:N,t=1:T], μ̲ˢ⁻ʳ[n,t] <= u̲ˢ⁻ʳ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_s_min_r[n=1:N,t=1:T], s⁻ʳ[n,t] - S̲ <= (1-u̲ˢ⁻ʳ[n,t])*Mᴱⱽ)
        @constraint(linear, complementarity_μ̅ˢ_r[n=1:N,t=1:T], μ̅ˢ⁻ʳ[n,t] <= u̅ˢ⁻ʳ[n,t]*Mᴱⱽ)
        @constraint(linear, complementarity_s_max_r[n=1:N,t=1:T], S̅ - s⁻ʳ[n,t] <= (1-u̅ˢ⁻ʳ[n,t])*Mᴱⱽ)
    end
    =#
    return linear, value.(p), τᵉⁿᵈ
end

function nonlinear_pricing(theta_sample, T, N, K, L, PV, DA_prices, P̄ᴰˢᴼ,Cᵉˣᵗ,warm_start)
    ### --- Model definition --- ###
    nonlinear = Model(Ipopt.Optimizer)
    set_silent(nonlinear)

    ##########################
    ### --- PARAMETERS --- ###
    ##########################

    ### --- Capacity Limitation Parameters --- ###
    α = 50      #penalty
    βᴰˢᴼ = 0.5  #discount rate
    τⁱᵐ = 2     #import tariff
    τᵉˣ = 1     #export tariff

    ### --- Individual Consumer Parameters --- ###
    T_morning = 6:9
    T_day = 10:16
    T_evening = 17:22

    ### --- Battery Parameters --- ###
    E̲ = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]    #Lower limit for state of energy
    E̅ = [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]    #Upper limit for state of energy
    B̲ = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]    #Lower limit for charging and discharging power
    B̅ = E̅./2                                    #Upper limit for charging and discharging power
    η = 0.95                                    #Charging and discharging efficiency of the battery
    
    ###############################
    ###### --- VARIABLES --- ######
    ###############################

    ### --- Upper Level Variables --- ###
    @variable(nonlinear, 0 <= x[1:N,1:T] <= maximum(DA_prices)+τⁱᵐ)    #Individual Dynamic Price
    @variable(nonlinear, y[1:N,1:T])                                   #Response
    @variable(nonlinear, y⁺[1:N,1:T] >= 0)                             #Auxiliary variable for internal power calculation
    @variable(nonlinear, pⁱᵐ[1:T] >= 0)                                #Imported Community Power
    @variable(nonlinear, pᵉˣ[1:T] >= 0)                                #Exported Community Power
    @variable(nonlinear, pᵖᵉⁿ[1:T] >= 0)                               #Penalized Power
    #Warm starting upper level variables
    for t = 1:T
        set_start_value(pⁱᵐ[t],value(warm_start[:pⁱᵐ][t]))
        set_start_value(pᵉˣ[t],value(warm_start[:pᵉˣ][t]))
        set_start_value(pᵖᵉⁿ[t],value(warm_start[:pᵖᵉⁿ][t]))
        for n = 1:N
            set_start_value(x[n,t],value(warm_start[:x][n,t]))
            set_start_value(y[n,t],value(warm_start[:y][n,t]))
            set_start_value(y⁺[n,t],value(warm_start[:y⁺][n,t]))
        end
    end

    ### --- Lower Level Variables --- ###
    #Only variable that exists for all signatures
    @variable(nonlinear, p[1:N,1:T,1:K])                               #power from grid for consumer n at time t
    for n=1:N
        for t=1:T
            for k=1:K
                set_start_value(p[n,t,k], value(warm_start[:p][n,t,k]))
            end
        end
    end

    if K >= 1
        ### Signature 1 ###
        @variable(nonlinear, l⁻¹[1:N,1:T])                                 #load for consumer n
        @variable(nonlinear, μ̲ˡ⁻¹[1:N,1:T] >= 0)                           #dual variable for minimum load inequality
        @variable(nonlinear, μ̅ˡ⁻¹[1:N,1:T] >= 0)                           #dual variable for maximum load inequality
        @variable(nonlinear, λ¹⁻¹[1:N,1:T])                                #Dual for power balance in signature 1
        @variable(nonlinear, λ²⁻¹[1:N,setdiff(1:T,T_morning)])             #Dual for load matching in signature 1
        @variable(nonlinear, λ³⁻¹[1:N])                                    #Dual for load flexibility in signature 1
        #Warm starting variables
        for n = 1:N
            set_start_value(λ³⁻¹[n],value(warm_start[:λ³⁻¹][n]))
            for t = 1:T
                set_start_value(l⁻¹[n,t],value(warm_start[:l⁻¹][n,t]))
                set_start_value(μ̲ˡ⁻¹[n,t],value(warm_start[:μ̲ˡ⁻¹][n,t]))
                set_start_value(μ̅ˡ⁻¹[n,t],value(warm_start[:μ̅ˡ⁻¹][n,t]))
                set_start_value(λ¹⁻¹[n,t],value(warm_start[:λ¹⁻¹][n,t]))
                if t in setdiff(1:T,T_morning)
                    set_start_value(λ²⁻¹[n,t],value(warm_start[:λ²⁻¹][n,t]))
                end
            end
        end
    end
    if K >= 2
        ### Signature 2 ###
        @variable(nonlinear, l⁻²[1:N,1:T])                                 #load for consumer n
        @variable(nonlinear, μ̲ˡ⁻²[1:N,1:T] >= 0)                           #dual variable for minimum load inequality
        @variable(nonlinear, μ̅ˡ⁻²[1:N,1:T] >= 0)                           #dual variable for maximum load inequality
        @variable(nonlinear, λ¹⁻²[1:N,1:T])                                #Dual for power balance in signature 2
        @variable(nonlinear, λ²⁻²[1:N,setdiff(1:T,T_day)])                 #Dual for load matching in signature 2
        @variable(nonlinear, λ³⁻²[1:N])                                    #Dual for load flexibility in signature 2
        #Warm starting variables
        for n = 1:N
            set_start_value(λ³⁻²[n],value(warm_start[:λ³⁻²][n]))
            for t = 1:T
                set_start_value(l⁻²[n,t],value(warm_start[:l⁻²][n,t]))
                set_start_value(μ̲ˡ⁻²[n,t],value(warm_start[:μ̲ˡ⁻²][n,t]))
                set_start_value(μ̅ˡ⁻²[n,t],value(warm_start[:μ̅ˡ⁻²][n,t]))
                set_start_value(λ¹⁻²[n,t],value(warm_start[:λ¹⁻²][n,t]))
                if t in setdiff(1:T,T_day)
                    set_start_value(λ²⁻²[n,t],value(warm_start[:λ²⁻²][n,t]))
                end
            end
        end
    end
    if K >= 3
        ### Signature 3 ###
        @variable(nonlinear, l⁻³[1:N,1:T])                                 #load for consumer n
        @variable(nonlinear, μ̲ˡ⁻³[1:N,1:T] >= 0)                           #dual variable for minimum load inequality
        @variable(nonlinear, μ̅ˡ⁻³[1:N,1:T] >= 0)                           #dual variable for maximum load inequality
        @variable(nonlinear, λ¹⁻³[1:N,1:T])                                #Dual for power balance in signature 3
        @variable(nonlinear, λ²⁻³[1:N,setdiff(1:T,T_evening)])             #Dual for load matching in signature 3
        @variable(nonlinear, λ³⁻³[1:N])                                    #Dual for load flexibility in signature 3
        #Warm starting variables
        for n = 1:N
            set_start_value(λ³⁻³[n],value(warm_start[:λ³⁻³][n]))
            for t = 1:T
                set_start_value(l⁻³[n,t],value(warm_start[:l⁻³][n,t]))
                set_start_value(μ̲ˡ⁻³[n,t],value(warm_start[:μ̲ˡ⁻³][n,t]))
                set_start_value(μ̅ˡ⁻³[n,t],value(warm_start[:μ̅ˡ⁻³][n,t]))
                set_start_value(λ¹⁻³[n,t],value(warm_start[:λ¹⁻³][n,t]))
                if t in setdiff(1:T,T_evening)
                    set_start_value(λ²⁻³[n,t],value(warm_start[:λ²⁻³][n,t]))
                end
            end
        end
    end
    if K >= 4
        ### Signature 4 ###
        @variable(nonlinear, l⁻⁴[1:N,1:T])                                 #load for consumer n
        @variable(nonlinear, μ̲ˡ⁻⁴[1:N,1:T] >= 0)                           #dual variable for minimum load inequality
        @variable(nonlinear, μ̅ˡ⁻⁴[1:N,1:T] >= 0)                           #dual variable for maximum load inequality
        @variable(nonlinear, λ⁴[1:N,1:T])                                  #dual variable for power balance in signature 4
        @variable(nonlinear, λ⁵[1:N])                                      #dual variable for load flexibility in signature 4
        #Warm starting variables
        for n = 1:N
            set_start_value(λ⁵[n],value(warm_start[:λ⁵][n]))
            for t = 1:T
                set_start_value(l⁻⁴[n,t],value(warm_start[:l⁻⁴][n,t]))
                set_start_value(μ̲ˡ⁻⁴[n,t],value(warm_start[:μ̲ˡ⁻⁴][n,t]))
                set_start_value(μ̅ˡ⁻⁴[n,t],value(warm_start[:μ̅ˡ⁻⁴][n,t]))
                set_start_value(λ⁴[n,t],value(warm_start[:λ⁴][n,t]))
            end
        end
    end
    if K >= 5
        ### Signature 5 ###
        @variable(nonlinear, b⁺[1:N,1:T])                                 #battery charging power [kW]
        @variable(nonlinear, b⁻[1:N,1:T])                                 #battery discharging power [kW]
        @variable(nonlinear, e[1:N,1:T])                                  #state of energy of the battery [kWh]
        @variable(nonlinear, λ⁴[1:N,1:T])                                 #dual of the power balance equation
        @variable(nonlinear, λ⁷[1:N,2:T])                                 #dual of the battery balance constraint
        @variable(nonlinear, λ⁶[1:N])                                     #dual of the initial and final battery balance
        @variable(nonlinear, μ̲ᵇ⁺[1:N,1:T] >= 0)                           #dual of the lower limit of charging power
        @variable(nonlinear, μ̅ᵇ⁺[1:N,1:T] >= 0)                           #dual of the upper limit of charging power
        @variable(nonlinear, μ̲ᵇ⁻[1:N,1:T] >= 0)                           #dual of the lower limit of discharging power
        @variable(nonlinear, μ̅ᵇ⁻[1:N,1:T] >= 0)                           #dual of the upper limit of discharging power
        @variable(nonlinear, μ̲ᵉ[1:N,1:T] >= 0)                            #dual of the lower limit of state of energy
        @variable(nonlinear, μ̅ᵉ[1:N,1:T] >= 0)                            #dual of the upper limit of state of energy
        for n = 1:N
            set_start_value(λ⁸[n],value(warm_start[:λ⁸][n]))
            for t = 1:T
                set_start_value(b⁺[n,t],value(warm_start[:b⁺][n,t]))
                set_start_value(b⁻[n,t],value(warm_start[:b⁻][n,t]))
                set_start_value(e[n,t],value(warm_start[:e][n,t]))
                set_start_value(λ⁴[n,t],value(warm_start[:λ⁶][n,t]))
                set_start_value(μ̲ᵇ⁺[n,t],value(warm_start[:μ̲ᵇ⁺][n,t]))
                set_start_value(μ̅ᵇ⁺[n,t],value(warm_start[:μ̅ᵇ⁺][n,t]))
                set_start_value(μ̲ᵇ⁻[n,t],value(warm_start[:μ̲ᵇ⁻][n,t]))
                set_start_value(μ̅ᵇ⁻[n,t],value(warm_start[:μ̅ᵇ⁻][n,t]))
                set_start_value(μ̲ᵉ[n,t],value(warm_start[:μ̲ᵉ][n,t]))
                set_start_value(μ̅ᵉ[n,t],value(warm_start[:μ̅ᵉ][n,t]))
                if t > 1
                    set_start_value(λ⁷[n,t],value(warm_start[:λ⁷][n,t]))
                end
            end
        end
    end

    #################################
    ########## CONSTRAINTS ##########
    #################################

    ### --- Upper Level Constraints --- ###
    @constraint(nonlinear, response[n = 1:N], y[n,:] == p[n,:,:]*theta_sample[n,:])                       #Response prediction constraint using theta sample
    @constraint(nonlinear, community_balance[t = 1:T], pⁱᵐ[t] - pᵉˣ[t] == sum(y[n,t] for n in 1:N))       #Power balance of the energy community
    @constraint(nonlinear, penalty[t = 1:T], pᵖᵉⁿ[t] >= pⁱᵐ[t] - P̄ᴰˢᴼ[t])                                 #Calculating penalized power for exceeding the DSO limitation
    @constraint(nonlinear, auxiliary[n=1:N,t=1:T], y⁺[n,t] >= y[n,t])                                     #Calculation of the power flowing within the community

    #Individual individual_rationality
    if K == 3
        @constraint(nonlinear, individual_rationality[n=1:N], theta_sample[n,1]*sum(p[n,t,1]*x[n,t] for t in 1:T) 
                                                            + theta_sample[n,2]*sum(p[n,t,2]*x[n,t] for t in 1:T) 
                                                            + theta_sample[n,3]*sum(p[n,t,3]*x[n,t] for t in 1:T)
                                                            <= Cᵉˣᵗ[n])

        @constraint(nonlinear, revenue_adequacy, sum(theta_sample[n,1]*sum(p[n,t,1]*x[n,t] for t in 1:T) 
                                                + theta_sample[n,2]*sum(p[n,t,2]*x[n,t] for t in 1:T) 
                                                + theta_sample[n,3]*sum(p[n,t,3]*x[n,t] for t in 1:T) for n in 1:N) 
                                                >= 3000)

    elseif K == 4
        @constraint(nonlinear, individual_rationality[n=1:N], theta_sample[n,1]*sum(p[n,t,1]*x[n,t] for t in 1:T) 
                                                            + theta_sample[n,2]*sum(p[n,t,2]*x[n,t] for t in 1:T) 
                                                            + theta_sample[n,3]*sum(p[n,t,3]*x[n,t] for t in 1:T) 
                                                            + theta_sample[n,4]*sum(p[n,t,4]*x[n,t] for t in 1:T)
                                                            <= Cᵉˣᵗ[n])

        @constraint(nonlinear, revenue_adequacy, sum(theta_sample[n,1]*sum(p[n,t,1]*x[n,t] for t in 1:T) 
                                                + theta_sample[n,2]*sum(p[n,t,2]*x[n,t] for t in 1:T) 
                                                + theta_sample[n,3]*sum(p[n,t,3]*x[n,t] for t in 1:T) 
                                                + theta_sample[n,4]*sum(p[n,t,4]*x[n,t] for t in 1:T) for n in 1:N) 
                                                >= 3000)

    elseif K == 5
        @constraint(nonlinear, individual_rationality[n=1:N], theta_sample[n,1]*sum(p[n,t,1]*x[n,t] for t in 1:T) 
                                                            + theta_sample[n,2]*sum(p[n,t,2]*x[n,t] for t in 1:T) 
                                                            + theta_sample[n,3]*sum(p[n,t,3]*x[n,t] for t in 1:T) 
                                                            + theta_sample[n,4]*sum(p[n,t,4]*x[n,t] for t in 1:T) 
                                                            + theta_sample[n,5]*sum(p[n,t,5]*x[n,t] for t in 1:T)
                                                            <= Cᵉˣᵗ[n])

        @constraint(nonlinear, revenue_adequacy, sum(theta_sample[n,1]*sum(p[n,t,1]*x[n,t] for t in 1:T) 
                                                + theta_sample[n,2]*sum(p[n,t,2]*x[n,t] for t in 1:T) 
                                                + theta_sample[n,3]*sum(p[n,t,3]*x[n,t] for t in 1:T) 
                                                + theta_sample[n,4]*sum(p[n,t,4]*x[n,t] for t in 1:T) 
                                                + theta_sample[n,5]*sum(p[n,t,5]*x[n,t] for t in 1:T) for n in 1:N) 
                                                >= 3000)
    end

    ### --- Lower Level Constraints --- ###
    if K >= 1
        ### Signature 1 ###
        @constraint(nonlinear, KKT_flex_p_1[t=1:T,n=1:N], x[n,t] - λ¹⁻¹[n,t] == 0)                                                         #KKT for p in signature 1
        @constraint(nonlinear, KKT_flex_l_1nonflex[t=setdiff(1:T,T_morning),n=1:N], λ¹⁻¹[n,t] + λ²⁻¹[n,t] - μ̲ˡ⁻¹[n,t] + μ̅ˡ⁻¹[n,t] == 0)    #KKT for l in nonflexible hours in signature 1
        @constraint(nonlinear, KKT_flex_l_1flex[t=T_morning,n=1:N], λ¹⁻¹[n,t] + λ³⁻¹[n] - μ̲ˡ⁻¹[n,t] + μ̅ˡ⁻¹[n,t] == 0)                      #KKT for l in flexible hours in signature 1
        @constraint(nonlinear, KKT_flex_lambda1_1[t=1:T,n=1:N], -p[n,t,1] + l⁻¹[n,t] == 0)                                       #KKT for λ¹ in signature 1
        @constraint(nonlinear, KKT_flex_lambda2_1[t=setdiff(1:T,T_morning),n=1:N], l⁻¹[n,t] - L[n,t] == 0)                                 #KKT for λ² in signature 1
        @constraint(nonlinear, KKT_flex_lambda3_1[n=1:N], sum(l⁻¹[n,t] - L[n,t] for t = T_morning) == 0)                                   #KKT for λ³ in signature 1
        @constraint(nonlinear, KKT_flex_Lmin1[t=1:T,n=1:N], l⁻¹[n,t] >= minimum(L[n,:]))                                                  #Minimum load in signature 1
        @constraint(nonlinear, KKT_flex_Lmax1[t=1:T,n=1:N], l⁻¹[n,t] <= maximum(L[n,:]))                                                  #Maximum load in signature 1
        #Complementarities for signature 1
        @constraint(nonlinear, complementarity_μ̲ˡ_l_1[t=1:T,n=1:N], μ̲ˡ⁻¹[n,t]*(minimum(L[n,:]) - l⁻¹[n,t]) == 0)
        @constraint(nonlinear, complementarity_μ̅ˡ_l_1[t=1:T,n=1:N], μ̅ˡ⁻¹[n,t]*(l⁻¹[n,t] -maximum(L[n,:])) == 0)
    end
    if K >= 2
        ### Signature 2 ###
        @constraint(nonlinear, KKT_flex_p_2[t=1:T,n=1:N], x[n,t] - λ¹⁻²[n,t] == 0)                                                         
        @constraint(nonlinear, KKT_flex_l_2nonflex[t=setdiff(1:T,T_day),n=1:N], λ¹⁻²[n,t] + λ²⁻²[n,t] - μ̲ˡ⁻²[n,t] + μ̅ˡ⁻²[n,t] == 0)        
        @constraint(nonlinear, KKT_flex_l_2flex[t=T_day,n=1:N], λ¹⁻²[n,t] + λ³⁻²[n] - μ̲ˡ⁻²[n,t] + μ̅ˡ⁻²[n,t] == 0)                         
        @constraint(nonlinear, KKT_flex_lambda1_2[t=1:T,n=1:N], -p[n,t,2] + l⁻²[n,t] == 0)
        @constraint(nonlinear, KKT_flex_lambda2_2[t=setdiff(1:T,T_day),n=1:N], l⁻²[n,t] - L[n,t] == 0)
        @constraint(nonlinear, KKT_flex_lambda3_2[n=1:N], sum(l⁻²[n,t] - L[n,t] for t = T_day) == 0)
        @constraint(nonlinear, KKT_flex_Lmin_2[t=1:T,n=1:N], l⁻²[n,t] >= minimum(L[n,:]))                                                  #Minimum load 
        @constraint(nonlinear, KKT_flex_Lmax_2[t=1:T,n=1:N], l⁻²[n,t] <= maximum(L[n,:]))                                                  #Maximum load
        #Complementarities for signature 2
        @constraint(nonlinear, complementarity_μ̲ˡ_l_2[t=1:T,n=1:N], μ̲ˡ⁻²[n,t]*(minimum(L[n,:]) - l⁻²[n,t]) == 0)
        @constraint(nonlinear, complementarity_μ̅ˡ_l_2[t=1:T,n=1:N], μ̅ˡ⁻²[n,t]*(l⁻²[n,t] -maximum(L[n,:])) == 0)
    end
    if K >= 3
        #Signature 3
        @constraint(nonlinear, KKT_flex_p_3[t=1:T,n=1:N], x[n,t] - λ¹⁻³[n,t] == 0)
        @constraint(nonlinear, KKT_flex_l_3nonflex[t=setdiff(1:T,T_evening),n=1:N], λ¹⁻³[n,t] + λ²⁻³[n,t] - μ̲ˡ⁻³[n,t] + μ̅ˡ⁻³[n,t] == 0)
        @constraint(nonlinear, KKT_flex_l_3flex[t=T_evening,n=1:N], λ¹⁻³[n,t] + λ³⁻³[n] - μ̲ˡ⁻³[n,t] + μ̅ˡ⁻³[n,t] == 0)
        @constraint(nonlinear, KKT_flex_lambda1_3[t=1:T,n=1:N], -p[n,t,3] + l⁻³[n,t] == 0)
        @constraint(nonlinear, KKT_flex_lambda2_3[t=setdiff(1:T,T_evening),n=1:N], l⁻³[n,t] - L[n,t] == 0)
        @constraint(nonlinear, KKT_flex_lambda3_3[n=1:N], sum(l⁻³[n,t] - L[n,t] for t = T_evening) == 0)
        @constraint(nonlinear, KKT_flex_Lmin_3[t=1:T,n=1:N], l⁻³[n,t] >= minimum(L[n,:]))     #Minimum load 
        @constraint(nonlinear, KKT_flex_Lmax_3[t=1:T,n=1:N], l⁻³[n,t] <= maximum(L[n,:]))     #Maximum load
        #Complementarities for signature 3
        @constraint(nonlinear, complementarity_μ̲ˡ_l_3[t=1:T,n=1:N], μ̲ˡ⁻³[n,t]*(minimum(L[n,:]) - l⁻³[n,t]) == 0)
        @constraint(nonlinear, complementarity_μ̅ˡ_l_3[t=1:T,n=1:N], μ̅ˡ⁻³[n,t]*(l⁻³[n,t] -maximum(L[n,:])) == 0)
    end
    if K >= 4
        #Signature 4
        @constraint(nonlinear, KKT_stubborn_p_4[n=1:N,t=1:T], x[n,t] - λ⁴[n,t] == 0)
        @constraint(nonlinear, KKT_stubborn_l_4[n=1:N,t=1:T], λ⁴[n,t] + λ⁵[n] - μ̲ˡ⁻⁴[n,t] + μ̅ˡ⁻⁴[n,t] == 0)
        @constraint(nonlinear, KKT_stubborn_λ⁴_4[n=1:N,t=1:T], -p[n,t,4] - PV[t] + l⁻⁴[n,t] == 0)
        @constraint(nonlinear, KKT_stubborn_λ⁵_4[n=1:N], sum(l⁻⁴[n,t] - L[n,t] for t=1:T) == 0)
        @constraint(nonlinear, KKT_flex_Lmin_4[t=1:T,n=1:N], l⁻⁴[n,t] >= minimum(L[n,:]))     #Minimum load 
        @constraint(nonlinear, KKT_flex_Lmax_4[t=1:T,n=1:N], l⁻⁴[n,t] <= maximum(L[n,:]))     #Maximum load
        #Complementarities for signature 4
        @constraint(nonlinear, complementarity_μ̲ˡ_l_4[t=1:T,n=1:N], μ̲ˡ⁻⁴[n,t]*(minimum(L[n,:]) - l⁻⁴[n,t]) == 0)
        @constraint(nonlinear, complementarity_μ̅ˡ_l_4[t=1:T,n=1:N], μ̅ˡ⁻⁴[n,t]*(l⁻⁴[n,t] - maximum(L[n,:])) == 0)
    end
    if K >= 5
        #Signature 5
        @constraint(nonlinear, KKT_battery_p[n=1:N,t=1:T], x[n,t] - λ⁶[n,t] == 0)
        @constraint(nonlinear, KKT_battery_b⁺_1[n=1:N,t=[1]], + λ⁶[n,t]/η + λ⁸[n]  - μ̲ᵇ⁺[n,t] + μ̅ᵇ⁺[n,t] == 0)
        @constraint(nonlinear, KKT_battery_b⁺[n=1:N,t=2:T], + λ⁶[n,t]/η + λ⁷[n,t] - μ̲ᵇ⁺[n,t] + μ̅ᵇ⁺[n,t] == 0)
        @constraint(nonlinear, KKT_battery_b⁻_1[n=1:N,t=[1]], - λ⁶[n,t]*η - λ⁸[n] - μ̲ᵇ⁻[n,t] + μ̅ᵇ⁻[n,t] == 0)
        @constraint(nonlinear, KKT_battery_b⁻[n=1:N,t=2:T], - λ⁶[n,t]*η - λ⁷[n,t]  - μ̲ᵇ⁻[n,t] + μ̅ᵇ⁻[n,t] == 0)
        @constraint(nonlinear, KKT_battery_e_1[n=1:N,t=[1]],  - λ⁸[n] + λ⁷[n,t+1] - μ̲ᵉ[n,t] + μ̅ᵉ[n,t] == 0)
        @constraint(nonlinear, KKT_battery_e[n=1:N,t=2:T-1], - λ⁷[n,t] + λ⁷[n,t+1] - μ̲ᵉ[n,t] + μ̅ᵉ[n,t] == 0)
        @constraint(nonlinear, KKT_battery_e_24[n=1:N,t=[T]], - λ⁷[n,t] + λ⁸[n] - μ̲ᵉ[n,t] + μ̅ᵉ[n,t] == 0)
        @constraint(nonlinear, KKT_battery_λ⁶[n=1:N,t=1:T], - p[n,t,5] - PV[t] + L[n,t] + b⁺[n,t]/η - η*b⁻[n,t] == 0)
        @constraint(nonlinear, KKT_battery_λ⁷[n=1:N,t=2:T], e[n,t-1] - e[n,t] + b⁺[n,t] - b⁻[n,t] == 0)
        @constraint(nonlinear, KKT_battery_λ⁸[n=1:N,t=[1]], e[n,T] - e[n,t] + b⁺[n,t] - b⁻[n,t] == 0)
        @constraint(nonlinear, KKT_battery_b⁺_min[t=1:T,n=1:N], b⁺[n,t] >= B̲[n])
        @constraint(nonlinear, KKT_battery_b⁺_max[t=1:T,n=1:N], b⁺[n,t] <= B̅[n])
        @constraint(nonlinear, KKT_battery_b⁻_min[t=1:T,n=1:N], b⁻[n,t] >= B̲[n])
        @constraint(nonlinear, KKT_battery_b⁻_max[t=1:T,n=1:N], b⁻[n,t] <= B̅[n])
        @constraint(nonlinear, KKT_battery_e_min[t=1:T,n=1:N], e[n,t] >= E̲[n])
        @constraint(nonlinear, KKT_battery_e_max[t=1:T,n=1:N], e[n,t] <= E̅[n])
        #Complementarities charging
        @constraint(nonlinear, complementarity_μ̲ᵇ⁺_b⁺[t=1:T,n=1:N], μ̲ᵇ⁺[n,t]*(B̲[n] - b⁺[n,t]) == 0)
        @constraint(nonlinear, complementarity_μ̅ᵇ⁺_b⁺[t=1:T,n=1:N], μ̅ᵇ⁺[n,t]*(b⁺[n,t] - B̅[n]) == 0)
        #Complementarities discharging
        @constraint(nonlinear, complementarity_μ̲ᵇ⁻_b⁻[t=1:T,n=1:N], μ̲ᵇ⁻[n,t]*(B̲[n] - b⁻[n,t]) == 0)
        @constraint(nonlinear, complementarity_μ̅ᵇ⁻_b⁻[t=1:T,n=1:N], μ̅ᵇ⁻[n,t]*(b⁻[n,t] - B̅[n]) == 0)
        #Complementarities state of energy
        @constraint(nonlinear, complementarity_μ̲ᵉ_e[t=1:T,n=1:N], μ̲ᵉ[n,t]*(E̲[n] - e[n,t]) == 0)
        @constraint(nonlinear, complementarity_μ̅ᵉ_e[t=1:T,n=1:N], μ̅ᵉ[n,t]*(e[n,t] - E̅[n]) == 0)
    end

    ##################################
    ### --- OBJECTIVE FUNCTION --- ###
    ##################################

    ### --- Capacity Limitation Objective Function --- ###
    @objective(nonlinear,Min, sum(pⁱᵐ[t]*(DA_prices[t] .+ τⁱᵐ) - pᵉˣ[t]*(DA_prices[t] .- τᵉˣ) + (1-βᴰˢᴼ)*τⁱᵐ*(sum(y⁺[n,t] for n in 1:N)-pⁱᵐ[t]) + α*pᵖᵉⁿ[t] for t in 1:T))

    ####################################
    ### --- SOLVING AND PRINTING --- ###
    ####################################

    println("Running nonlinear model...")
    optimize!(nonlinear)

    println("Solve Time: ", solve_time(nonlinear))
    println("Termination Status: ", termination_status(nonlinear))

    return nonlinear, value.(p), termination_status(nonlinear), solve_time(nonlinear)
end

function pricing(theta_sample, T, N, K, L, PV, DA_prices, P̄ᴰˢᴼ,Cᵉˣᵗ, type)
    ### Pricing Problem ###
    #Time sets
    T_morning = 6:9
    T_day = 10:16
    T_evening = 17:22

    #Capacity Limitation parameters
    α = 50
    βᴰˢᴼ = 0.5
    τⁱᵐ = 2
    τᵉˣ = 1

    #Participant and Signature
    if type == "NL"
        bilevel = Model(Ipopt.Optimizer)
        #set_silent(bilevel)
        set_optimizer_attribute(bilevel, "max_iter", 10000)
    elseif type == "Linear"
        bilevel = Model(Gurobi.Optimizer)#() -> Gurobi.Optimizer(GRB_ENV))
        set_silent(linear)
        set_optimizer_attribute(bilevel, "MIPGap", 1e-4)
        set_time_limit_sec(bilevel, 100.0)
    end
    
    #Upper Level Variables
    @variable(bilevel, 0 <= x[1:N,1:T] <= maximum(DA_prices)+τⁱᵐ)     #Individual Dynamic Price
    @variable(bilevel, y[1:N,1:T])          #Response
    @variable(bilevel, y⁺[1:N,1:T] >= 0)    #Auxiliary variable for internal power calculation
    @variable(bilevel, pⁱᵐ[1:T] >= 0)       #Imported Community Power
    @variable(bilevel, pᵉˣ[1:T] >= 0)       #Exported Community Power
    @variable(bilevel, pᵖᵉⁿ[1:T] >= 0)      #Penalized Power

    #Lower Level variable but needs to be included here as it is in the upper level constraints.
    @variable(bilevel, p[1:N,1:T,1:K])      #Individual power from/to grid

    #Upper Level Constraints
    @constraint(bilevel, response[n = 1:N], y[n,:] == p[n,:,:]*theta_sample[n,:])
    @constraint(bilevel, community_balance[t = 1:T], pⁱᵐ[t] - pᵉˣ[t] == sum(y[n,t] for n in 1:N))
    @constraint(bilevel, penalty[t = 1:T], pᵖᵉⁿ[t] >= pⁱᵐ[t] - P̄ᴰˢᴼ[t])
    @constraint(bilevel, auxiliary[n=1:N,t=1:T], y⁺[n,t] >= y[n,t])

    if type == "NL"
        #Non-linear equality
        @constraint(bilevel, NL_price_uniqueness[n=1:N,t=1:T,t_prime = 1:T; t_prime > t], (x[n,t] - x[n,t_prime])*(x[n,t_prime]-x[n,t]) <= 0.1)

    elseif type == "Linear"
        #Price inequality for unique solution
        #@constraint(bilevel,unique_price[n=1:N,t=1:T,h=1:T; h > t], (DA_prices[t] - DA_prices[h])*(x[n,t] - x[n,h]) >= 0.01)

        #Binary formulation for different prices
        #γ = 0.1
        #Mˣ = 50
        #@variable(bilevel, ω[1:N,1:T,1:T], Bin)
        #@constraint(bilevel, unique_price1[n=1:N,t=1:T,h=1:T;h>t], x[n,t] - x[n,h] <= -γ + Mˣ*ω[n,t,h])
        #@constraint(bilevel, unique_price2[n=1:N,t=1:T,h=1:T;h>t], x[n,t] - x[n,h] >= γ - Mˣ*(1-ω[n,t,h]))

        #maximizing difference between prices
        @variable(bilevel, ρ[1:N])
        @variable(bilevel, ω[1:N])
        @variable(bilevel, u[1:N], Bin)
        @variable(bilevel, z[1:N], Bin)
        @variable(bilevel, Γ[1:N])
        @variable(bilevel, ϕ[1:N])
        @variable(bilevel, ψ[1:N])

        @constraint(bilevel, rho[n=1:N,t=1:T,t_prime=1:T;t_prime>t], x[n,t] - x[n,t_prime] >= ρ[n])
        @constraint(bilevel, omega[n=1:N,t=1:T,t_prime=1:T;t_prime<t], x[n,t_prime] - x[n,t] >= ω[n])

        Mˣ = 50
        @constraint(bilevel, gamma[n=1:N], Γ[n] <= ϕ[n] + ψ[n])

        @constraint(bilevel, phi_min[n=1:N], -u[n]*Mˣ <= ϕ[n])
        @constraint(bilevel, phi_max[n=1:N], ϕ[n] <= u[n]*Mˣ)
        @constraint(bilevel, phi_rho_max[n=1:N], -Mˣ*(1-u[n]) <= ϕ[n] - ρ[n])
        @constraint(bilevel, phi_rho_min[n=1:N], ϕ[n] - ρ[n] <= Mˣ*(1-u[n]))

        @constraint(bilevel, psi_min[n=1:N], -z[n]*Mˣ <= ψ[n])
        @constraint(bilevel, psi_max[n=1:N], ψ[n] <= z[n]*Mˣ)
        @constraint(bilevel, psi_omega_max[n=1:N], -Mˣ*(1-z[n]) <= ψ[n] - ω[n])
        @constraint(bilevel, psi_omega_min[n=1:N], ψ[n] - ω[n] <= Mˣ*(1-z[n]))
        #=
        for n =1:N
            fix(u[n],1)
        end
        =#

    end

    ###########################
    ### --- LOWER LEVEL --- ###
    ###########################
    #Lower Level Variables for signatures 1:4
    @variable(bilevel, l[1:N,1:T,1:4]) #demand load
    @constraint(bilevel, KKT_flex_Lmin[k=1:4,t=1:T,n=1:N], l[n,t,k] >= minimum(L[n,:]))
    @constraint(bilevel, KKT_flex_Lmax[k=1:4,t=1:T,n=1:N], l[n,t,k] <= maximum(L[n,:]))

    #Lower Level Dual Variables for all prosumers
    @variable(bilevel, μ̲ˡ[1:N,1:T,1:4] >= 0) #dual min load
    @variable(bilevel, μ̅ˡ[1:N,1:T,1:4] >= 0) #dual max load
    
    if type == "Linear"
        ### COMMENTED OUT TO TRY IPOPT AND THIS SOLVER DOES NOT WORK WITH BINARIES ###
        Mˡ = 1e3 #Big M value for load complementarities

        #Big-M for all load complementarities
        @variable(bilevel, u̲ˡ[1:N,1:T,1:4], Bin)
        @constraint(bilevel, compl_μ̲ˡ_l[k=1:4,t=1:T,n=1:N], μ̲ˡ[n,t,k] <= u̲ˡ[n,t,k]*Mˡ)
        @constraint(bilevel, compl_l_μ̲ˡ[k=1:4,t=1:T,n=1:N], l[n,t,k] - minimum(L[n,:]) <= (1-u̲ˡ[n,t,k])*Mˡ)

        @variable(bilevel, u̅ˡ[1:N,1:T,1:4], Bin)
        @constraint(bilevel, compl_μ̅ˡ_l[k=1:4,t=1:T,n=1:N], μ̅ˡ[n,t,k] <= u̅ˡ[n,t,k]*Mˡ)
        @constraint(bilevel, compl_l_μ̅ˡ[k=1:4,t=1:T,n=1:N], maximum(L[n,:]) - l[n,t,k] <= (1-u̅ˡ[n,t,k])*Mˡ)
    end
    
    ### --- Flexible Hour Dual Variables and KKTs --- ###
    @variable(bilevel,λ¹[1:N,1:T,1:3])
    @variable(bilevel,λ²⁻¹[1:N,setdiff(1:T,T_morning)])
    @variable(bilevel,λ²⁻²[1:N,setdiff(1:T,T_day)])
    @variable(bilevel,λ²⁻³[1:N,setdiff(1:T,T_evening)])
    @variable(bilevel,λ³[1:N,1:3])

    @constraint(bilevel, KKT_flex_p[k=1:3,t=1:T,n=1:N], x[n,t] #=+ 2*β*p[n,t,k]=# - λ¹[n,t,k] == 0)
    @constraint(bilevel, KKT_flex_l_1nonflex[t=setdiff(1:T,T_morning),n=1:N], λ¹[n,t,1] + λ²⁻¹[n,t] - μ̲ˡ[n,t,1] + μ̅ˡ[n,t,1] == 0)
    @constraint(bilevel, KKT_flex_l_1flex[t=T_morning,n=1:N], λ¹[n,t,1] + λ³[n,1] - μ̲ˡ[n,t,1] + μ̅ˡ[n,t,1] == 0)
    @constraint(bilevel, KKT_flex_l_2nonflex[t=setdiff(1:T,T_day),n=1:N], λ¹[n,t,2] + λ²⁻²[n,t] - μ̲ˡ[n,t,2] + μ̅ˡ[n,t,2] == 0)
    @constraint(bilevel, KKT_flex_l_2flex[t=T_day,n=1:N], λ¹[n,t,2] + λ³[n,2] - μ̲ˡ[n,t,2] + μ̅ˡ[n,t,2] == 0)
    @constraint(bilevel, KKT_flex_l_3nonflex[t=setdiff(1:T,T_evening),n=1:N], λ¹[n,t,3] + λ²⁻³[n,t] - μ̲ˡ[n,t,3] + μ̅ˡ[n,t,3] == 0)
    @constraint(bilevel, KKT_flex_l_3flex[t=T_evening,n=1:N], λ¹[n,t,3] + λ³[n,3] - μ̲ˡ[n,t,3] + μ̅ˡ[n,t,3] == 0)
    @constraint(bilevel, KKT_flex_lambda1[k=1:3,t=1:T,n=1:N], -p[n,t,k] - PV[n,t] + l[n,t,k] == 0)
    @constraint(bilevel, KKT_flex_lambda2_1[t=setdiff(1:T,T_morning),n=1:N], l[n,t,1] - L[n,t] == 0)
    @constraint(bilevel, KKT_flex_lambda2_2[t=setdiff(1:T,T_day),n=1:N], l[n,t,2] - L[n,t] == 0)
    @constraint(bilevel, KKT_flex_lambda2_3[t=setdiff(1:T,T_evening),n=1:N], l[n,t,3] - L[n,t] == 0)
    @constraint(bilevel, KKT_flex_lambda3_1[n=1:N], sum(l[n,t,1] - L[n,t] for t = T_morning) == 0)
    @constraint(bilevel, KKT_flex_lambda3_2[n=1:N], sum(l[n,t,2] - L[n,t] for t = T_day) == 0)
    @constraint(bilevel, KKT_flex_lambda3_3[n=1:N], sum(l[n,t,3] - L[n,t] for t = T_evening) == 0)

    if type == "NL"
        #Strong duality constraint for IPOPT
        @constraint(bilevel, strong_duality_k1[n=1:N, k=[1]], sum(x[n,t]*p[n,t,k] #=+ β*p[n,t,k]^2=# for t in 1:T) == sum(-λ¹[n,t,k]*PV[n,t] + μ̲ˡ[n,t,k]*minimum(L[n,:]) - μ̅ˡ[n,t,k]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³[n,k]*sum(L[n,t] for t in T_morning))
        @constraint(bilevel, strong_duality_k2[n=1:N, k=[2]], sum(x[n,t]*p[n,t,k] #=+ β*p[n,t,k]^2=# for t in 1:T) == sum(-λ¹[n,t,k]*PV[n,t] + μ̲ˡ[n,t,k]*minimum(L[n,:]) - μ̅ˡ[n,t,k]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³[n,k]*sum(L[n,t] for t in T_day))
        @constraint(bilevel, strong_duality_k3[n=1:N, k=[3]], sum(x[n,t]*p[n,t,k] #=+ β*p[n,t,k]^2=# for t in 1:T) == sum(-λ¹[n,t,k]*PV[n,t] + μ̲ˡ[n,t,k]*minimum(L[n,:]) - μ̅ˡ[n,t,k]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³[n,k]*sum(L[n,t] for t in T_evening))
    end

    if K >= 4
    ### --- Stubborn Consumer Dual Variables and KKTs --- ###
    
    #Variables
    @variable(bilevel, λ⁴[1:N,1:T,[4]])
    @variable(bilevel, λ⁵[1:N,[4]])

    @constraint(bilevel, KKT_stubborn_p[k=[4],n=1:N,t=1:T], x[n,t] - λ⁴[n,t,k] == 0)
    @constraint(bilevel, KKT_stubborn_l[k=[4],n=1:N,t=1:T], #=2*β*(l[n,t,k] - L[n,t]) +=# λ⁴[n,t,k] + λ⁵[n,k] - μ̲ˡ[n,t,k] + μ̅ˡ[n,t,k] == 0)
    @constraint(bilevel, KKT_stubborn_λ⁴[k=[4],n=1:N,t=1:T], -p[n,t,k] - PV[n,t] + l[n,t,k] == 0)
    @constraint(bilevel, KKT_stubborn_λ⁵[k=[4],n=1:N], sum(l[n,t,k] - L[n,t] for t=1:T) == 0)
    #constraints on max and min values of L are already enforced above.
        if type == "NL"
            @constraint(bilevel, strong_duality_k4[n=1:N, k=[4]], sum(x[n,t]*p[n,t,k] #=+ β*(L[n,t] - l[n,t,k])^2=# for t in 1:T) == sum(-λ⁴[n,t,k]*PV[n,t] + μ̲ˡ[n,t,k]*minimum(L[n,:]) - μ̅ˡ[n,t,k]*maximum(L[n,:]) for t in 1:T) - λ⁵[n,k]*sum(L[n,t] for t in 1:T))
        end
    end

    if K >= 5
        ### --- Battery Prosumer Variables and KKTs --- ###
        #Parameters
        E̲ = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        E̅ = [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]
        B̲ = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        B̅ = E̅./2
        η = 0.95

        #Variables
        @variable(bilevel, b⁺[1:N,1:T,[5]])
        @variable(bilevel, b⁻[1:N,1:T,[5]])
        @variable(bilevel, e[1:N,1:T,[5]] )
        @variable(bilevel, λ⁶[1:N,1:T,[5]])
        @variable(bilevel, λ⁷[1:N,2:T,[5]])
        @variable(bilevel, λ⁸[1:N,[5]])
        @variable(bilevel, μ̲ᵇ⁺[1:N,1:T,[5]] >= 0)
        @variable(bilevel, μ̅ᵇ⁺[1:N,1:T,[5]] >= 0)
        @variable(bilevel, μ̲ᵇ⁻[1:N,1:T,[5]] >= 0)
        @variable(bilevel, μ̅ᵇ⁻[1:N,1:T,[5]] >= 0)
        @variable(bilevel, μ̲ᵉ[1:N,1:T,[5]] >= 0)
        @variable(bilevel, μ̅ᵉ[1:N,1:T,[5]] >= 0)

        @constraint(bilevel, KKT_battery_p[n=1:N,t=1:T,k=[5]], x[n,t] - λ⁶[n,t,k] == 0)
        @constraint(bilevel, KKT_battery_b⁺_1[n=1:N,t=[1],k=[5]], #=2*β*b⁺[n,t,k]=# + λ⁶[n,t,k]/η + λ⁸[n,k]  - μ̲ᵇ⁺[n,t,k] + μ̅ᵇ⁺[n,t,k] == 0)
        @constraint(bilevel, KKT_battery_b⁺[n=1:N,t=2:T,k=[5]], #=2*β*b⁺[n,t,k]=# + λ⁶[n,t,k]/η + λ⁷[n,t,k] - μ̲ᵇ⁺[n,t,k] + μ̅ᵇ⁺[n,t,k] == 0)
        @constraint(bilevel, KKT_battery_b⁻_1[n=1:N,t=[1],k=[5]], #=2*β*b⁻[n,t,k]=# - λ⁶[n,t,k]*η - λ⁸[n,k] - μ̲ᵇ⁻[n,t,k] + μ̅ᵇ⁻[n,t,k] == 0)
        @constraint(bilevel, KKT_battery_b⁻[n=1:N,t=2:T,k=[5]], #=2*β*b⁻[n,t,k]=# - λ⁶[n,t,k]*η - λ⁷[n,t,k]  - μ̲ᵇ⁻[n,t,k] + μ̅ᵇ⁻[n,t,k] == 0)
        @constraint(bilevel, KKT_battery_e_1[n=1:N,t=[1],k=[5]],  - λ⁸[n,k] + λ⁷[n,t+1,k] - μ̲ᵉ[n,t,k] + μ̅ᵉ[n,t,k] == 0)
        @constraint(bilevel, KKT_battery_e[n=1:N,t=2:T-1,k=[5]], - λ⁷[n,t,k] + λ⁷[n,t+1,k] - μ̲ᵉ[n,t,k] + μ̅ᵉ[n,t,k] == 0)
        @constraint(bilevel, KKT_battery_e_24[n=1:N,t=[T],k=[5]], - λ⁷[n,t,k] + λ⁸[n,k] - μ̲ᵉ[n,t,k] + μ̅ᵉ[n,t,k] == 0)
        @constraint(bilevel, KKT_battery_λ⁶[n=1:N,t=1:T,k=[5]], - p[n,t,k] - PV[n,t] + L[n,t] + b⁺[n,t,k]/η - η*b⁻[n,t,k] == 0)
        @constraint(bilevel, KKT_battery_λ⁷[n=1:N,t=2:T,k=[5]], e[n,t-1,k] - e[n,t,k] + b⁺[n,t,k] - b⁻[n,t,k] == 0)
        @constraint(bilevel, KKT_battery_λ⁸[n=1:N,t=[1],k=[5]], e[n,T,k] - e[n,t,k] + b⁺[n,t,k] - b⁻[n,t,k] == 0)
        
        if type == "NL"
            #charging and soc limits
            @constraint(bilevel, KKT_battery_b⁺_min[k=[5],t=1:T,n=1:N], b⁺[n,t,k] >= B̲[n])
            @constraint(bilevel, KKT_battery_b⁺_max[k=[5],t=1:T,n=1:N], b⁺[n,t,k] <= B̅[n])
            @constraint(bilevel, KKT_battery_b⁻_min[k=[5],t=1:T,n=1:N], b⁻[n,t,k] >= B̲[n])
            @constraint(bilevel, KKT_battery_b⁻_max[k=[5],t=1:T,n=1:N], b⁻[n,t,k] <= B̅[n])
            @constraint(bilevel, KKT_battery_e_min[k=[5],t=1:T,n=1:N], e[n,t,k] >= E̲[n])
            @constraint(bilevel, KKT_battery_e_max[k=[5],t=1:T,n=1:N], e[n,t,k] <= E̅[n])

            #strong duality
            @constraint(bilevel, strong_duality_k5[n=1:N,k=[5]],sum(x[n,t]*p[n,t,k] #=+ β*(b⁺[n,t,k]^2 + b⁻[n,t,k]^2)=# for t in 1:T) == sum( λ⁶[n,t,k]*(-PV[n,t] + L[n,t]) + μ̲ᵇ⁺[n,t,k]*B̲[n] - μ̅ᵇ⁺[n,t,k]*B̅[n] + μ̲ᵇ⁻[n,t,k]*B̲[n] - μ̅ᵇ⁻[n,t,k]*B̅[n] + μ̲ᵉ[n,t,k]*E̲[n] - μ̅ᵉ[n,t,k]*E̅[n] for t in 1:T))
        elseif type == "Linear"
            #Big-M for battery charging complementarities
            M_charging_min = 1000
            M_charging_max = 1000
            @constraint(bilevel, KKT_battery_b⁺_min[k=[5],t=1:T,n=1:N], b⁺[n,t,k] >= B̲[n])
            @constraint(bilevel, KKT_battery_b⁺_max[k=[5],t=1:T,n=1:N], b⁺[n,t,k] <= B̅[n])

            @variable(bilevel, u̲ᵇ⁺[1:N,1:T,[5]], Bin)
            @constraint(bilevel, compl_μ̲ᵇ⁺_b⁺[k=[5],t=1:T,n=1:N], μ̲ᵇ⁺[n,t,k] <= u̲ᵇ⁺[n,t,k]*M_charging_min)
            @constraint(bilevel, compl_b⁺_μ̲ᵇ⁺[k=[5],t=1:T,n=1:N], b⁺[n,t,k] - B̲[n] <= (1-u̲ᵇ⁺[n,t,k])*M_charging_min)

            @variable(bilevel, u̅ᵇ⁺[1:N,1:T,[5]], Bin)
            @constraint(bilevel, compl_μ̅ᵇ⁺_b⁺[k=[5],t=1:T,n=1:N], μ̅ᵇ⁺[n,t,k] <= u̅ᵇ⁺[n,t,k]*M_charging_max)
            @constraint(bilevel, compl_b⁺_μ̅ᵇ⁺[k=[5],t=1:T,n=1:N], B̅[n] - b⁺[n,t,k] <= (1-u̅ᵇ⁺[n,t,k])*M_charging_max)

            #Big-M for battery discharging complementarities
            M_discharging = 1000
            @constraint(bilevel, KKT_battery_b⁻_min[k=[5],t=1:T,n=1:N], b⁻[n,t,k] >= B̲[n])
            @constraint(bilevel, KKT_battery_b⁻_max[k=[5],t=1:T,n=1:N], b⁻[n,t,k] <= B̅[n])

            @variable(bilevel, u̲ᵇ⁻[1:N,1:T,[5]], Bin)
            @constraint(bilevel, compl_μ̲ᵇ⁻_b⁻[k=[5],t=1:T,n=1:N], μ̲ᵇ⁻[n,t,k] <= u̲ᵇ⁻[n,t,k]*M_discharging)
            @constraint(bilevel, compl_b⁻_μ̲ᵇ⁻[k=[5],t=1:T,n=1:N], b⁻[n,t,k] - B̲[n] <= (1-u̲ᵇ⁻[n,t,k])*M_discharging)

            @variable(bilevel, u̅ᵇ⁻[1:N,1:T,[5]], Bin)
            @constraint(bilevel, compl_μ̅ᵇ⁻_b⁻[k=[5],t=1:T,n=1:N], μ̅ᵇ⁻[n,t,k] <= u̅ᵇ⁻[n,t,k]*M_discharging)
            @constraint(bilevel, compl_b⁻_μ̅ᵇ⁻[k=[5],t=1:T,n=1:N], B̅[n] - b⁻[n,t,k] <= (1-u̅ᵇ⁻[n,t,k])*M_discharging)

            #Big-M for SOC complementarities
            M_soc = 1000
            @constraint(bilevel, KKT_battery_e_min[k=[5],t=1:T,n=1:N], e[n,t,k] >= E̲[n])
            @constraint(bilevel, KKT_battery_e_max[k=[5],t=1:T,n=1:N], e[n,t,k] <= E̅[n])

            @variable(bilevel, u̲ᵉ[1:N,1:T,[5]], Bin)
            @constraint(bilevel, compl_μ̲ᵉ_e[k=[5],t=1:T,n=1:N], μ̲ᵉ[n,t,k] <= u̲ᵉ[n,t,k]*M_soc)
            @constraint(bilevel, compl_e_μ̲ᵉ[k=[5],t=1:T,n=1:N], e[n,t,k] - E̲[n] <= (1-u̲ᵉ[n,t,k])*M_soc)

            @variable(bilevel, u̅ᵉ[1:N,1:T,[5]], Bin)
            @constraint(bilevel, compl_μ̅ᵉ_e[k=[5],t=1:T,n=1:N], μ̅ᵉ[n,t,k] <= u̅ᵉ[n,t,k]*M_soc)
            @constraint(bilevel, compl_e_μ̅ᵉ[k=[5],t=1:T,n=1:N], E̅[n] - e[n,t,k] <= (1-u̅ᵉ[n,t,k])*M_soc)
        end
    end
    
    #Individual individual_rationality
    if K == 3
        @constraint(bilevel, individual_rationality[n=1:N], theta_sample[n,1]*(sum(-λ¹[n,t,1]*PV[n,t] + μ̲ˡ[n,t,1]*minimum(L[n,:]) - μ̅ˡ[n,t,1]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³[n,1]*sum(L[n,t] for t in T_morning)) 
                                                            + theta_sample[n,2]*(sum(-λ¹[n,t,2]*PV[n,t] + μ̲ˡ[n,t,2]*minimum(L[n,:]) - μ̅ˡ[n,t,2]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³[n,2]*sum(L[n,t] for t in T_day)) 
                                                            + theta_sample[n,3]*(sum(-λ¹[n,t,3]*PV[n,t] + μ̲ˡ[n,t,3]*minimum(L[n,:]) - μ̅ˡ[n,t,3]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³[n,3]*sum(L[n,t] for t in T_evening)) 
                                                            <= Cᵉˣᵗ[n])

        @constraint(bilevel, revenue_adequacy, sum(theta_sample[n,1]*(sum(-λ¹[n,t,1]*PV[n,t] + μ̲ˡ[n,t,1]*minimum(L[n,:]) - μ̅ˡ[n,t,1]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³[n,1]*sum(L[n,t] for t in T_morning)) 
                                                + theta_sample[n,2]*(sum(-λ¹[n,t,2]*PV[n,t] + μ̲ˡ[n,t,2]*minimum(L[n,:]) - μ̅ˡ[n,t,2]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³[n,2]*sum(L[n,t] for t in T_day)) 
                                                + theta_sample[n,3]*(sum(-λ¹[n,t,3]*PV[n,t] + μ̲ˡ[n,t,3]*minimum(L[n,:]) - μ̅ˡ[n,t,3]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³[n,3]*sum(L[n,t] for t in T_evening)) for n in 1:N) 
                                                >= 3000)

    elseif K == 4
        @constraint(bilevel, individual_rationality[n=1:N], theta_sample[n,1]*(sum(-λ¹[n,t,1]*PV[n,t] + μ̲ˡ[n,t,1]*minimum(L[n,:]) - μ̅ˡ[n,t,1]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³[n,1]*sum(L[n,t] for t in T_morning)) 
                                                            + theta_sample[n,2]*(sum(-λ¹[n,t,2]*PV[n,t] + μ̲ˡ[n,t,2]*minimum(L[n,:]) - μ̅ˡ[n,t,2]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³[n,2]*sum(L[n,t] for t in T_day)) 
                                                            + theta_sample[n,3]*(sum(-λ¹[n,t,3]*PV[n,t] + μ̲ˡ[n,t,3]*minimum(L[n,:]) - μ̅ˡ[n,t,3]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³[n,3]*sum(L[n,t] for t in T_evening)) 
                                                            + theta_sample[n,4]*(sum(-λ⁴[n,t,4]*PV[n,t] + μ̲ˡ[n,t,4]*minimum(L[n,:]) - μ̅ˡ[n,t,4]*maximum(L[n,:]) for t in 1:T) - λ⁵[n,4]*sum(L[n,t] for t in 1:T)) 
                                                            <= Cᵉˣᵗ[n])

        @constraint(bilevel, revenue_adequacy, sum(theta_sample[n,1]*(sum(-λ¹[n,t,1]*PV[n,t] + μ̲ˡ[n,t,1]*minimum(L[n,:]) - μ̅ˡ[n,t,1]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³[n,1]*sum(L[n,t] for t in T_morning)) 
                                                + theta_sample[n,2]*(sum(-λ¹[n,t,2]*PV[n,t] + μ̲ˡ[n,t,2]*minimum(L[n,:]) - μ̅ˡ[n,t,2]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³[n,2]*sum(L[n,t] for t in T_day)) 
                                                + theta_sample[n,3]*(sum(-λ¹[n,t,3]*PV[n,t] + μ̲ˡ[n,t,3]*minimum(L[n,:]) - μ̅ˡ[n,t,3]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³[n,3]*sum(L[n,t] for t in T_evening)) 
                                                + theta_sample[n,4]*(sum(-λ⁴[n,t,4]*PV[n,t] + μ̲ˡ[n,t,4]*minimum(L[n,:]) - μ̅ˡ[n,t,4]*maximum(L[n,:]) for t in 1:T) - λ⁵[n,4]*sum(L[n,t] for t in 1:T)) for n in 1:N) 
                                                >= 3000)

    elseif K == 5
        @constraint(bilevel, individual_rationality[n=1:N], theta_sample[n,1]*(sum(-λ¹[n,t,1]*PV[n,t] + μ̲ˡ[n,t,1]*minimum(L[n,:]) - μ̅ˡ[n,t,1]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³[n,1]*sum(L[n,t] for t in T_morning)) 
                                                            + theta_sample[n,2]*(sum(-λ¹[n,t,2]*PV[n,t] + μ̲ˡ[n,t,2]*minimum(L[n,:]) - μ̅ˡ[n,t,2]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³[n,2]*sum(L[n,t] for t in T_day)) 
                                                            + theta_sample[n,3]*(sum(-λ¹[n,t,3]*PV[n,t] + μ̲ˡ[n,t,3]*minimum(L[n,:]) - μ̅ˡ[n,t,3]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³[n,3]*sum(L[n,t] for t in T_evening)) 
                                                            + theta_sample[n,4]*(sum(-λ⁴[n,t,4]*PV[n,t] + μ̲ˡ[n,t,4]*minimum(L[n,:]) - μ̅ˡ[n,t,4]*maximum(L[n,:]) for t in 1:T) - λ⁵[n,4]*sum(L[n,t] for t in 1:T)) 
                                                            + theta_sample[n,5]*(sum( λ⁶[n,t,5]*(-PV[n,t] + L[n,t]) + μ̲ᵇ⁺[n,t,5]*B̲[n] - μ̅ᵇ⁺[n,t,5]*B̅[n] + μ̲ᵇ⁻[n,t,5]*B̲[n] - μ̅ᵇ⁻[n,t,5]*B̅[n] + μ̲ᵉ[n,t,5]*E̲[n] - μ̅ᵉ[n,t,5]*E̅[n] for t in 1:T)) 
                                                            <= Cᵉˣᵗ[n])

        @constraint(bilevel, revenue_adequacy, sum(theta_sample[n,1]*(sum(-λ¹[n,t,1]*PV[n,t] + μ̲ˡ[n,t,1]*minimum(L[n,:]) - μ̅ˡ[n,t,1]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻¹[n,t]*L[n,t] for t in setdiff(1:T,T_morning)) - λ³[n,1]*sum(L[n,t] for t in T_morning)) 
                                                + theta_sample[n,2]*(sum(-λ¹[n,t,2]*PV[n,t] + μ̲ˡ[n,t,2]*minimum(L[n,:]) - μ̅ˡ[n,t,2]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻²[n,t]*L[n,t] for t in setdiff(1:T,T_day)) - λ³[n,2]*sum(L[n,t] for t in T_day)) 
                                                + theta_sample[n,3]*(sum(-λ¹[n,t,3]*PV[n,t] + μ̲ˡ[n,t,3]*minimum(L[n,:]) - μ̅ˡ[n,t,3]*maximum(L[n,:]) for t in 1:T) - sum(λ²⁻³[n,t]*L[n,t] for t in setdiff(1:T,T_evening)) - λ³[n,3]*sum(L[n,t] for t in T_evening)) 
                                                + theta_sample[n,4]*(sum(-λ⁴[n,t,4]*PV[n,t] + μ̲ˡ[n,t,4]*minimum(L[n,:]) - μ̅ˡ[n,t,4]*maximum(L[n,:]) for t in 1:T) - λ⁵[n,4]*sum(L[n,t] for t in 1:T)) 
                                                + theta_sample[n,5]*(sum( λ⁶[n,t,5]*(-PV[n,t] + L[n,t]) + μ̲ᵇ⁺[n,t,5]*B̲[n] - μ̅ᵇ⁺[n,t,5]*B̅[n] + μ̲ᵇ⁻[n,t,5]*B̲[n] - μ̅ᵇ⁻[n,t,5]*B̅[n] + μ̲ᵉ[n,t,5]*E̲[n] - μ̅ᵉ[n,t,5]*E̅[n] for t in 1:T)) for n in 1:N) 
                                                >= 3000)

    end

    #Capacity Limitation Objective Function
    @objective(bilevel,Min, sum(pⁱᵐ[t]*(DA_prices[t] .+ τⁱᵐ) - pᵉˣ[t]*(DA_prices[t] .- τᵉˣ) + (1-βᴰˢᴼ)*τⁱᵐ*(sum(y⁺[n,t] for n in 1:N)-pⁱᵐ[t]) + α*pᵖᵉⁿ[t] - sum(Γ[n] for n in 1:N) for t in 1:T))

    println("Running model...")
    optimize!(bilevel)

    println("Solve Time: ", solve_time(bilevel))
    println("Termination Status: ", termination_status(bilevel))
    if type == "Linear"
        gap = MOI.get(bilevel, MOI.RelativeGap())
        println("Optimality Gap: ", MOI.get(bilevel, MOI.RelativeGap()))
    end
    #println("θ Sample: ", theta_sample)
    #println("θ Sum: ", sum(theta_sample))

    if type == "Linear"
        load_count = 0
        charging_count = 0
        discharging_count = 0
        soc_count = 0
        for t in 1:T
            for n in 1:N
                for k in 1:5
                    #Check load complementarities
                    if k in 1:4
                        if (abs(value.(μ̲ˡ[n,t,k]) * (value.(l[n,t,k]) - minimum(L[n,:]))) >= 1e-6) || (abs(value.(μ̅ˡ[n,t,k]) * (maximum(L[n,:]) - value.(l[n,t,k]))) >= 1e-6)
                            load_count += 1
                            println("Lower limit:", abs(value.(μ̲ˡ[n,t,k]) * (value.(l[n,t,k]) - minimum(L[n,:]))))
                            println("Upper limit:", abs(value.(μ̅ˡ[n,t,k]) * (maximum(L[n,:]) - value.(l[n,t,k]))))
                            println("Load value:", value(l[n,t,k]))
                        end
                    end
                    #Checking battery complementarities
                    if k == 5
                        #Check charging complementarities
                        if (abs(value.(μ̲ᵇ⁺[n,t,k]) * (value.(b⁺[n,t,k]) - B̲[n])) >= 1e-6) || (abs(value.(μ̅ᵇ⁺[n,t,k]) * (B̅[n] - value.(b⁺[n,t,k])))>= 1e-6) || value.(μ̲ᵇ⁺[n,t,k]) >= M_charging_min || value.(μ̅ᵇ⁺[n,t,k]) >= M_charging_max
                            charging_count += 1
                            println("Lower limit:", abs(value.(μ̲ᵇ⁺[n,t,k]) * (value.(b⁺[n,t,k]) - B̲[n])))
                            println("Upper limit:", abs(value.(μ̅ᵇ⁺[n,t,k]) * (B̅[n] - value.(b⁺[n,t,k]))))
                            println("Charging:", value(b⁺[n,t,k]))
                            println("Dual lower:", value(μ̲ᵇ⁺[n,t,k]))
                            println("Dual upper:", value(μ̅ᵇ⁺[n,t,k]))
                        end
                        #Check discharging complementarities
                        if (abs(value.(μ̲ᵇ⁻[n,t,k]) * (value.(b⁻[n,t,k]) - B̲[n])) >= 1e-6) || (abs(value.(μ̅ᵇ⁻[n,t,k]) * (B̅[n] - value.(b⁻[n,t,k])))>= 1e-6) || value.(μ̲ᵇ⁻[n,t,k]) >= M_discharging || value.(μ̅ᵇ⁻[n,t,k]) >= M_discharging 
                            discharging_count += 1
                            println("Lower limit:", abs(value.(μ̲ᵇ⁻[n,t,k]) * (value.(b⁻[n,t,k]) - B̲[n])))
                            println("Upper limit:", abs(value.(μ̅ᵇ⁻[n,t,k]) * (B̅[n] - value.(b⁻[n,t,k]))))
                            println("Discharging:", value(b⁻[n,t,k]))
                            println("Dual lower:", value(μ̲ᵇ⁻[n,t,k]))
                            println("Dual upper:", value(μ̅ᵇ⁻[n,t,k]))
                        end
                        #Check SOC complementarities
                        if (abs(value.(μ̲ᵉ[n,t,k]) * (value.(e[n,t,k]) - E̲[n])) >= 1e-6) || (abs(value.(μ̅ᵉ[n,t,k]) * (E̅[n] - value.(e[n,t,k])))>= 1e-6) || value.(μ̲ᵉ[n,t,k]) >= M_soc || value.(μ̅ᵉ[n,t,k]) >= M_soc
                            soc_count += 1
                            println("Lower limit:", abs(value.(μ̲ᵉ[n,t,k]) * (value.(e[n,t,k]) - E̲[n])))
                            println("Upper limit:", abs(value.(μ̅ᵉ[n,t,k]) * (E̅[n] - value.(e[n,t,k]))))
                            println("SOC:", value(e[n,t,k]))
                            println("Dual lower:", value(μ̲ᵉ[n,t,k]))
                            println("Dual upper:", value(μ̅ᵉ[n,t,k]))
                        end 
                    end
                end
            end
        end

        if load_count >= 1
            println("Load Complementarities Broken: ", load_count)
        end
        if charging_count >= 1
            println("Charging Complementarities Broken: ", charging_count)
        end
        if discharging_count >= 1
            println("Discharging Complementarities Broken: ", discharging_count)
        end
        if soc_count >= 1
            println("SOC Complementarities Broken: ", soc_count)
        end
    end
    
    penalty_values = zeros(T)
    y_values = zeros(N,T);
    x_values = zeros(N,T);
    H_values = zeros(N,T,K)

    #=
    for n in 1:N
        plot(Array(value.(e[n,:,5])), label = "SOC")
        plot!(Array(value.(b⁻[n,:,5])), label = "Discharging")
        plot!(Array(value.(b⁺[n,:,5])), label = "Charging")
        display(plot!())
    end
    =#

    #=
    println("Lower level primal")
    for n = 1:N
        for k = 5
            println(sum(value.(x[n,t])*value.(p[n,t,k]) for t in 1:T))
        end
    end

    println("Lower level dual")
    for n=1:N
        println(
            sum(
                value(λ⁶[n,t,5])*(-PV[n,t] + L[n,t]) 
                + value(μ̲ᵇ⁺[n,t,5])*B̲[n] 
                - value(μ̅ᵇ⁺[n,t,5])*B̅[n] 
                + value(μ̲ᵇ⁻[n,t,5])*B̲[n] 
                - value(μ̅ᵇ⁻[n,t,5])*B̅[n] 
                + value(μ̲ᵉ[n,t,5])*E̲[n] 
                - value(μ̅ᵉ[n,t,5])*E̅[n] 
                for t in 1:T))
    end
    =#

    println("RESULTS FROM BILEVEL")
    println(sum(value.(Γ)))
    for n in 1:N
        println("--- Consumer $n ---")
        println("Prices: ",value.(x[n,:]))
        println("binaries - u: ", value(u[n]), " z: ", value(z[n]))
    end

    
    for n = 1:N
        duals = DataFrame()
        duals[!,:λ⁶] = value.(λ⁶[n,:,5])
        duals[!,:μ̲ᵇ⁺] = value.(μ̲ᵇ⁺[n,:,5])
        duals[!,:μ̅ᵇ⁺] = value.(μ̅ᵇ⁺[n,:,5])
        duals[!,:μ̲ᵇ⁻] = value.(μ̲ᵇ⁻[n,:,5])
        duals[!,:μ̅ᵇ⁻] = value.(μ̅ᵇ⁻[n,:,5])
        duals[!,:μ̲ᵉ] = value.(μ̲ᵉ[n,:,5])
        duals[!,:μ̅ᵉ] = value.(μ̅ᵉ[n,:,5])
        #println(duals)
    end
    

    for t in 1:T
        for n in 1:N
            y_values[n,t] = value(y[n,t])
            x_values[n,t] = value(x[n,t])
            for k in 1:K
                H_values[n,t,k] = value(p[n,t,k])
            end
        end
    end
    return x_values, y_values, H_values, objective_value(bilevel), solve_time(bilevel)#, gap
end

function battery_dual_problem(price,L,PV,N,T)
    for n = 1:N
        #Defining models
        battery_dual = Model(() -> Gurobi.Optimizer(GRB_ENV))

        #Parameters
        η = 0.95
        β = 0.5
        #Parameters
        E̲ = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        E̅ = [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]
        B̲ = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
        B̅ = E̅./2
        
        #Variables
        @variable(battery_dual, λ⁶[1:T])
        @variable(battery_dual, λ⁷[2:T])
        @variable(battery_dual, λ⁸)
        @variable(battery_dual, μ̲ᵇ⁺[1:T] >= 0)
        @variable(battery_dual, μ̅ᵇ⁺[1:T] >= 0)
        @variable(battery_dual, μ̲ᵇ⁻[1:T] >= 0)
        @variable(battery_dual, μ̅ᵇ⁻[1:T] >= 0)
        @variable(battery_dual, μ̲ᵉ[1:T] >= 0)
        @variable(battery_dual, μ̅ᵉ[1:T] >= 0)
        #@variable(battery_dual, 0 <= b⁺[t][1:T] <= 2.5)
        #@variable(battery_dual, 0 <= b⁻[t][1:T] <= 2.5)
        

        #Objective
        @objective(battery_dual, Max, sum(λ⁶[t]*(PV[n,t] - L[n,t]) + μ̲ᵇ⁺[t]*B̲[n] - μ̅ᵇ⁺[t]*B̅[n] + μ̲ᵇ⁻[t]*B̲[n] - μ̅ᵇ⁻[t]*B̅[n] + μ̲ᵉ[t]*E̲[n] - μ̅ᵉ[t]*E̅[n] for t in 1:T))

        #Constraints
        @constraint(battery_dual, KKT_battery_p[t=1:T], price[n,t] - λ⁶[t] == 0)
        @constraint(battery_dual, KKT_battery_b⁺_1[t=[1]], #=2*β*b⁺[t]=# + λ⁶[t]/η + λ⁸  - μ̲ᵇ⁺[t] + μ̅ᵇ⁺[t] == 0)
        @constraint(battery_dual, KKT_battery_b⁺[t=2:T], #=2*β*b⁺[t]=# + λ⁶[t]/η + λ⁷[t] - μ̲ᵇ⁺[t] + μ̅ᵇ⁺[t] == 0)
        @constraint(battery_dual, KKT_battery_b⁻_1[t=[1]], #=2*β*b⁻[t]=# - λ⁶[t]*η - λ⁸ - μ̲ᵇ⁻[t] + μ̅ᵇ⁻[t] == 0)
        @constraint(battery_dual, KKT_battery_b⁻[t=2:T], #=2*β*b⁻[t]=# - λ⁶[t]*η - λ⁷[t]  - μ̲ᵇ⁻[t] + μ̅ᵇ⁻[t] == 0)
        @constraint(battery_dual, KKT_battery_e_1[t=[1]],  - λ⁸ + λ⁷[t+1] - μ̲ᵉ[t] + μ̅ᵉ[t] == 0)
        @constraint(battery_dual, KKT_battery_e[t=2:T-1], - λ⁷[t] + λ⁷[t+1] - μ̲ᵉ[t] + μ̅ᵉ[t] == 0)
        @constraint(battery_dual, KKT_battery_e_24[t=[T]], - λ⁷[t] + λ⁸ - μ̲ᵉ[t] + μ̅ᵉ[t] == 0)
        optimize!(battery_dual)
        println(objective_value(battery_dual))
    end
end

function response(prices,L,PV,N,T,K)
    K_set = 1:K
    T_set = 1:T

    if K == 3
        true_theta =  [0.6 0.4 0.0; 0.0 0.5 0.5; 0.0 0.0 1.0; 0.5 0.0 0.5; 0.33 0.33 0.34; 0.8 0.2 0.0; 0.1 0.8 0.1; 0.3 0.0 0.7; 0.1 0.4 0.5; 0.15 0.15 0.7; 0.23 0.37 0.4; 0.9 0.05 0.05]
    elseif K == 4
        true_theta =  [0.5 0.0 0.5 0.0; 0.0 0.5 0.5 0.0; 0.0 0.0 1.0 0.0; 0.5 0.0 0.5 0.0; 0.33 0.33 0.34 0.0; 0.8 0.2 0.0 0.0; 0.1 0.8 0.1 0.0; 0.3 0.0 0.7 0.0; 0.1 0.4 0.5 0.0; 0.15 0.15 0.7 0.0; 0.23 0.37 0.4 0.0; 0.9 0.05 0.05 0.0] #repeat([0.33 0.33 0.34],N)
    elseif K == 5
        true_theta =  [0.2 0.2 0.2 0.2 0.2; 0.0 0.5 0.4 0.0 0.1; 0.2 0.3 0.1 0.1 0.3; 0.4 0.0 0.5 0.0 0.1; 0.33 0.33 0.34 0.0 0.0; 0.5 0.2 0.0 0.0 0.3; 0.1 0.5 0.1 0.0 0.3; 0.3 0.0 0.2 0.0 0.5; 0.1 0.4 0.5 0.0 0.0; 0.15 0.15 0.0 0.0 0.7; 0.23 0.17 0.4 0.1 0.1; 0.2 0.05 0.05 0.4 0.3]
    end 

    #Noise parameters
    mean = 0
    variance = 0.15
    noise = Normal(mean,variance)
    beta = 0.5

    ### SIGNATURES ###

    response = Matrix{Float64}(undef,T,N)
    no_noise = Matrix{Float64}(undef,T,N)
    p_values = Array{Float64}(undef,N,T,K)

    #Battery parameters
    E̲ = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    E̅ = [5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5]
    B̲ = [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]
    B̅ = E̅./2

    for n in 1:N
        if K >= 1
        ### --------------- MORNING FLEXIBILITY --------------- ###
        #indexing signature number
        k=1

        #Setting Model with Gurobi optimizer
        signature_morning = Model(() -> Gurobi.Optimizer(GRB_ENV))

        #Parameters
        T_flex = 6:9
        T_nonflex = setdiff(T_set,T_flex)

        #Variables
        @variable(signature_morning, p[T_set])
        @variable(signature_morning, minimum(L[n,:]) <= l[T_set] <= maximum(L[n,:]))

        #Objective
        @objective(signature_morning, Min, sum(prices[n,t]*p[t] + beta*p[t]^2 for t in T_set))

        #Constraints
        @constraint(signature_morning, balance_constraints[t=T_set], -p[t] - PV[n,t] + l[t] == 0) #Balance constraint
        @constraint(signature_morning, flex_hours, sum(l[t] - L[n,t] for t in T_flex) == 0)
        @constraint(signature_morning, non_flex_hours[t=T_nonflex], l[t] - L[n,t] == 0)

        #Solve Problem
        optimize!(signature_morning)

        #Saving power values into power array for prosumer n
        p_values[n,:,k] = value.(p[:])
        end

        if K >= 2
        ### --------------- DAY FLEXIBILITY --------------- ###
        #indexing signature number
        k=2

        #Setting Model with Gurobi optimizer
        signature_day = Model(() -> Gurobi.Optimizer(GRB_ENV))

        #Parameters
        T_flex = 10:16
        T_nonflex = setdiff(T_set,T_flex)

        #Variables
        @variable(signature_day, p[T_set])
        @variable(signature_day, minimum(L[n,:]) <= l[T_set] <= maximum(L[n,:]))

        #Objective
        @objective(signature_day, Min, sum(prices[n,t]*p[t] + beta*p[t]^2 for t in T_set))

        #Constraints
        @constraint(signature_day, balance_constraints[t=T_set], -p[t] - PV[n,t] + l[t] == 0) #Balance constraint
        @constraint(signature_day, flex_hours, sum(l[t] - L[n,t] for t in T_flex) == 0)
        @constraint(signature_day, non_flex_hours[t=T_nonflex], l[t] - L[n,t] == 0)

        #Solve Problem
        optimize!(signature_day)

        #Saving power values for signature k into power array for prosumer n
        p_values[n,:,k] = value.(p[:])
        end

        if K >= 3
        ### --------------- EVENING FLEXIBILITY --------------- ###
        #indexing signature number
        k=3

        #Setting Model with Gurobi optimizer
        signature_evening = Model(() -> Gurobi.Optimizer(GRB_ENV))

        #Parameters
        T_flex = 17:22
        T_nonflex = setdiff(T_set,T_flex)

        #Variables
        @variable(signature_evening, p[T_set])
        @variable(signature_evening, minimum(L[n,:]) <= l[T_set] <= maximum(L[n,:]))

        #objective
        @objective(signature_evening, Min, sum(prices[n,t]*p[t] + beta*p[t]^2 for t in T_set))

        #constraints
        @constraint(signature_evening, balance_constraints[t=T_set], -p[t] - PV[n,t] + l[t] == 0) #Balance constraint
        @constraint(signature_evening, flex_hours, sum(l[t] - L[n,t] for t in T_flex) == 0)
        @constraint(signature_evening, non_flex_hours[t=T_nonflex], l[t] - L[n,t] == 0)

        #Solving evening signature
        optimize!(signature_evening)
        #Saving power values for signature k into power array for prosumer n
        p_values[n,:,k] = value.(p[:])
        end

        if K >= 4
            ### --- STUBBORN PROSUMER --- ###
            k = 4

            #Defining models
            stubborn = Model(() -> Gurobi.Optimizer(GRB_ENV))

            #Variables
            @variable(stubborn, p[T_set])
            @variable(stubborn, minimum(L[n,:]) <= l[T_set] <= maximum(L[n,:]))

            #Objective
            @objective(stubborn, Min, sum(prices[n,t]*p[t] + beta*(L[n,t] - l[t])^2 for t in T_set))

            #Constraints
            @constraint(stubborn, balance[t=T_set], p[t] + PV[n,t] - l[t] == 0)
            @constraint(stubborn, totalload, sum(l[t] - L[n,t] for t in T_set) == 0)
            optimize!(stubborn)

            #Saving power values for signature k into power array for prosumer n
            p_values[n,:,k] = value.(p[:])
        end

        if K >= 5
            k = 5

            #Defining models
            battery = Model(() -> Gurobi.Optimizer(GRB_ENV))

            #Parameters
            η = 0.95

            #Variables
            @variable(battery, p[T_set])
            @variable(battery, B̲[n] <= b⁺[T_set] <= B̅[n])
            @variable(battery, B̲[n] <= b⁻[T_set] <= B̅[n])
            @variable(battery, E̲[n] <= e[T_set] <= E̅[n])

            #Objective
            @objective(battery, Min, sum(prices[n,t]*p[t] #=+ beta*(b⁺[t]^2 + b⁻[t]^2)=# for t in T_set))

            #Constraints
            @constraint(battery, balance[t=T_set], -p[t] - PV[n,t] + L[n,t] + b⁺[t]/η - b⁻[t]*η == 0)
            @constraint(battery, initial_SOC, e[T] + b⁺[1] - b⁻[1] == e[1])
            @constraint(battery, SOC[t=2:T], e[t-1] + b⁺[t] - b⁻[t] == e[t])
            #println(lp_matrix_data(battery))
            optimize!(battery)

            primal = objective_value(battery)
            #println("Response primal objective:", primal)

            #=
            plot(Array(value.(e)), label="SOC")
            plot!(Array(value.(b⁺)),label = "charging")
            plot!(Array(value.(b⁻)), label = "discharging")
            display(plot!())
            =#

            ### PRINTING OUT DUALS ###

            duals = DataFrame()
            duals[!,:λ⁶] = dual.(balance)
            duals[!,:μ̲ᵇ⁺] = dual.(LowerBoundRef.(b⁺))
            duals[!,:μ̅ᵇ⁺] = dual.(UpperBoundRef.(b⁺))
            duals[!,:μ̲ᵇ⁻] = dual.(LowerBoundRef.(b⁻))
            duals[!,:μ̅ᵇ⁻] = dual.(UpperBoundRef.(b⁻))
            duals[!,:μ̲ᵉ] = dual.(LowerBoundRef.(e))
            duals[!,:μ̅ᵉ] = dual.(UpperBoundRef.(e))
            #println(duals)
            dual_obj = sum(duals[!,:λ⁶][t]*(-PV[n,t] + L[n,t]) + duals[!,:μ̲ᵇ⁺][t]*B̲[n] - duals[!,:μ̅ᵇ⁺][t]*B̅[n] + duals[!,:μ̲ᵇ⁻][t]*B̲[n] - duals[!,:μ̅ᵇ⁻][t]*B̅[n] + duals[!,:μ̲ᵉ][t]*E̲[n] - duals[!,:μ̅ᵉ][t]*E̅[n] for t = 1:T)
            #println("Response dual objective",dual_obj)
            #Saving power values for signature k into power array for prosumer n
            p_values[n,:,k] = value.(p[:])
        end

        noise_sample = rand(noise,T)

        response[:,n] = p_values[n,:,:]*true_theta[n,:] + noise_sample
        no_noise[:,n] = p_values[n,:,:]*true_theta[n,:]
        end
    return response, no_noise, p_values, diagm(repeat([variance],T))
end

function regretplots(regret,I_n)
    default(fontfamily = "Computer Modern", dpi = 400, size = (800, 600))
    total_regret = Array{Float64}(undef,1,I_n)

    for i in 1:I_n
        if i == 1
            total_regret[1,i] = regret[1,i]
        else
            total_regret[1,i] = total_regret[1,i-1] + regret[1,i]
        end
    end

    totalregretplot = plot(mean(transpose(total_regret),dims=2), label = "Cumulative regret", ylabel = L"\mathrm{Total \ Regret \ [kW^2]}", xlabel = "Iteration [day]", xlims = (0,I_n))
    #perroundregretplot = plot(1:I_n,mean(transpose(regret),dims=2), label = "Per-round regret", ylabel = L"\mathrm{Daily \ Regret \ [kW^2]}", xlims = (0,I_n))
    #regretplot = plot(totalregretplot, perroundregretplot, layout=(1,2),size = (800,400), left_margin=8Plots.mm, bottom_margin = 8Plots.mm, legend = false)
    xlabel!("Iteration [day]")

    return totalregretplot
end

function response_alternate(prices,N,T,K)
    A = [5 2 7]
    B = [0.2 0 0.4]

    theta_star =    repeat([0.33 0.33 0.34],24)

    signatures = Array{Float64}(undef,N,T,K)
    for n in 1:N
        for t in 1:T
            for k in 1:K
                signatures[n,t,k] = A[k] - B[k]*prices[t,n]
            end
        end
    end

    variance = 0.25
    noise = Normal(0,variance)

    noise_sample = rand(noise,T)
    response = Matrix{Float64}(undef,T,N)
    no_noise_response = Matrix{Float64}(undef,T,N)
    for n in 1:N
        response[:,n] = signatures[n,:,:]*theta_star[n,:] + noise_sample
        no_noise_response[:,n] = signatures[n,:,:]*theta_star[n,:]
    end

    return response, no_noise_response, signatures, diagm(repeat([variance],24))
end

### To debug
function pricing_alternate(theta,Y,N,T,K)
    
    linear_pricing = Model(() -> Gurobi.Optimizer(GRB_ENV))

    #Parameters
    A = [5 2 7]
    B = [0.2 0 0.4]

    #Variables
    @variable(linear_pricing, x[1:N,1:T]) #Price
    @variable(linear_pricing, y[1:N,1:T]) #Response
    @variable(linear_pricing, h[1:N,1:T,1:K]) #Power
    
    #Constraints
    @constraint(linear_pricing, constraint1[n=1:N,t=1:T,k=1:K], h[n,t,k] == A[k] - B[k]*x[n,t])
    @constraint(linear_pricing, constraint2[n=1:N,t=1:T], y[n,t] == sum(h[n,t,k]*theta[n,k] for k=1:K))

    #Objective function
    @objective(linear_pricing, Min, sum((sum(y[n,t] for n=1:N) - Y[t])^2 for t=1:T))

    optimize!(linear_pricing)

    y_values = zeros(T,N);
    x_values = zeros(T,N);
    H_values = zeros(N,T,K)
    for t in 1:T
        for n in 1:N
            y_values[t,n] = value(y[n,t])
            x_values[t,n] = value(x[n,t])
            for k in 1:K
                H_values[n,t,k] = value(h[n,t,k])
            end
        end
    end
    return x_values, y_values, H_values, objective_value(linear_pricing)
end


