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
global datanpvs    = "$klmmexico/abccare/NPV/"
global collapseprj  = "$klmmexico/abccare/income_projections/"
global dataabccare  = "$klmshare/Data_Central/Abecedarian/data/ABC-CARE/extensions/cba-iv/"
// output
global output      = "$projects/abc-treatmenteffects-finalseason/output/"

// open merged data
cd $dataabccare
use append-abccare_iv.dta, clear
summ R if male == 0
local N0 = r(N)
summ R if male == 1
local N1 = r(N)

// get predicted at age 30
cd $datanpvs
use  labor_r-male-draw.dta, clear
egen labor30 = rowmean(labor_c26 labor_c29 labor_c31 labor_c34)
replace labor30 = labor30/1000
keep adraw r male labor30
gen  perp30 = labor30/.03

foreach sex of numlist 0 1{
foreach num of numlist 0 1{
foreach var in labor perp {

	summ   `var'30 if r   == `num' & male == `sex'
	local  `var'30_`num'_`sex'm  = r(mean)
	local  `var'30_`num'_`sex'sd = r(sd)
	local  `var'30_`num'_`sex'se = ``var'30_`num'_`sex'sd'/(sqrt(`N`sex''))
	
	matrix `var'30_`num'_`sex'  = [``var'30_`num'_`sex'm' \ ``var'30_`num'_`sex'se'] 
}
	// ontaining prediction from plots to get exact.
	matrix per_`num'_`sex'   = [perp30_`num'_`sex']
}
}

// get actuals
cd $datanpvs
use labor_r-male-draw.dta, clear
egen labor_tot = rowtotal(labor_c22-labor_c67), missing
replace labor_tot = labor_tot/1000
keep labor_tot r male
collapse (mean) m = labor_tot (sd) sd = labor_tot, by(r male)
drop if r == .

replace sd = sd/`N1' if male == 1
replace sd = sd/`N0' if male == 0

foreach num of numlist 0 1 {
	foreach sex of numlist 0 1 {
		foreach stat in m sd {
			summ `stat' if r == `num' & male == `sex'
			local `stat'_`num'_`sex' = r(mean)
		}
	matrix npv_`num'_`sex' = [`m_`num'_`sex'' \ `sd_`num'_`sex'']
	}
}

cd $output
use realpredwide.dta, clear
drop real*

foreach num of numlist 0 1 {
	foreach sex of numlist 0 1 {
		foreach stat in pred predse {
			summ `stat'`num' if male == `sex'
			local `stat'_`num'_`sex' = r(mean)
		}
	matrix pred_`num'_`sex' = [`pred_`num'_`sex'' \ `predse_`num'_`sex'']
	}
}


// construct output matrices
foreach sex of numlist 0 1 {
matrix allperp_`sex' = [pred_0_`sex',per_0_`sex',npv_0_`sex',pred_1_`sex',per_1_`sex',npv_1_`sex']
}

matrix allperp = [allperp_0 \ allperp_1]


cd $output
#delimit
outtable using mincerpred, 
mat(allperp) replace nobox center norowlab f(%9.3f);
#delimit cr
