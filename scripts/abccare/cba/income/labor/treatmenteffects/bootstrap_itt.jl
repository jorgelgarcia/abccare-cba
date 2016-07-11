# =================================================================== #
# Function to run ITT with Bootstrap (for Parallel Computing Purpose)
# Author: Jessica Yu Kyung Koh
# Created: 06/27/2016
# Edited: 07/08/2016
# =================================================================== #
# Using packages
using DataFrames
using GLM
using StatsBase
using Distances

# Set globals and directories
global current = pwd()
global base =	"$current/../.."
global data = "$current/../../../../../../data/abccare/extensions/cba-iv"
global dofiles = "$current"
global results = "$current/../../rslt"
global atecode = "$current/../../../../juliafunctions"

# Include necessary files
include("$current/driver.jl")
include("$current/data.jl")

# ================================================================ #
# Implement options
# ================================================================ #
# Define the gender loop
global genderloop = ["male", "female", "pooled"]

ITTinitial = Dict()
bsid_orig = Dict()
datainuse = Dict()

# Loop over gender and run estimate
for gender in genderloop

	if gender == "male"
		datainuse["$(gender)"] = abccare[abccare[:male] .== 1, :]
		controlset = [:hrabc_index, :apgar1, :apgar5, :hh_sibs0y, :grandma_county, :has_relatives]
	elseif gender == "female"
		datainuse["$(gender)"] = abccare[abccare[:male] .== 0, :]
		controlset = [:hrabc_index, :apgar1, :apgar5, :hh_sibs0y, :grandma_county, :has_relatives]
	elseif gender == "pooled"
		datainuse["$(gender)"] = abccare
		controlset = [:hrabc_index, :apgar1, :apgar5, :hh_sibs0y, :grandma_county, :has_relatives, :male]
	end

	# Drop "_$(gender)" from column names
	colnames = names(datainuse["$(gender)"])
	for col in colnames
		strver = "$(col)"
		if contains(strver, "_$(gender)")
			splitver = split(strver, "_")
			newname = parse(splitver[1])
			rename!(datainuse["$(gender)"], col, newname)
		end
	end

  # ==================== #
	# Bootstrap esstimates #
	# ==================== #

	# Define the result matrix for the first bootstrap (brep = 0)
	for arep in 0:areps
		datainuse_tmpz = datainuse["$(gender)"]
		datainuse_arepz = datainuse_tmpz[datainuse_tmpz[:adraw] .== arep, :]

		if arep == 0
		  ITTinitial["$(gender)"] = ITTestimator(datainuse_arepz, outcomes, outcomelist, controlset, 0, arep, "no", 0)
	  else
		  ITTinitial_add = ITTestimator(datainuse_arepz, outcomes, outcomelist, controlset, 0, arep, "no", 0)
		  ITTinitial["$(gender)"] = append!(ITTinitial["$(gender)"], ITTinitial_add)
		end
	end
	ITTinitial["$(gender)"] = sort(ITTinitial["$(gender)"], cols = [:draw, :ddraw])
end


	# ================================================= #
	# Define the function for the rest of the bootstrap #
	# ================================================= #
function ITTrun(boots)
	ITTresult = Dict()

	for gender in genderloop

		if gender == "male"
			controlset = [:hrabc_index, :apgar1, :apgar5, :hh_sibs0y, :grandma_county, :has_relatives]
		elseif gender == "female"
			controlset = [:hrabc_index, :apgar1, :apgar5, :hh_sibs0y, :grandma_county, :has_relatives]
		elseif gender == "pooled"
			controlset = [:hrabc_index, :apgar1, :apgar5, :hh_sibs0y, :grandma_county, :has_relatives, :male]
		end

		# Keep the IDs of the original sample to perform ABC boostraps
		bsid_orig_tmp = datainuse["$(gender)"]
		bsid_orig_tmp = bsid_orig_tmp[bsid_orig_tmp[:adraw] .== 0, [:id, :male, :family]]

	  #  bootstrap estimates
	  for brep in 1:boots
	  	if brep != 0
	  	  bsid_draw = bsample(bsid_orig_tmp, :male, :family)
	  	end

	    for arep in 0:areps
				datainuse_tmp = datainuse["$(gender)"]
				datainuse_arep = datainuse_tmp[datainuse_tmp[:adraw] .== arep, :]
				datainuse_act = join(datainuse_arep, bsid_draw, on = [:id, :male, :family], kind = :inner)

				if (brep == 1) & (arep == 0)
					ITTresult["$(gender)"] = ITTestimator(datainuse_act, outcomes, outcomelist, controlset, brep, arep, "no", 0)
				else
					ITTnew = ITTestimator(datainuse_act, outcomes, outcomelist, controlset, brep, arep, "no", 0)
	      	ITTresult["$(gender)"] = append!(ITTresult["$(gender)"], ITTnew)
				end
	    end
	  end

		ITTresult["$(gender)"] = sort(ITTresult["$(gender)"], cols = [:draw, :ddraw])
	end

	return ITTresult
end