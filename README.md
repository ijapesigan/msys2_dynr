# Setup dynr in Windows

**Author:** Ivan Jacob Agaloos Pesigan  
**Date:** September 1, 2025

## Download Repository

Clone or download the repository:  
<https://github.com/ijapesigan/msys2_dynr>

---

## Setup in R

### 1. Install MSYS2 toolchain
- Source `000-msys2.R`.  
- This installs [MSYS2](https://www.msys2.org/) and the toolchain required to compile `dynr` models.
- Runs entirely in user space — no administrator rights required.
- **Important:** Restart R before proceeding.

### 2. Install `dynr`
- Source `001-dynr.R`.  
- This installs the CRAN version of the [`dynr`](https://CRAN.R-project.org/package=dynr) package.

### 3. Verify installation
- Source `003-linear-sde.R`.  
- This script checks whether `dynr` and its dependencies were installed correctly.  
- A successful installation will produce output similar to the following:

```r
Coefficients:
         Estimate Std. Error t value ci.lower ci.upper Pr(>|t|)    
spring   -0.10000    0.01583  -6.318 -0.13102 -0.06898   <2e-16 ***
friction -0.20000    0.03598  -5.558 -0.27053 -0.12947   <2e-16 ***
dnoise    1.00000    0.15505   6.450  0.69611  1.30389   <2e-16 ***
mnoise    1.50000    0.08875  16.901  1.32605  1.67395   <2e-16 ***
inipos    0.00000    1.37080   0.000 -2.68671  2.68671      0.5    
---
Signif. codes:  0 ‘***’ 0.001 ‘**’ 0.01 ‘*’ 0.05 ‘.’ 0.1 ‘ ’ 1

-2 log-likelihood value at convergence = 4214.13
AIC = 4224.13
BIC = 4248.67
