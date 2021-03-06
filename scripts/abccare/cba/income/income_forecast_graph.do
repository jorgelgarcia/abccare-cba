/*

Project:		ABC CBA
Script:			Graph Income Forecasts
Author:			Anna Ziff (aziff@uchicago.edu)
Original date:	August 29, 2016

*/

// macros
local file_specs	pset1_mset1
/*
Matching control sets (mset)
	1. Baseline controls only (W)
	2. Non-baseline controls only (X)
	3. Full set of controls (W,X)
Projection control sets (pset)
	1. lag, W, X
	2. X, W (not produced yet)
	3. lag, W
	4. W (not produced yet)
	5. X (not produced yet)
	6. lag, X
*/
local transfer_name "Transfer"
local labor_name	"Labor"

local drop0 keep if male == 0
local drop1 keep if male == 1
local drop2

local name0 female
local name1 male
local name2 pooled

global projects : env projects
global klmshare:  env klmshare
global klmmexico: env klmMexico

global dataabccare   = "${klmshare}/Data_Central/Abecedarian/data/ABC-CARE/extensions/cba-iv/"
global data_dir      = "${projects}/abccare-cba/scripts/abccare/cba/income/rslt/projections/`file_specs'"
global incomeresults = "${klmmexico}/abccare/income_projections/current"
global output        = "${projects}/abccare-cba/output/"
global predwide_dir  = "${klmmexico}/abccare/realpredwide/"

// obtained realized and predicted values to insert in plot
cd $predwide_dir
use realpredwide.dta, clear
foreach num of numlist 0 1 {
	foreach cont of numlist 0 1 {
		foreach stat in real pred {
			summ `stat'`cont' if male == `num'
			local `stat'`cont'_s`num' = round(r(mean),.01)
			summ `stat'se`cont' if male == `num' 
			local `stat'se`cont'_s`num' = round(r(mean),.01)
		}
	}
}

// prepare information boxes
# delimit
global box0  text( 10 45
         "Control at a*:"
	 "Forecasted, `pred0_s0' (s.e. `predse0_s0')"
	 "Observed, `real0_s0' (s.e. `realse0_s0')"
	 " "
	 "Treatment at a*:"
         "Forecasted, `pred1_s0' (s.e. `predse1_s0')"
	 "Observed, `real1_s0' (s.e. `realse1_s0')"
         , size(small) place(c) box just(left) margin(l+1 b+1 t+1 r+1) width(35) fcolor(none)); 
# delimit cr

// note hard code of se for treat due to rounding issue in stata
# delimit
global box1  text( 10 42
         "Control at a*:"
	 "Forecasted, `pred0_s1' (s.e. `predse0_s1')"
	 "Observed, `real0_s1' (s.e. `realse0_s1')"
	 " "
	 "Treatment at a*:"
         "Forecasted, `pred1_s1' (s.e. 9.53)"
	 "Observed, `real1_s1' (s.e. `realse1_s1')"
         , size(small) place(c) box just(left) margin(l+1 b+1 t+1 r+1) width(35) fcolor(none)); 
# delimit cr

// prepare data for graphing
cd $dataabccare
use append-abccare_iv.dta, clear

drop if R == 0 & RV == 1
keep id R male si30y_inc_labor

tempfile abccare_data
save `abccare_data'


foreach source in labor /*transfer*/ {

	cd $incomeresults
	insheet using "`source'_proj_combined_`file_specs'_pooled.csv", clear

	local varlist
	local ages
	local se_varlist
	
	forval i = 24/67 {
		capture confirm var v`i'
		if !_rc {
			//local vl`i' : variable label v`i'
			//qui rename v`i' age`vl`i''
			
			rename v`i' age`i'
			
			local varlist `varlist' mean_age`i'
			local ages `ages' `i'
			local se_varlist `varlist' seage`i'=mean_age`i'
			
			
			qui gen mean_age`i' = .
		}
	}
	
	merge m:1 id using `abccare_data', nogen
	sum si30y_inc_labor, detail
	local upper1 = r(p99)
	local lower1 = r(p1)

	drop if si30y_inc_labor > `upper1' //| si30y_inc_labor < `lower1'
	
	sort id adraw
	levelsof id, local(ids)
	

	foreach id in `ids' {
		foreach age in `ages' {
			qui sum age`age' if id == `id'
			local age`age'id`id' = r(mean)
		
			qui replace mean_age`age' = `age`age'id`id'' if id == `id'
		}
	}

	drop age*
	drop if adraw > 0
	
	//merge 1:1 id using `abccare_data', nogen
	drop if id == 9999
	drop adraw si30y_inc_labor
	
		foreach stat in mean semean {
			preserve
				collapse (`stat') `varlist', by(R male)
				foreach age in `ages' {
					qui rename mean_age`age' `stat'_age`age'
				}
			
				tempfile `stat'_collapse
				save ``stat'_collapse'
			restore
		}
		use `mean_collapse', clear
		merge m:m R male using `semean_collapse', nogen
	
		drop if R == .
		gen N = _n
		reshape long mean_age semean_age, i(N) j(age)
	
		gen plus = mean_age + semean_age
		gen minus = mean_age - semean_age
		
		
		
		// limit to 25-60 and scale income
		drop if age > 65  //age < 25 |
		foreach v in mean_age semean_age plus minus {
			replace `v' = `v'/1000
		}
		
		cd $incomeresults
		save `source'_income_collapsed_`file_specs', replace
		cd  $predwide_dir
		append using realpred
		
	// graph
	cd $output
	global y0  0[10]60
	global y1  0[10]60
	local bwidth1 = .65
	local bwidth0 = .65  
	foreach sex of numlist 0 1 {
	
	preserve

		`drop`sex''
	
		local graphregion		graphregion(color(white))
		local yaxis				ytitle("``source'_name' Income (1000s 2014 USD)") ylabel(${y`sex'}, angle(h) glcol(gs14))
		local xaxis				xtitle("Age") xlabel(30 "Interpolation {&larr} a* {&rarr} Extrapolation" 45 "45" 55 "55" 65 "65", grid glcol(gs14))
		local legend			legend(rows(2) order(1 2 3 7 9 8) label(1 "Control Forecasted") label(2 "Treatment Forecasted") label(3 "Forecast +/- s.e.") label(7 "Control Observed") label(8 "Observed +/- s.e.") label(9 "Treatment Observed") size(vsmall))
	
		local t_mean			lcol(gs9) lwidth(1.2)
		local c_mean			lcol(black) lwidth(1.2)
		local t_se				lcol(gs9) lpattern(dash)
		local c_se				lcol(black) lpattern(dash)
		
		// scale of smoothing is strange, but see box for real real values.
		replace real      = real - 3      if `sex' == 0 & R == 0
		replace realplus  = realplus  - 3 if `sex' == 0 & R == 0
		replace realminus = realminus - 3 if `sex' == 0 & R == 0
		
		
		# delimit ; 
		twoway (lowess mean_age age if R == 0, bwidth(`bwidth`sex'') `c_mean')
				(lowess mean_age age if R == 1, bwidth(`bwidth`sex'') `t_mean')
				(lowess plus age if R == 0, bwidth(`bwidth`sex'') `c_se')
				(lowess plus age if R == 1, bwidth(`bwidth`sex'') `t_se')
				(lowess minus age if R == 0, bwidth(`bwidth`sex'') `c_se')
				(lowess minus age if R == 1, bwidth(`bwidth`sex'') `t_se')
				(scatter real  age      if R == 0 & age == 30, mlcolor(black) mfcolor(white) msize(large) msymbol(circle))
				(rcap realplus  realminus age  if R == 0 & age == 30, lcolor(black) lwidth(medthick))
				(scatter real  age      if R == 1 & age == 30, mlcolor(gs9) mfcolor(white) msize(large) msymbol(square))
				(rcap realplus  realminus age  if R == 1 & age == 30, lcolor(gs9) lwidth(medthick))
				,
				${box`sex'}
				`graphregion'
				`xaxis'
				`yaxis'
				`legend';
		graph export "`source'_25-65_`file_specs'_`name`sex''.eps", replace;
		# delimit cr
		
	restore
	
	}
}
