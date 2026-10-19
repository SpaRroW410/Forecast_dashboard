# forecastsuite 1.0.3

* Manually specified ARIMA/SARIMA orders now fall back to maximum likelihood
  ("ML") and then conditional sum of squares ("CSS") estimation when the
  default "CSS-ML" optimisation fails, instead of stopping with an `optim()`
  error. This could happen on some platforms (seen on macOS) for seasonal fits.
* The seasonal manual-order test now uses a fixed random seed.

# forecastsuite 1.0.2

* First CRAN release.
