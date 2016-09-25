version 12.0
set more off
clear all
set matsize 11000

/*
Project :       ABC
Description:    plot estimates conditional on IQ
*This version:  April 18, 2016
*This .do file: Jorge L. Garcia
*This project : All except Seong, B. and CC. 
*/

// set environment variables (server)
global erc: env erc
global projects: env projects
global klmshare:  env klmshare
global klmmexico: env klmMexico
global googledrive: env googledrive

// set general locations
// do files
global scripts     = "$projects/abc-treatmenteffects-finalseason/scripts/"
// ready data
global allresults  = "$klmmexico/abccare/irr_ratios/current"
// output
global output      = "$projects/abc-treatmenteffects-finalseason/output/"


// get all baseline types
foreach num of numlist 1(1)11 {
	foreach par in irr ratio {
		cd $allresults/type`num'
		insheet using `par'_mean.csv, clear
		foreach sex in m f p {
			summ v2 if v1 == "`sex'"
			local `par'_mean_type`num'_`sex' = r(mean)
		}
		insheet using `par'_se.csv, clear
		foreach sex in m f p {
			summ v2 if v1 == "`sex'"
			local `par'_se_type`num'_`sex'   = r(mean)
		}
	}
}

// drop murders and rapes from 
foreach num of numlist 2 {
	foreach par in irr ratio {
		cd $allresults/type`num'_nm
		insheet using `par'_mean.csv, clear
		foreach sex in m f p {
			summ v2 if v1 == "`sex'"
			local `par'_mean_type`num'_nm_`sex' = r(mean)
		}
		insheet using `par'_se.csv, clear
		foreach sex in m f p {
			summ v2 if v1 == "`sex'"
			local `par'_se_type`num'_nm_`sex'   = r(mean)
		}
	}
}


// deadweight-loss cases
cd $allresults/sensitivity
foreach par in bc irr {
	insheet using `par'_dwl.csv, clear
	keep if rate == 0 | rate == 1
	foreach var of varlist mean se {
		foreach rate of numlist 0 1 {
			foreach sex in f m p {
				summ `var' if v1 == "`sex'" & rate == `rate'
				local `par'_`var'_rate`rate'_`sex' = r(mean)
			}
		}
	}
}

// discount
cd $allresults/sensitivity
insheet using bc_discount.csv, clear
replace rate = rate*100
keep if rate == 0 | rate == 7
foreach var of varlist mean se {
	foreach rate of numlist 0 7 {
		foreach sex in f m  p {
			summ `var' if v1 == "`sex'" & rate == `rate'
			local bc_`var'_discount`rate'_`sex' = r(mean)
		}
	}
}


// up to age x
cd $allresults/sensitivity
foreach par in ratios irr {
	insheet using `par'_age_type2.csv, clear
	keep if age == 21 | age == 30
	foreach var of varlist mean se {
		foreach age in 21 30 {
			foreach sex in f m p {
				summ `var' if sex == "`sex'" & age == `age'
				local `par'_`var'_age`age'_`sex' = r(mean)
			}
		}
	}
}

// 1.25 parental income (approximate Mincer-type)
cd $allresults/sensitivity
foreach par in bc irr {
	insheet using `par'_factors.csv, clear
	keep if part == "inc_parent" & rate == 1.25
	foreach var of varlist mean se {
		foreach sex in f m p {
			summ `var' if v1 == "`sex'" 
			local `par'_`var'_mincer_`sex' = r(mean)
		}
	}
}

// half crime costs 
cd $allresults/sensitivity
foreach par in bc irr {
	insheet using `par'_factors.csv, clear
	keep if part == "crime" & rate == .5
	foreach var of varlist mean se {
		foreach sex in f m p {
			summ `var' if v1 == "`sex'" 
			local `par'_`var'_crimhalf_`sex' = r(mean)
		}
	}
}

// wage growth 
cd $allresults/sensitivity
foreach par in bc irr {
	insheet using `par'_factors.csv, clear
	keep if part == "inc_labor" & rate == .25
	foreach var of varlist mean se {
		foreach sex in f m p {
			summ `var' if v1 == "`sex'" 
			local `par'_`var'_incgrowth_`sex' = r(mean)
		}
	}
}

// labor income only benefit
cd $allresults/type2
insheet using npv_type2.csv, clear
keep if part == "inc_labor" & (type == "mean" | type == "se")
drop part 
foreach sex in f m p {
	foreach var in mean se {
		summ value if sex == "`sex'" & type == "`var'"
		local bc_`var'_npvinc_`sex' = r(mean)
	}
	local bc_mean_npvinc_`sex' = (`bc_mean_npvinc_`sex'')/((18514) + (18514)/((1 + .03)^2) + (18514)/((1 + .03)^3) + (18514)/((1 + .03)^4) +(18514)/((1 + .03)^5))
	local bc_se_npvinc_`sex'   = (`bc_se_npvinc_`sex'')/(((18514) + (18514)/((1 + .03)^2) + (18514)/((1 + .03)^3) + (18514)/((1 + .03)^4) +(18514)/((1 + .03)^5)))^2

}



// double value of life 
cd $allresults/sensitivity
foreach par in bc irr {
	insheet using `par'_factors.csv, clear
	keep if part == "qaly" & (rate == 2 | rate == 0)
	foreach var of varlist mean se {
		foreach sex in f m p {
			foreach num of numlist 0 2 {
				summ `var' if v1 == "`sex'" & rate == `num'
				local `par'_`var'_valife`num'_`sex' = r(mean)
			}
		}
	}
}

// arrange matrix
// bc/ratio
matrix baselinebc        = [`ratio_mean_type2_f',`ratio_se_type2_f',`ratio_mean_type2_m',`ratio_se_type2_m',`ratio_mean_type2_p',`ratio_se_type2_p']
matrix specification   = [[`ratio_mean_type9_f' \ `ratio_se_type9_f' ],[`ratio_mean_type1_f' \ `ratio_se_type1_f' ],  [`ratio_mean_type9_m' \ `ratio_se_type9_m'], [`ratio_mean_type1_m' \ `ratio_se_type1_m'], [`ratio_mean_type9_p' \ `ratio_se_type9_p'],  [`ratio_mean_type1_p' \ `ratio_se_type1_p']]
matrix predictiontime  = [[`ratios_mean_age21_f' \ `ratios_se_age21_f'], [`ratios_mean_age30_m' \ `ratios_se_age30_m'], [`ratios_mean_age21_m' \ `ratios_se_age21_m'], [`ratios_mean_age30_m' \ `ratios_se_age30_m'], [`ratios_mean_age21_p' \ `ratios_se_age21_p'], [`ratios_mean_age30_p' \ `ratios_se_age30_p']] 
matrix counterfactual  = [[`ratio_mean_type5_f' \ `ratio_se_type5_f' ],[`ratio_mean_type8_f' \ `ratio_se_type8_f' ],  [`ratio_mean_type5_m' \ `ratio_se_type5_m'], [`ratio_mean_type8_m' \ `ratio_se_type8_m'], [`ratio_mean_type5_p' \ `ratio_se_type5_p'],  [`ratio_mean_type8_p' \ `ratio_se_type8_p']]
matrix dwl             = [[`bc_mean_rate0_f' \ `bc_se_rate0_f'], [`bc_mean_rate1_f' \ `bc_se_rate1_f'], [`bc_mean_rate0_m' \ `bc_se_rate0_m'], [`bc_mean_rate1_m' \ `bc_se_rate1_m'],  [`bc_mean_rate0_p' \ `bc_se_rate0_p'], [`bc_mean_rate1_p' \ `bc_se_rate1_p']]
matrix discount        = [[`bc_mean_discount0_f' \ `bc_se_discount0_f'], [`bc_mean_discount7_f' \ `bc_se_discount7_f'], [`bc_mean_discount0_m' \ `bc_se_discount0_m'], [`bc_mean_discount7_m' \ `bc_se_discount7_m'],  [`bc_mean_discount0_p' \ `bc_se_discount0_p'], [`bc_mean_discount7_p' \ `bc_se_discount7_p']]
matrix parental        = [[`bc_mean_mincer_f' \ `bc_se_mincer_f'], [. \ .] , [`bc_mean_mincer_m' \ `bc_se_mincer_m'], [. \ .] , [`bc_mean_mincer_p' \ `bc_se_mincer_p'], [. \ .]]
matrix lincome         = [[`bc_mean_incgrowth_f' \ `bc_se_incgrowth_f'], [`bc_mean_npvinc_f' \ `bc_se_npvinc_f'], [`bc_mean_incgrowth_m' \ `bc_se_incgrowth_m'], [`bc_mean_npvinc_m' \ `bc_se_npvinc_m'], [`bc_mean_incgrowth_p' \ `bc_se_incgrowth_p'], [`bc_mean_npvinc_p' \ `bc_se_npvinc_p']]  
matrix crime           = [[`ratio_mean_type2_nm_f' \ `ratio_se_type2_nm_f'], [`bc_mean_crimhalf_f' \ `bc_se_crimhalf_f'], [`ratio_mean_type2_nm_m' \ `ratio_se_type2_nm_m'], [`bc_mean_crimhalf_m' \ `bc_se_crimhalf_m'], [`ratio_mean_type2_nm_p' \ `ratio_se_type2_nm_p'], [`bc_mean_crimhalf_p' \ `bc_se_crimhalf_p']]
matrix health          = [[`bc_mean_valife0_f' \ `bc_se_valife0_f'], [`bc_mean_valife2_f' \ `bc_se_valife2_f'], [`bc_mean_valife0_m' \ `bc_se_valife0_m'], [`bc_mean_valife2_m' \ `bc_se_valife2_m'], [`bc_mean_valife0_p' \ `bc_se_valife0_p'], [`bc_mean_valife2_p' \ `bc_se_valife2_p']]

matrix allbc = [baselinebc \ specification \ predictiontime \ counterfactual \ dwl \ discount \ parental \ lincome \ crime \ health]
matrix rownames allbc = baseline specification "."  predictiontime "." counterfactual "." dwl "." discount "." parental "." lincome "." crime "." health "."
matrix colnames allbc = pooled pooled males males females females

// irr
matrix baselineirr     = [`irr_mean_type2_f',`irr_se_type2_f',`irr_mean_type2_m',`irr_se_type2_m',`irr_mean_type2_p',`irr_se_type2_p']
matrix specification   = [[`irr_mean_type9_f' \ `irr_se_type9_f' ],[`irr_mean_type1_f' \ `irr_se_type1_f' ],  [`irr_mean_type9_m' \ `irr_se_type9_m'], [`irr_mean_type1_m' \ `irr_se_type1_m'], [`irr_mean_type9_p' \ `irr_se_type9_p'],  [`irr_mean_type1_p' \ `irr_se_type1_p']]
matrix predictiontime  = [[`irr_mean_age21_f' \ `irr_se_age21_f'], [`irr_mean_age30_m' \ `irr_se_age30_m'], [`irr_mean_age21_m' \ `irr_se_age21_m'], [`irr_mean_age30_m' \ `irr_se_age30_m'], [`irr_mean_age21_p' \ `irr_se_age21_p'], [`irr_mean_age30_p' \ `irr_se_age30_p']] 
matrix counterfactual  = [[`irr_mean_type5_f' \ `irr_se_type5_f' ],[`irr_mean_type8_f' \ `irr_se_type8_f' ],  [`irr_mean_type5_m' \ `irr_se_type5_m'], [`irr_mean_type8_m' \ `irr_se_type8_m'], [`irr_mean_type5_p' \ `irr_se_type5_p'],  [`irr_mean_type8_p' \ `irr_se_type8_p']]
matrix dwl             = [[`irr_mean_rate0_f' \ `irr_se_rate0_f'], [`irr_mean_rate1_f' \ `irr_se_rate1_f'], [`irr_mean_rate0_m' \ `irr_se_rate0_m'], [`irr_mean_rate1_m' \ `irr_se_rate1_m'],  [`irr_mean_rate0_p' \ `irr_se_rate0_p'], [`irr_mean_rate1_p' \ `irr_se_rate1_p']]
matrix parental        = [[`irr_mean_mincer_f' \ `irr_se_mincer_f'], [. \ .] , [`irr_mean_mincer_m' \ `irr_se_mincer_m'], [. \ .] , [`irr_mean_mincer_p' \ `irr_se_mincer_p'], [. \ .]]
matrix lincome         = [[`irr_mean_incgrowth_f' \ `irr_se_incgrowth_f'], [. \ .], [`irr_mean_incgrowth_m' \ `irr_se_incgrowth_m'], [. \ .], [`irr_mean_incgrowth_p' \ `irr_se_incgrowth_p'], [. \ .]] 
matrix crime           = [[`irr_mean_type2_nm_f' \ `irr_se_type2_nm_f'], [`irr_mean_crimhalf_f' \ `irr_se_crimhalf_f'], [`irr_mean_type2_nm_m' \ `irr_se_type2_nm_m'], [`irr_mean_crimhalf_m' \ `irr_se_crimhalf_m'], [`irr_mean_type2_nm_p' \ `irr_se_type2_nm_p'], [`irr_mean_crimhalf_p' \ `irr_se_crimhalf_p']]
matrix health          = [[`irr_mean_valife0_f' \ `irr_se_valife0_f'], [`irr_mean_valife2_f' \ `irr_se_valife2_f'], [`irr_mean_valife0_m' \ `irr_se_valife0_m'], [`irr_mean_valife2_m' \ `irr_se_valife2_m'], [`irr_mean_valife0_p' \ `irr_se_valife0_p'], [`irr_mean_valife2_p' \ `irr_se_valife2_p']]

matrix allirr = [baselineirr \ specification \ predictiontime \ counterfactual \ dwl \ parental \ lincome\ crime \ health]

matrix allirr = [baselineirr \ specification \ predictiontime \ counterfactual \ dwl \ parental \ lincome \ crime \ health]
matrix rownames allirr = baseline specification "."  predictiontime "." counterfactual "." dwl "." parental "." lincome "." crime "." health "."
matrix colnames allirr = pooled pooled males males females females

cd $output
putexcel A1 = matrix(allbc)  using allbc_sens, replace
putexcel A1 = matrix(allirr) using allirr_sens, replace