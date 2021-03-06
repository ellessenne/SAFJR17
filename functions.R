### functions for model estimation

# function for estimating a model with a (potentially shared) Gamma frailty term
sim_an_vs_gq_vs_int <- function(df) {
  # seed = 265536720; n_individuals = 25; n_clusters = 15; frailty_theta = 0.25; treatment_effect = -0.5; lambda = 0.5; p = 1
  # packages

  if (!requireNamespace("pacman")) install.packages("pacman")
  pacman::p_load("numDeriv", "minqa", "pracma", "marqLevAlg")

  # starting parameters
  sr = survival::survreg(survival::Surv(t, d) ~ trt, dist = "weibull", data = df)
  # we need to change survreg's parametrisation
  # 1/sr$scale # p, shape
  # exp(sr$coef[1]) ^ (-1/sr$scale) # lambda, scale
  start = c(log(1 / sr$scale), # p
            log(exp(sr$coef[1]) ^ (-1 / sr$scale)), # lambda
            log(1), # theta
            -sr$coef[2] * (1 / sr$scale)) # beta1, coefficient of trt, AFT --> PH
  names(start) <- c("p", "lambda", "theta", "trt")

  n_clusters = unique(df$n_clusters)

  # analytical likelihood
  if (n_clusters == 1) {
    mll = function(pars){
      p = exp(pars[1])
      lambda = exp(pars[2])
      theta = exp(pars[3])
      beta1 = pars[4]
      log_hi = log(p) + log(lambda) + (p - 1) * log(df$t) + df$trt * beta1
      log_Si = -lambda * df$t ^ p * exp(df$trt * beta1)
      ll = sum(df$d * (log_hi) - (theta ^ (-1) + df$d) * log(1 - theta * log_Si)) + sum(log(df$t))
      return(-ll)
    }
  } else {
    mll = function(pars) {
      p = exp(pars[1])
      lambda = exp(pars[2])
      theta = exp(pars[3])
      beta1 = pars[4]
      lli = vapply(1:n_clusters,
                   FUN = function(i) {
                     log_hi = log(p) + log(lambda) + (p - 1) * log(df$t[df$grpid == i]) + df$trt[df$grpid == i] * beta1
                     log_Si = -lambda * df$t[df$grpid == i] ^ p * exp(df$trt[df$grpid == i] * beta1)
                     Di = sum(df$d[df$grpid == i])
                     lli = sum(df$d[df$grpid == i] * (log_hi)) - (theta ^ (-1) + Di) * log(1 - theta * sum(log_Si)) + Di * log(theta) + lgamma(theta ^ (-1) + Di) - lgamma(1 / theta) + sum(log(df$t[df$grpid == i]))
                     return(lli)
                   },
                   FUN.VALUE = numeric(1))
      ll = sum(lli)
      return(-ll)
    }
  }

  # quadrature likelihood with varying number of nodes
  gl_rule_15 = gaussLaguerre(n = 15)
  gl_rule_35 = gaussLaguerre(n = 35)
  gl_rule_75 = gaussLaguerre(n = 75)
  gl_rule_105 = gaussLaguerre(n = 105)

  mll_quad_15 = function(pars) {
    p = exp(pars[1])
    lambda = exp(pars[2])
    theta = exp(pars[3])
    beta1 = pars[4]
    lli = vapply(1:n_clusters,
                 FUN = function(i) {
                   log_hi = log(p) + log(lambda) + (p - 1) * log(df$t[df$grpid == i]) + (df$trt[df$grpid == i] * beta1)
                   log_Si = -lambda * (df$t[df$grpid == i]) ^ p * exp(df$trt[df$grpid == i] * beta1)
                   Di = sum(df$d[df$grpid == i])
                   intgrdq = function(alpha) exp(alpha + Di * log(alpha) + alpha * sum(log_Si) + (1 / theta - 1) * log(alpha) - alpha / theta)
                   vintgrdq = Vectorize(intgrdq)
                   int = sum(gl_rule_15$w * vintgrdq(gl_rule_15$x))
                   ll = sum(df$d[df$grpid == i] * (log_hi)) - lgamma(1 / theta) - (1 / theta) * log(theta) + log(int) + sum(log(df$t[df$grpid == i]))
                   return(ll)},
                 FUN.VALUE = numeric(1))
    ll = sum(lli)
    return(-ll)
  }

  mll_quad_35 = function(pars) {
    p = exp(pars[1])
    lambda = exp(pars[2])
    theta = exp(pars[3])
    beta1 = pars[4]
    lli = vapply(1:n_clusters,
                 FUN = function(i) {
                   log_hi = log(p) + log(lambda) + (p - 1) * log(df$t[df$grpid == i]) + (df$trt[df$grpid == i] * beta1)
                   log_Si = -lambda * (df$t[df$grpid == i]) ^ p * exp(df$trt[df$grpid == i] * beta1)
                   Di = sum(df$d[df$grpid == i])
                   intgrdq = function(alpha) exp(alpha + Di * log(alpha) + alpha * sum(log_Si) + (1 / theta - 1) * log(alpha) - alpha / theta)
                   vintgrdq = Vectorize(intgrdq)
                   int = sum(gl_rule_35$w * vintgrdq(gl_rule_35$x))
                   ll = sum(df$d[df$grpid == i] * (log_hi)) - lgamma(1 / theta) - (1 / theta) * log(theta) + log(int) + sum(log(df$t[df$grpid == i]))
                   return(ll)},
                 FUN.VALUE = numeric(1))
    ll = sum(lli)
    return(-ll)
  }

  mll_quad_75 = function(pars) {
    p = exp(pars[1])
    lambda = exp(pars[2])
    theta = exp(pars[3])
    beta1 = pars[4]
    lli = vapply(1:n_clusters,
                 FUN = function(i) {
                   log_hi = log(p) + log(lambda) + (p - 1) * log(df$t[df$grpid == i]) + (df$trt[df$grpid == i] * beta1)
                   log_Si = -lambda * (df$t[df$grpid == i]) ^ p * exp(df$trt[df$grpid == i] * beta1)
                   Di = sum(df$d[df$grpid == i])
                   intgrdq = function(alpha) exp(alpha + Di * log(alpha) + alpha * sum(log_Si) + (1 / theta - 1) * log(alpha) - alpha / theta)
                   vintgrdq = Vectorize(intgrdq)
                   int = sum(gl_rule_75$w * vintgrdq(gl_rule_75$x))
                   ll = sum(df$d[df$grpid == i] * (log_hi)) - lgamma(1 / theta) - (1 / theta) * log(theta) + log(int) + sum(log(df$t[df$grpid == i]))
                   return(ll)},
                 FUN.VALUE = numeric(1))
    ll = sum(lli)
    return(-ll)
  }

  mll_quad_105 = function(pars) {
    p = exp(pars[1])
    lambda = exp(pars[2])
    theta = exp(pars[3])
    beta1 = pars[4]
    lli = vapply(1:n_clusters,
                 FUN = function(i) {
                   log_hi = log(p) + log(lambda) + (p - 1) * log(df$t[df$grpid == i]) + (df$trt[df$grpid == i] * beta1)
                   log_Si = -lambda * (df$t[df$grpid == i]) ^ p * exp(df$trt[df$grpid == i] * beta1)
                   Di = sum(df$d[df$grpid == i])
                   intgrdq = function(alpha) exp(alpha + Di * log(alpha) + alpha * sum(log_Si) + (1 / theta - 1) * log(alpha) - alpha / theta)
                   vintgrdq = Vectorize(intgrdq)
                   int = sum(gl_rule_105$w * vintgrdq(gl_rule_105$x))
                   ll = sum(df$d[df$grpid == i] * (log_hi)) - lgamma(1 / theta) - (1 / theta) * log(theta) + log(int) + sum(log(df$t[df$grpid == i]))
                   return(ll)},
                 FUN.VALUE = numeric(1))
    ll = sum(lli)
    return(-ll)
  }

  # integrate() likelihood
  mll_int = function(pars) {
    p = exp(pars[1])
    lambda = exp(pars[2])
    theta = exp(pars[3])
    beta1 = pars[4]

    lli = vapply(1:n_clusters,
                 FUN = function(i) {
                   log_hi = log(p) + log(lambda) + (p - 1) * log(df$t[df$grpid == i]) + (df$trt[df$grpid == i] * beta1)
                   log_Si = -lambda * (df$t[df$grpid == i]) ^ p * exp(df$trt[df$grpid == i] * beta1)
                   Di = sum(df$d[df$grpid == i])
                   intgrdq = function(alpha) exp(Di * log(alpha) + alpha * sum(log_Si) + (1 / theta - 1) * log(alpha) - alpha / theta)
                   vintgrdq = Vectorize(intgrdq)
                   int = integrate(f = vintgrdq, lower = 0, upper = Inf)$value
                   ll = sum(df$d[df$grpid == i] * (log_hi)) - lgamma(1 / theta) - (1 / theta) * log(theta) + log(int) + sum(log(df$t[df$grpid == i]))
                   return(ll)},
                 FUN.VALUE = numeric(1))
    ll = sum(lli)
    return(-ll)
  }

  # error object to return in case of optim errors
  error_obj = list(
    par = c(p = NA, lambda = NA, theta = NA, trt = NA),
    value = NA,
    counts = c(`function` = NA, `gradient` = NA),
    convergence = -99,
    message = NULL,
    hessian = matrix(NA, nrow = 4, ncol = 4, dimnames = list(c("p", "lambda", "theta", "trt"), c("p", "lambda", "theta", "trt"))),
    se = c(p = NA, lambda = NA, theta = NA, trt = NA)
  )

  # functions for converting objects from nlm and bobywa to optim's format
  restructure_nlm = function(obj) {
    ret = list(
      par = obj$estimate,
      value = obj$minimum,
      counts = c(`function` = NA, `gradient` = NA),
      convergence = ifelse(obj$code %in% c(1, 2), 0, obj$code),
      message = NULL,
      hessian = obj$hessian,
      se = c(p = NA, lambda = NA, theta = NA, trt = NA))
    return(ret)
  }
  restructure_bobyqa = function(obj, fun) {
    ret = list(
      par = obj$par,
      value = obj$fval,
      counts = c(`function` = NA, `gradient` = NA),
      convergence = obj$ierr,
      message = obj$msg,
      hessian = numDeriv::hessian(fun, obj$par),
      se = c(p = NA, lambda = NA, theta = NA, trt = NA))
    return(ret)
  }

  # optimisation routines
  # fallback order: nlm, BFGS, bobyqa, Nelder-Mead
  o_an = tryCatch(restructure_nlm(nlm(f = mll, p = start, hessian = TRUE)),
                  error = function(cond) {
                    tryCatch(optim(par = start, fn = mll, method = "BFGS", hessian = TRUE),
                             error = function(cond1) {
                               tryCatch(restructure_bobyqa(bobyqa(par = start, fn = mll), fun = mll),
                                        error = function(cond2) {
                                          tryCatch(optim(par = start, fn = mll, method = "Nelder-Mead", hessian = TRUE),
                                                   error = function(cond3) {
                                                     return(error_obj)
                                                     })
                                          })
                               })
                    })
  if (o_an$convergence != 0) {
    o_an = error_obj
  } else {
    o_an$se = tryCatch(sqrt(diag(solve(o_an$hessian))),
                       error = function(cond) {
                         return(c(p = NA, lambda = NA, theta = NA, trt = NA))})
    if (any(is.na(o_an$se))) {
      o_an = error_obj
    }
  }

  o_gq_15 = tryCatch(restructure_nlm(nlm(f = mll_quad_15, p = start, hessian = TRUE)),
                     error = function(cond) {
                       tryCatch(optim(par = start, fn = mll_quad_15, method = "BFGS", hessian = TRUE),
                                error = function(cond1) {
                                  tryCatch(restructure_bobyqa(bobyqa(par = start, fn = mll_quad_15), fun = mll_quad_15),
                                           error = function(cond2) {
                                             tryCatch(optim(par = start, fn = mll_quad_15, method = "Nelder-Mead", hessian = TRUE),
                                                      error = function(cond3) {
                                                        return(error_obj)
                                                        })
                                             })
                                  })
                       })

  if (o_gq_15$convergence != 0) {
    o_gq_15 = error_obj
  } else {
    o_gq_15$se = tryCatch(sqrt(diag(solve(o_gq_15$hessian))),
                          error = function(cond) {
                            return(c(p = NA, lambda = NA, theta = NA, trt = NA))})
    if (any(is.na(o_gq_15$se))) {
      o_gq_15 = error_obj
    }
  }

  o_gq_35 = tryCatch(restructure_nlm(nlm(f = mll_quad_35, p = start, hessian = TRUE)),
                     error = function(cond) {
                       tryCatch(optim(par = start, fn = mll_quad_35, method = "BFGS", hessian = TRUE),
                                error = function(cond1) {
                                  tryCatch(restructure_bobyqa(bobyqa(par = start, fn = mll_quad_35), fun = mll_quad_35),
                                           error = function(cond2) {
                                             tryCatch(optim(par = start, fn = mll_quad_35, method = "Nelder-Mead", hessian = TRUE),
                                                      error = function(cond3) {
                                                        return(error_obj)
                                                        })
                                             })
                                  })
                       })
  if (o_gq_35$convergence != 0) {
    o_gq_35 = error_obj
  } else  {
    o_gq_35$se = tryCatch(sqrt(diag(solve(o_gq_35$hessian))),
                          error = function(cond) {
                            return(c(p = NA, lambda = NA, theta = NA, trt = NA))})
    if (any(is.na(o_gq_35$se))) {
      o_gq_35 = error_obj
    }
  }

  o_gq_75 = tryCatch(restructure_nlm(nlm(f = mll_quad_75, p = start, hessian = TRUE)),
                     error = function(cond) {
                       tryCatch(optim(par = start, fn = mll_quad_75, method = "BFGS", hessian = TRUE),
                                error = function(cond1) {
                                  tryCatch(restructure_bobyqa(bobyqa(par = start, fn = mll_quad_75), fun = mll_quad_75),
                                           error = function(cond2) {
                                             tryCatch(optim(par = start, fn = mll_quad_75, method = "Nelder-Mead", hessian = TRUE),
                                                      error = function(cond3) {
                                                        return(error_obj)
                                                        })
                                             })
                                  })
                       })
  if (o_gq_75$convergence != 0) {
    o_gq_75 = error_obj
  } else {
    o_gq_75$se = tryCatch(sqrt(diag(solve(o_gq_75$hessian))),
                          error = function(cond) {
                            return(c(p = NA, lambda = NA, theta = NA, trt = NA))})
    if (any(is.na(o_gq_75$se))) {
      o_gq_75 = error_obj
    }
  }

  o_gq_105 = tryCatch(restructure_nlm(nlm(f = mll_quad_105, p = start, hessian = TRUE)),
                     error = function(cond) {
                       tryCatch(optim(par = start, fn = mll_quad_105, method = "BFGS", hessian = TRUE),
                                error = function(cond1) {
                                  tryCatch(restructure_bobyqa(bobyqa(par = start, fn = mll_quad_105), fun = mll_quad_105),
                                           error = function(cond2) {
                                             tryCatch(optim(par = start, fn = mll_quad_105, method = "Nelder-Mead", hessian = TRUE),
                                                      error = function(cond3) {
                                                        return(error_obj)
                                                        })
                                             })
                                  })
                       })
  if (o_gq_105$convergence != 0) {
    o_gq_105 = error_obj
  } else {
    o_gq_105$se = tryCatch(sqrt(diag(solve(o_gq_105$hessian))),
                          error = function(cond) {
                            return(c(p = NA, lambda = NA, theta = NA, trt = NA))})
    if (any(is.na(o_gq_105$se))) {
      o_gq_105 = error_obj
    }
  }

  o_int = tryCatch(restructure_nlm(nlm(f = mll_int, p = start, hessian = TRUE)),
                   error = function(cond) {
                     tryCatch(optim(par = start, fn = mll_int, method = "BFGS", hessian = TRUE),
                              error = function(cond1) {
                                tryCatch(restructure_bobyqa(bobyqa(par = start, fn = mll_int), fun = mll_int),
                                         error = function(cond2) {
                                           tryCatch(optim(par = start, fn = mll_int, method = "Nelder-Mead", hessian = TRUE),
                                                    error = function(cond3) {
                                                      return(error_obj)
                                                      })
                                           })
                                })
                     })
  if (o_int$convergence != 0) {
    o_int = error_obj
  } else {
    o_int$se = tryCatch(sqrt(diag(solve(o_int$hessian))),
                           error = function(cond) {
                             return(c(p = NA, lambda = NA, theta = NA, trt = NA))})
    if (any(is.na(o_int$se))) {
      o_int = error_obj
    }
  }

  output = data.frame(n_individuals = unique(df$n_individuals),
                      n_clusters = unique(df$n_clusters),
                      fv_dist = unique(df$fv_dist),
                      fv = unique(df$fv),
                      treatment_effect = unique(df$treatment_effect),
                      lambda = unique(df$lambda),
                      p = unique(df$p),
                      AF_p = o_an$par[1], AF_p_se = o_an$se[1], AF_lambda = o_an$par[2], AF_lambda_se = o_an$se[2], AF_theta = o_an$par[3], AF_theta_se = o_an$se[3], AF_trt = o_an$par[4], AF_trt_se = o_an$se[4], AF_value = -o_an$value, AF_convergence = o_an$convergence,
                      GQ15_p = o_gq_15$par[1], GQ15_p_se = o_gq_15$se[1], GQ15_lambda = o_gq_15$par[2], GQ15_lambda_se = o_gq_15$se[2], GQ15_theta = o_gq_15$par[3], GQ15_theta_se = o_gq_15$se[3], GQ15_trt = o_gq_15$par[4], GQ15_trt_se = o_gq_15$se[4], GQ15_value = -o_gq_15$value, GQ15_convergence = o_gq_15$convergence,
                      GQ35_p = o_gq_35$par[1], GQ35_p_se = o_gq_35$se[1], GQ35_lambda = o_gq_35$par[2], GQ35_lambda_se = o_gq_35$se[2], GQ35_theta = o_gq_35$par[3], GQ35_theta_se = o_gq_35$se[3], GQ35_trt = o_gq_35$par[4], GQ35_trt_se = o_gq_35$se[4], GQ35_value = -o_gq_35$value, GQ35_convergence = o_gq_35$convergence,
                      GQ75_p = o_gq_75$par[1], GQ75_p_se = o_gq_75$se[1], GQ75_lambda = o_gq_75$par[2], GQ75_lambda_se = o_gq_75$se[2], GQ75_theta = o_gq_75$par[3], GQ75_theta_se = o_gq_75$se[3], GQ75_trt = o_gq_75$par[4], GQ75_trt_se = o_gq_75$se[4], GQ75_value = -o_gq_75$value, GQ75_convergence = o_gq_75$convergence,
                      GQ105_p = o_gq_105$par[1], GQ105_p_se = o_gq_105$se[1], GQ105_lambda = o_gq_105$par[2], GQ105_lambda_se = o_gq_105$se[2], GQ105_theta = o_gq_105$par[3], GQ105_theta_se = o_gq_105$se[3], GQ105_trt = o_gq_105$par[4], GQ105_trt_se = o_gq_105$se[4], GQ105_value = -o_gq_105$value, GQ105_convergence = o_gq_105$convergence,
                      IN_p = o_int$par[1], IN_p_se = o_int$se[1], IN_lambda = o_int$par[2], IN_lambda_se = o_int$se[2], IN_theta = o_int$par[3], IN_theta_se = o_int$se[3], IN_trt = o_int$par[4], IN_trt_se = o_int$se[4], IN_value = -o_int$value, IN_convergence = o_int$convergence)
  rownames(output) =  NULL

  # return results
  return(output)
}

# function for estimating a model with a (potentially shared) Normal frailty term
sim_normal_gq <- function(df) {
  # packages
  if (!requireNamespace("pacman")) install.packages("pacman")
  pacman::p_load("fastGHQuad")

  # starting parameters
  sr = survival::survreg(survival::Surv(t, d) ~ trt, dist = "weibull", data = df)
  # we need to change survreg's parametrisation
  # 1/sr$scale # p, shape
  # exp(sr$coef[1]) ^ (-1/sr$scale) # lambda, scale
  start = c(log(1 / sr$scale), # p
            log(exp(sr$coef[1]) ^ (-1 / sr$scale)), # lambda
            log(1), # sigma
            -sr$coef[2] * (1 / sr$scale)) # beta1, coefficient of trt, AFT --> PH
  names(start) <- c("p", "lambda", "sigma", "trt")

  # Gauss-Hermite knots and weights, including adjustment:
  gh_rule_15 = gaussHermiteData(15)
  gh_rule_35 = gaussHermiteData(35)
  gh_rule_75 = gaussHermiteData(75)
  gh_rule_105 = gaussHermiteData(105)

  n_clusters = unique(df$n_clusters)

  # quadrature likelihood with varying number of nodes
  mll_15 = function(pars) {
    p = exp(pars[1])
    lambda = exp(pars[2])
    sigma = exp(pars[3])
    beta1 = pars[4]

    lli = vapply(1:n_clusters,
                 FUN = function(i) {
                   intgrd = function(bi) {
                     log_hi = log(p) + log(lambda) + (p - 1) * log(df$t[df$grpid == i]) + (df$trt[df$grpid == i] * (beta1 + bi))
                     log_Si = -lambda * df$t[df$grpid == i] ^ p * exp(df$trt[df$grpid == i] * (beta1 + bi))
                     # ret = exp(sum(df$d[df$grpid == i] * (log_hi + log(df$t[df$grpid == i]))) + sum(log_Si) - (bi ^ 2) / (2 * sigma ^ 2))
                     ret = exp(sum(df$d[df$grpid == i] * (log_hi)) + sum(log_Si))
                     return(ret)}
                   vintgrd = Vectorize(intgrd)
                   int = sum(gh_rule_15$w / sqrt(pi) * vintgrd(gh_rule_15$x * sqrt(2) * sigma))
                   # ll = -(1/2) * log(2 * (sigma ^ 2) * pi) + log(int)
                   ll = log(int) + sum(log(df$t[df$grpid == i]))
                   return(ll)},
                 FUN.VALUE = numeric(1))
    ll = sum(lli)
    return(-ll)
  }

  mll_35 = function(pars) {
    p = exp(pars[1])
    lambda = exp(pars[2])
    sigma = exp(pars[3])
    beta1 = pars[4]

    lli = vapply(1:n_clusters,
                 FUN = function(i) {
                   intgrd = function(bi) {
                     log_hi = log(p) + log(lambda) + (p - 1) * log(df$t[df$grpid == i]) + (df$trt[df$grpid == i] * (beta1 + bi))
                     log_Si = -lambda * df$t[df$grpid == i] ^ p * exp(df$trt[df$grpid == i] * (beta1 + bi))
                     # ret = exp(sum(df$d[df$grpid == i] * (log_hi + log(df$t[df$grpid == i]))) + sum(log_Si) - (bi ^ 2) / (2 * sigma ^ 2))
                     ret = exp(sum(df$d[df$grpid == i] * (log_hi)) + sum(log_Si))
                     return(ret)}
                   vintgrd = Vectorize(intgrd)
                   int = sum(gh_rule_35$w / sqrt(pi) * vintgrd(gh_rule_35$x * sqrt(2) * sigma))
                   # ll = -(1/2) * log(2 * (sigma ^ 2) * pi) + log(int)
                   ll = log(int) + sum(log(df$t[df$grpid == i]))
                   return(ll)},
                 FUN.VALUE = numeric(1))
    ll = sum(lli)
    return(-ll)
  }

  mll_75 = function(pars) {
    p = exp(pars[1])
    lambda = exp(pars[2])
    sigma = exp(pars[3])
    beta1 = pars[4]

    lli = vapply(1:n_clusters,
                 FUN = function(i) {
                   intgrd = function(bi) {
                     log_hi = log(p) + log(lambda) + (p - 1) * log(df$t[df$grpid == i]) + (df$trt[df$grpid == i] * (beta1 + bi))
                     log_Si = -lambda * df$t[df$grpid == i] ^ p * exp(df$trt[df$grpid == i] * (beta1 + bi))
                     # ret = exp(sum(df$d[df$grpid == i] * (log_hi + log(df$t[df$grpid == i]))) + sum(log_Si) - (bi ^ 2) / (2 * sigma ^ 2))
                     ret = exp(sum(df$d[df$grpid == i] * (log_hi)) + sum(log_Si))
                     return(ret)}
                   vintgrd = Vectorize(intgrd)
                   int = sum(gh_rule_75$w / sqrt(pi) * vintgrd(gh_rule_75$x * sqrt(2) * sigma))
                   # ll = -(1/2) * log(2 * (sigma ^ 2) * pi) + log(int)
                   ll = log(int) + sum(log(df$t[df$grpid == i]))
                   return(ll)},
                 FUN.VALUE = numeric(1))
    ll = sum(lli)
    return(-ll)
  }

  mll_105 = function(pars) {
    p = exp(pars[1])
    lambda = exp(pars[2])
    sigma = exp(pars[3])
    beta1 = pars[4]

    lli = vapply(1:n_clusters,
                 FUN = function(i) {
                   intgrd = function(bi) {
                     log_hi = log(p) + log(lambda) + (p - 1) * log(df$t[df$grpid == i]) + (df$trt[df$grpid == i] * (beta1 + bi))
                     log_Si = -lambda * df$t[df$grpid == i] ^ p * exp(df$trt[df$grpid == i] * (beta1 + bi))
                     # ret = exp(sum(df$d[df$grpid == i] * (log_hi + log(df$t[df$grpid == i]))) + sum(log_Si) - (bi ^ 2) / (2 * sigma ^ 2))
                     ret = exp(sum(df$d[df$grpid == i] * (log_hi)) + sum(log_Si))
                     return(ret)}
                   vintgrd = Vectorize(intgrd)
                   int = sum(gh_rule_105$w / sqrt(pi) * vintgrd(gh_rule_105$x * sqrt(2) * sigma))
                   # ll = -(1/2) * log(2 * (sigma ^ 2) * pi) + log(int)
                   ll = log(int) + sum(log(df$t[df$grpid == i]))
                   return(ll)},
                 FUN.VALUE = numeric(1))
    ll = sum(lli)
    return(-ll)
  }

  # error object to return in case of optim errors
  error_obj = list(
    par = c(p = NA, lambda = NA, sigma = NA, trt = NA),
    value = NA,
    counts = c(`function` = NA, `gradient` = NA),
    convergence = -99,
    message = NULL,
    hessian = matrix(NA, nrow = 4, ncol = 4, dimnames = list(c("p", "lambda", "sigma", "trt"), c("p", "lambda", "sigma", "trt"))),
    se = c(p = NA, lambda = NA, theta = NA, trt = NA)
  )

  # functions for converting objects from nlm and bobyqa to optim's format
  restructure_nlm = function(obj) {
    ret = list(
      par = obj$estimate,
      value = obj$minimum,
      counts = c(`function` = NA, `gradient` = NA),
      convergence = ifelse(obj$code %in% c(1, 2), 0, obj$code),
      message = NULL,
      hessian = obj$hessian,
      se = c(p = NA, lambda = NA, theta = NA, trt = NA))
    return(ret)
  }
  restructure_bobyqa = function(obj, fun) {
    ret = list(
      par = obj$par,
      value = obj$fval,
      counts = c(`function` = NA, `gradient` = NA),
      convergence = obj$ierr,
      message = obj$mess,
      hessian = numDeriv::hessian(fun, obj$par),
      se = c(p = NA, lambda = NA, theta = NA, trt = NA))
    return(ret)
  }

  # optimisation routines
  # fallback order: nlm, BFGS, bobyqa, Nelder-Mead
  o_gq_15 = tryCatch(restructure_nlm(nlm(f = mll_15, p = start, hessian = TRUE)),
                     error = function(cond) {
                       tryCatch(optim(par = start, fn = mll_15, method = "BFGS", hessian = TRUE),
                                error = function(cond1) {
                                  tryCatch(restructure_bobyqa(bobyqa(par = start, fn = mll_15), fun = mll_15),
                                           error = function(cond2) {
                                             tryCatch(optim(par = start, fn = mll_15, method = "Nelder-Mead", hessian = TRUE),
                                                      error = function(cond3) {
                                                        return(error_obj)
                                                        })
                                             })
                                  })
                       })
  if (o_gq_15$convergence != 0) {
    o_gq_15 = error_obj
  } else {
    o_gq_15$se = tryCatch(sqrt(diag(solve(o_gq_15$hessian))),
                          error = function(cond) {
                            return(c(p = NA, lambda = NA, theta = NA, trt = NA))})
    if (any(is.na(o_gq_15$se))) {
      o_gq_15 = error_obj
    }
  }

  o_gq_35 = tryCatch(restructure_nlm(nlm(f = mll_35, p = start, hessian = TRUE)),
                     error = function(cond) {
                       tryCatch(optim(par = start, fn = mll_35, method = "BFGS", hessian = TRUE),
                                error = function(cond1) {
                                  tryCatch(restructure_bobyqa(bobyqa(par = start, fn = mll_35), fun = mll_35),
                                           error = function(cond2) {
                                             tryCatch(optim(par = start, fn = mll_35, method = "Nelder-Mead", hessian = TRUE),
                                                      error = function(cond3) {
                                                        return(error_obj)
                                                        })
                                             })
                                  })
                       })
  if (o_gq_35$convergence != 0) {
    o_gq_35 = error_obj
  } else {
    o_gq_35$se = tryCatch(sqrt(diag(solve(o_gq_35$hessian))),
                          error = function(cond) {
                            return(c(p = NA, lambda = NA, theta = NA, trt = NA))})
    if (any(is.na(o_gq_35$se))) {
      o_gq_35 = error_obj
    }
  }

  o_gq_75 = tryCatch(restructure_nlm(nlm(f = mll_75, p = start, hessian = TRUE)),
                     error = function(cond) {
                       tryCatch(optim(par = start, fn = mll_75, method = "BFGS", hessian = TRUE),
                                error = function(cond1) {
                                  tryCatch(restructure_bobyqa(bobyqa(par = start, fn = mll_75), fun = mll_75),
                                           error = function(cond2) {
                                             tryCatch(optim(par = start, fn = mll_75, method = "Nelder-Mead", hessian = TRUE),
                                                      error = function(cond3) {
                                                        return(error_obj)
                                                        })
                                             })
                                  })
                       })
  if (o_gq_75$convergence != 0) {
    o_gq_75 = error_obj
  } else {
    o_gq_75$se = tryCatch(sqrt(diag(solve(o_gq_75$hessian))),
                          error = function(cond) {
                            return(c(p = NA, lambda = NA, theta = NA, trt = NA))})
    if (any(is.na(o_gq_75$se))) {
      o_gq_75 = error_obj
    }
  }

  o_gq_105 = tryCatch(restructure_nlm(nlm(f = mll_105, p = start, hessian = TRUE)),
                     error = function(cond) {
                       tryCatch(optim(par = start, fn = mll_105, method = "BFGS", hessian = TRUE),
                                error = function(cond1) {
                                  tryCatch(restructure_bobyqa(bobyqa(par = start, fn = mll_105), fun = mll_105),
                                           error = function(cond2) {
                                             tryCatch(optim(par = start, fn = mll_105, method = "Nelder-Mead", hessian = TRUE),
                                                      error = function(cond3) {
                                                        return(error_obj)
                                                        })
                                             })
                                  })
                       })
  if (o_gq_105$convergence != 0) {
    o_gq_105 = error_obj
  } else {
    o_gq_105$se = tryCatch(sqrt(diag(solve(o_gq_105$hessian))),
                          error = function(cond) {
                            return(c(p = NA, lambda = NA, theta = NA, trt = NA))})
    if (any(is.na(o_gq_105$se))) {
      o_gq_105 = error_obj
    }
  }

  output = data.frame(n_individuals = unique(df$n_individuals),
                      n_clusters = unique(df$n_clusters),
                      fv_dist = unique(df$fv_dist),
                      fv = unique(df$fv),
                      treatment_effect = unique(df$treatment_effect),
                      lambda = unique(df$lambda),
                      p = unique(df$p),
                      GQ15_p = o_gq_15$par[1], GQ15_p_se = o_gq_15$se[1], GQ15_lambda = o_gq_15$par[2], GQ15_lambda_se = o_gq_15$se[2], GQ15_sigma = o_gq_15$par[3], GQ15_sigma_se = o_gq_15$se[3], GQ15_trt = o_gq_15$par[4], GQ15_trt_se = o_gq_15$se[4], GQ15_value = -o_gq_15$value, GQ15_convergence = o_gq_15$convergence,
                      GQ35_p = o_gq_35$par[1], GQ35_p_se = o_gq_35$se[1], GQ35_lambda = o_gq_35$par[2], GQ35_lambda_se = o_gq_35$se[2], GQ35_sigma = o_gq_35$par[3], GQ35_sigma_se = o_gq_35$se[3], GQ35_trt = o_gq_35$par[4], GQ35_trt_se = o_gq_35$se[4], GQ35_value = -o_gq_35$value, GQ35_convergence = o_gq_35$convergence,
                      GQ75_p = o_gq_75$par[1], GQ75_p_se = o_gq_75$se[1], GQ75_lambda = o_gq_75$par[2], GQ75_lambda_se = o_gq_75$se[2], GQ75_sigma = o_gq_75$par[3], GQ75_sigma_se = o_gq_75$se[3], GQ75_trt = o_gq_75$par[4], GQ75_trt_se = o_gq_75$se[4], GQ75_value = -o_gq_75$value, GQ75_convergence = o_gq_75$convergence,
                      GQ105_p = o_gq_105$par[1], GQ105_p_se = o_gq_105$se[1], GQ105_lambda = o_gq_105$par[2], GQ105_lambda_se = o_gq_105$se[2], GQ105_sigma = o_gq_105$par[3], GQ105_sigma_se = o_gq_105$se[3], GQ105_trt = o_gq_105$par[4], GQ105_trt_se = o_gq_105$se[4], GQ105_value = -o_gq_105$value, GQ105_convergence = o_gq_105$convergence)
  rownames(output) = NULL

  # return results
  return(output)
}
