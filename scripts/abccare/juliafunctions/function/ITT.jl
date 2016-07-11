# ================================================================ #
# Function for ITT estimation of ABC/CARE
# Author: Jessica Yu Kyung Koh
# Created: 05/03/2016
# Updated: 06/20/2016
# ================================================================ #

# ================================================================ #
# Function to perform ITT estimation
# ================================================================ #

function ITTestimator(sampledata, outcomes, outcome_list, controls, draw, ddraw, bootsample, bygender)

  # ----------- #
  # Preparation #
  # ----------- #
  # Define ittgender
  if bygender == 1
    ittgender = ["pooled", "male", "female"]
  elseif bygender == 0
    ittgender = ["pooled"]
  end

  # Define ITT data
  ITTdata = sampledata

  # Bootstrap resample if necessary
  if bootsample == "yes"
    if ddraw != 0
      ITTdata = bsample(ITTdata, :male, :family)
    end
  end

  # Generate IPW weight for the bootstrapped sample
  println("Bootstrap $(draw) - $(ddraw): estimating IPW weights")
  ITTdata = IPWweight(ITTdata, outcomes, outcome_list)

  outMat = Dict()

    # ----------------------------------- #
    # Define sample for each gender group #
    # ----------------------------------- #
   for gender in ittgender

     subdata = Dict()

     if gender == "male"
       subdata["$(gender)"] = ITTdata[ITTdata[:male] .== 1, :]
       controls = deleteat!(controls, findin(controls, [:male]))    # Julia does not automatically drop male
     elseif gender == "female"
       subdata["$(gender)"] = ITTdata[ITTdata[:male] .== 0, :]
       controls = deleteat!(controls, findin(controls, [:male]))
     elseif gender == "pooled"
       subdata["$(gender)"] = ITTdata
     end
     gender = parse(gender)

     # Delete controls that have 0 variance (Julia cannot drop them automatically)
     for var in controls
       if levels(subdata["$(gender)"][var])[1] == 1
         controls = deleteat!(controls, findin(controls, [var]))
       end
     end

     # ------------------------------ #
     # Define sample for each p group #
     # ------------------------------ #
     for p in (10, 0, 1)

       if p == 1
         predata = subdata["$(gender)"][!isna(subdata["$(gender)"][:P]), :]
         usedata = predata[(predata[:P] .== 1) | (predata[:R] .== 1), :]
       elseif p == 0
         predata = subdata["$(gender)"][!isna(subdata["$(gender)"][:P]), :]
         usedata = predata[(predata[:P] .== 0) | (predata[:R] .== 1), :]
       else
         usedata = subdata["$(gender)"]
       end

       outMat["ITT_$(gender)_P$(p)"] = DataFrame(rowname = [], draw = [], ddraw = [],
                              itt_noctrl = [], itt_noctrl_p = [], itt_noctrl_N = [],
                              itt_ctrl = [], itt_ctrl_p = [], itt_ctrl_N = [],
                              itt_wctrl = [], itt_wctrl_p = [], itt_wctrl_N = [])

        # ------------------ #
        # Perform estimation #
        # ------------------ #
        for y in outcome_list

            # ------------------------------- #
            # ITT without controls or weights #
            # ------------------------------- #
            ITT_none_fml = Formula(y, :R)     # Formula function convert entries into the formula format. For example, Formula(:a, :b) ==> a ~ b
            try # try/catch structure handles exceptions
              lm(ITT_none_fml, usedata)
            # If the regression fails
            catch err
              push!(outMat["ITT_$(gender)_P$(p)"], [y, draw, ddraw, NA, NA, NA, NA, NA, NA, NA, NA, NA])
              continue
            end

            ITT_none = lm(ITT_none_fml, usedata)
            ITT_none_coeff = coef(ITT_none)[2]   # index [2] shows result for R for all estimation matrix
            ITT_none_stderr = stderr(ITT_none)[2]

            # Check if Julia is able to calculate the p-value.
            pval_check = 1
            try
              ccdf(FDist(1, df_residual(ITT_none)), abs2(ITT_none_coeff./ITT_none_stderr))
            catch error
              pval_check = 0
              ITT_none_pval = NA
            end

            if pval_check == 1
              ITT_none_pval = ccdf(FDist(1, df_residual(ITT_none)), abs2(ITT_none_coeff./ITT_none_stderr))
            end

            # Create the data to check the number of observations used in the regression (non-missing Y and X)
            none_list = [y, :R]
            obsdata = usedata[:, none_list]
            for var in none_list
              obsdata = obsdata[!isna(obsdata[var]),:]
            end
            ITT_none_N = size(obsdata, 1)


            # ------------------ #
            # ITT with contronls #
            # ------------------ #
            ITT_controls_fml = Formula(y, Expr(:call, :+, :R, controls...))
            try # try/catch structure handles exceptions
              lm(ITT_controls_fml, usedata)
            # If the regression fails
            catch err
                push!(outMat["ITT_$(gender)_P$(p)"], [y, draw, ddraw, ITT_none_coeff, ITT_none_pval, ITT_none_N, NA, NA, NA, NA, NA, NA])
                continue
            end
            ITT_control = lm(ITT_controls_fml, usedata)
            ITT_control_coeff = coef(ITT_control)[2]
            ITT_control_stderr = stderr(ITT_control)[2]

            # Check if Julia is able to calculate the p-value.
            pval_check = 1
            try
              ccdf(FDist(1, df_residual(ITT_control)), abs2(ITT_control_coeff./ITT_control_stderr))
            catch error
              pval_check = 0
              ITT_control_pval = NA
            end

            if pval_check == 1
              ITT_control_pval = ccdf(FDist(1, df_residual(ITT_control)), abs2(ITT_control_coeff./ITT_control_stderr))
            end

            # Create the data to check the number of observations used in the regression (non-missing Y and X)
            control_list = [y, :R]
            append!(control_list, controls)
            obsdata = usedata[:, control_list]
            for var in control_list
              obsdata = obsdata[!isna(obsdata[var]),:]
            end
            ITT_control_N = size(obsdata, 1)

            # ----------------------------- #
            # ITT with controls and weights #
            # ----------------------------- #
            if in(parse("ipw_$(y)"), names(usedata))

              # Define a weighted y column first as an empty column. (Julia's WLS function is not credible.)
              usedata[:y_w] = 0.0
              usedata[:y_w] = usedata[parse("$(y)")] .* sqrt(usedata[parse("ipw_$(y)")])

              # Define a weighted R column
              usedata[:R_w] = 0.0
              usedata[:R_w] = usedata[:R] .* sqrt(usedata[parse("ipw_$(y)")])

              # Define weighted controls
              controls_w = []
              for c in controls
                usedata[parse("$(c)_w")] = 0.0
                usedata[parse("$(c)_w")] = usedata[parse("$(c)")] .* sqrt(usedata[parse("ipw_$(y)")])
                controls_w = push!(controls_w, parse("$(c)_w"))

              end

              ITT_weight_fml = Formula(:y_w, Expr(:call, :+, :R_w, controls_w...))

              try # try/catch structure handles exceptions
                lm(ITT_weight_fml, usedata)
              # If the regression fails
              catch err
                  push!(outMat["ITT_$(gender)_P$(p)"], [y, draw, ddraw, ITT_none_coeff, ITT_none_pval, ITT_none_N, ITT_control_coeff, ITT_control_pval, ITT_control_N, NA, NA, NA])
                  continue
              end

              ITT_weight = lm(ITT_weight_fml, usedata)
              ITT_weight_coeff = coef(ITT_weight)[2]
              ITT_weight_stderr = stderr(ITT_weight)[2]
              pval_check = 1
              try
                ccdf(FDist(1, df_residual(ITT_weight)), abs2(ITT_weight_coeff./ITT_weight_stderr))
              catch error
                pval_check = 0
                ITT_weight_pval = NA
              end

              if pval_check == 1
                ITT_weight_pval = ccdf(FDist(1, df_residual(ITT_weight)), abs2(ITT_weight_coeff./ITT_weight_stderr))
              end

              # Create the data to check the number of observations used in the regression (non-missing X)
                  wweight_list = [:y_w, :R_w]
                  append!(wweight_list, controls_w)
                  obsdata = usedata[:, wweight_list]
                  for var in wweight_list
                    obsdata = obsdata[!isna(obsdata[var]),:]
                  end
              ITT_weight_N = size(obsdata, 1)

            else
              ITT_weight_fml = Formula(y, Expr(:call, :+, :R, controls...))
              try # try/catch structure handles exceptions
                lm(ITT_weight_fml, usedata)
              # If the regression fails
              catch err
                push!(outMat["ITT_$(gender)_P$(p)"], [y, draw, ddraw, ITT_none_coeff, ITT_none_pval, ITT_none_N, ITT_control_coeff, ITT_control_pval, ITT_control_N, NA, NA, NA])
                continue
              end

              ITT_weight = lm(ITT_weight_fml, usedata)
              ITT_weight_coeff = coef(ITT_weight)[2]
              ITT_weight_stderr = stderr(ITT_weight)[2]
              pval_check = 1
              try
                ccdf(FDist(1, df_residual(ITT_weight)), abs2(ITT_weight_coeff./ITT_weight_stderr))
              catch error
                pval_check = 0
                ITT_weight_pval = NA
              end

              if pval_check == 1
                ITT_weight_pval = ccdf(FDist(1, df_residual(ITT_weight)), abs2(ITT_weight_coeff./ITT_weight_stderr))
              end
              # Create the data to check the number of observations used in the regression (non-missing X)
                woweight_list = [y, :R]
                append!(woweight_list, controls)
                obsdata = usedata[:, woweight_list]
                for var in woweight_list
                  obsdata = obsdata[!isna(obsdata[var]),:]
                end
              ITT_weight_N = size(obsdata, 1)
            end

            # Store estimation results for R (randomization into treatment in ABC) into the output_ITT matrix. push! adds a row to the matrix output_ITT.
            push!(outMat["ITT_$(gender)_P$(p)"], [y, draw, ddraw,
                                                  ITT_none_coeff, ITT_none_pval, ITT_none_N,
                                                  ITT_control_coeff, ITT_control_pval, ITT_control_N,
                                                  ITT_weight_coeff, ITT_weight_pval, ITT_weight_N])


      end
    end
  end

  # Horizontally concatenate items in the dictionary
  if bygender == 1
    Output = hcat(outMat["ITT_male_P0"], outMat["ITT_male_P1"], outMat["ITT_male_P10"], outMat["ITT_female_P0"], outMat["ITT_female_P1"], outMat["ITT_female_P10"], outMat["ITT_pooled_P0"], outMat["ITT_pooled_P1"], outMat["ITT_pooled_P10"])
  elseif bygender == 0
    Output = hcat(outMat["ITT_pooled_P0"], outMat["ITT_pooled_P1"], outMat["ITT_pooled_P10"])
  end
  println("Draw $(draw) DDRAW $(ddraw) OUTPUT SUCCESS")
  return Output
end