# ======================================================================== #
# Prepare data before running estimates on Income
# Original Code in STATA written by Joshua Shea
# Translator: Jessica Yu Kyung Koh
# Date: 07/07/2016
# ======================================================================== #

# Collect variable names to estimate effects for
outcomes = readtable("$(base)/outcomes_p_inc.csv")
outcomes_col = outcomes[:variable]

# Collect names of the outcomes and put them into an array so that we can use in the estimation
outcomelist = []
for outcome in outcomes_col
    outcomelist = append!(outcomelist, [parse(outcome)])
end


# ======================================================================- #

# ----------------------- #
# Bring in pooled results #
# ----------------------- #
p_inc_proj_p = readtable("$results/projections/p_inc_proj_pooled.csv")

# Rename column names to have them start with "c"
colnames = names(p_inc_proj_p)
colnames = deleteat!(colnames, findin(colnames, [:id]))
colnames = deleteat!(colnames, findin(colnames, [:adraw]))
for col in colnames
  newcol = split("$(col)", "x")[2]
	rename!(p_inc_proj_p, col, parse("c$(newcol)_pooled"))
end

# Define "projection" data to merge in gender-specific projections
projections = p_inc_proj_p

# --------------------- #
# Bring in male results #
# --------------------- #
p_inc_proj_m = readtable("$results/projections/p_inc_proj_male.csv")

colnames = names(p_inc_proj_m)
colnames = deleteat!(colnames, findin(colnames, [:id]))
colnames = deleteat!(colnames, findin(colnames, [:adraw]))
for col in colnames
  newcol = split("$(col)", "x")[2]
	rename!(p_inc_proj_m, col, parse("c$(newcol)_male"))
end

# Merge 1:1 id adraw using `projections', nogen
projections = join(projections, p_inc_proj_m, on = [:id, :adraw], kind = :outer)

# ----------------------- #
# Bring in female results #
# ----------------------- #
p_inc_proj_f = readtable("$results/projections/p_inc_proj_female.csv")

colnames = names(p_inc_proj_f)
colnames = deleteat!(colnames, findin(colnames, [:id]))
colnames = deleteat!(colnames, findin(colnames, [:adraw]))
for col in colnames
  newcol = split("$(col)", "x")[2]
	rename!(p_inc_proj_f, col, parse("c$(newcol)_female"))
end

# Merge 1:1 id adraw using `projections', nogen
projections = join(projections, p_inc_proj_f, on = [:id, :adraw], kind = :outer)


# ------------------------------------------------------------------------------ #
# ----------------------------- #
# Merge in age 21 and 30 income #
# ----------------------------- #
abccare = readtable("$data/append-abccare_iv.csv")

# Drop home-visit only kids
abccare = abccare[!((abccare[:R] .== 0) & (abccare[:RV] .== 1)), :]

# Keep only the variables we need for income
keepvar = [:id, :R, :P, :family, :male, :si21y_inc_labor, :si30y_inc_labor, :si34y_time, :abc]
keepvar = append!(keepvar, controls)
keepvar = append!(keepvar, ipwvars_all)
abccare = abccare[:, keepvar]

# for var in keepvar
for var in [:id, :R, :P]
    println("variable: $(var)")
    occurrence = 0  # To convert a column with occurrence > 0 from string to integer (shown below)
    for alphabet in ['a':'z']
     if in(string(".",alphabet), abccare[!isna(abccare[var]), var])
        occurrence = occurrence + 1
      end
      abccare[abccare[var] .== string(".",alphabet), var] = NA
    end

  # Variables that originally contained ".a"&& etc. are saved as string. Now we need to convert string to integers. I could not find destring command for Julia. To be updated later.
   if occurrence > 0 # If a column contains ".a" etc.
    # Create a new column (to be deleted later) that will be filled in with integer values for string column.
   abccare[:var_new] = 0
    # Now run the loop over each row
      for i in 1:length(abccare[var])
        if !isna(abccare[i,var])
          abccare[i,:var_new] = parse(Float64,abccare[i,var])
        else
          abccare[i,:var_new] = NA
        end
      end
    # Now delete the old (string) column and rename the new column to old column
      delete!(abccare, var)
      rename!(abccare, :var_new, var)
  end
end

# ----------------------------------- #
# Define ABC-CARE, ABC, CARE datasets #
# ----------------------------------- #
abccare[isna(abccare[:id]), :id] = 9999

abccare = join(abccare, projections, on = [:id], kind = :outer)

# Organize data
sort(abccare, cols = [:adraw, :id])

# Drop id 64
abccare = abccare[!(abccare[:id] .== 64), :]

# Drop if male == NA
abccare = abccare[!isna(abccare[:male]), :]

# Convert discrete variables to binary (= 1 if greater than median, = 0 otherwise)
global discretized = ["m_iq0y", "m_ed0y", "m_age0y", "hrabc_index", "apgar1", "apgar5", "hh_sibs0y"]

for dvar in discretized
  dvar_p = parse(dvar) # Making "d_var" to :d_var
  med_d = median(abccare[!isna(abccare[dvar_p]), dvar_p]) # take the median of the non-missing values for each variables
  abccare[parse("$(dvar)_dum")] = 0 # Generate a new column for dummy
  abccare[abccare[dvar_p] .> med_d, parse("$(dvar)_dum")] = 1 # Replace dummy column to one if d_var is greater than the median
  abccare[isna(abccare[dvar_p]), parse("$(dvar)_dum")] = NA # Replace values of dunny column if corresponding rwo in original column is NA
end
