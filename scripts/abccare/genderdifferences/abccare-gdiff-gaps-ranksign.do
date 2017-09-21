/*
Project: 	Treatment effects
Date:		April 27, 2017

This file:	Means of control group
*/

clear all
set more off

// parameters
set seed 1
set matsize 11000
global bootstraps 1000
global quantiles 30

// macros
global projects		: env projects
global klmshare		: env klmshare
global klmmexico	: env klmMexico

// filepaths
global data	   	= "$klmshare/Data_Central/Abecedarian/data/ABC-CARE/extensions/cba-iv"
global scripts    	= "$projects/abccare-cba/scripts/"
global output      	= "$projects/abccare-cba/output/"

// data
cd $data
use append-abccare_iv, clear

drop if R == 0 & RV == 1

// variables
cd ${scripts}/abccare/genderdifferences
qui {
include abccare-reverse
include abccare-112-outcomes

foreach c in `categories' {
	if "`c'" != "all" {
		foreach v in ``c'' {
	
		
			if substr("`v'",1,6) == "factor" {
				gen `v' = .
			}
		
			forvalues s = 0/1 {
				local tofactor
				if substr("`v'",1,6) == "factor" {
					foreach v2 in ``v'' {
						sum `v2'
					gen std`v2'`s' = (`v2' - r(mean))/r(sd)
						local tofactor `tofactor' std`v2'`s'
					}
					cap factor `tofactor'
					if !_rc {
						cap predict `v'`s'
						if _rc {
							gen `v'`s' = .
						}
					}
					replace `v' = `v'`s' if male == `s'
				}
			}
		}
	}
}

forvalues b = 0/$bootstraps {
	di "`b'"
	preserve
	
	if `b' > 0 {
		bsample
	}
	
	foreach c in `categories' {
		local counter0 = 0			// use to keep track of number Y_m - Y_f > 0
		local counter1 = 0
		local numvars : word count ``c'' 	// number of variables
	
		foreach v in ``c'' {
			
			forvalues s = 0/1 {
				sum `v' if male == `s' & R == 0  //& dc_mo_pre == 0 //dc_mo_pre > 0 & dc_mo_pre != . //
				local b`v'`s'`b'_R0 = r(mean)
				sum `v' if male == `s' & R == 1
				local b`v'`s'`b'_R1 = r(mean)
				
			}
			if `b`v'1`b'_R0' - `b`v'0`b'_R0' > 0 {
				local counter0 = `counter0' + 1
			}
			if `b`v'1`b'_R1' - `b`v'0`b'_R1' > 0 {
				local counter1 = `counter1' + 1
			}
		}
		forvalues r = 0/1 {
			matrix `c'_prop`r'`b' = `counter`r'' / `numvars'
			matrix `c'_prop`r' = (nullmat(`c'_prop`r') \ `c'_prop`r'`b')
			matrix colnames `c'_prop`r' = `c'`r'
		}
	}
	
	restore
}

// bring to data
local n = 0
local numcats : word count `categories'

foreach c in `categories' {
	forvalues r = 0/1 {
		local n = `n' + 1
		if `n' < 2 * `numcats'  {
			local formatrix `formatrix' `c'_prop`r', 
		}
		else {
			local formatrix `formatrix' `c'_prop`r'
		}
	}
}

matrix all = `formatrix'


clear
svmat all, names(col)
gen draw = _n


// inference
foreach c in `categories' {
	signrank `c'1 = `c'0
	local p`c' = 2 * normprob(-abs(r(z)))
	if `p`c'' <= 0.101 {
		local sig = 1
	}
	else {
		local sig = 0
	}
	
	local p`c' = string(`p`c'', "9.3f")

	qui gen `c'_0_1 = `c'1 - `c'0
	sum `c'_0_1 if draw == 1
	local `c'_0_1 = string(r(mean), "%9.3f")
	
	if `sig' == 1 {
		local `c'_0_1 "\textbf{``c'_0_1'}"
	}
	
	// test if =50
	forvalues r = 0/1 {
		sum `c'`r' if draw == 1
		gen point`c'`r' = r(mean)
		
		sum `c'`r' if draw > 1
		gen emp`c'`r' = r(mean)
		
		gen dm`c'`r' = `c'`r' - emp`c'`r' + 0.5
		
		gen diff1`c'`r' = (dm`c'`r' < point`c'`r') if draw > 1
		gen diff2`c'`r' = (dm`c'`r' > point`c'`r') if draw > 1
		sum diff1`c'`r'
		local p1`c'`r' = r(mean)
		sum diff2`c'`r'
		local p2`c'`r' = r(mean)
	
		sum `c'`r' if draw == 1
		local `c'`r' = r(mean)
		if `p1`c'`r'' <= 0.101 | `p2`c'`r'' <= 0.101 {
			local sig50 = 1
		}
		else {
			local sig50 = 0
		}
		local `c'`r' = string(``c'`r'', "%9.3f")
		if `sig50' == 1 {
			local `c'`r' "\textbf{``c'`r''}"
		}
	}
	
}
}

file open tabfile using "${output}/abccare-proportion-summary-fullR.tex", replace write
file write tabfile "\begin{tabular}{l c c c c}" _n
file write tabfile "\toprule" _n
file write tabfile "Category & \# Outcomes & \mc{2}{c}{Proportion} & Difference \\" _n
file write tabfile "\cmidrule(lr){3-4} \cmidrule(lr){5-5}" _n
file write tabfile "		&			& Treatment & Control & Treatment $- $ Control \\" _n
file write tabfile "\midrule" _n	

foreach c in `categories' {
	local `c'_N : word count ``c''
	
	if "`c'" == "all" {
		file write tabfile "\midrule" _n
	}
	file write tabfile "``c'_name' & ``c'_N' & ``c'1' & ``c'0' & ``c'_0_1' \\" _n
}

file write tabfile "\bottomrule" _n
file write tabfile "\end{tabular}" _n
file write tabfile "% This file generated by: abccare-cba/scripts/abccare/genderdifferences/abccare-gdiff-gaps-ranksign.do" _n
file close tabfile
