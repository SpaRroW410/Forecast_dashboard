# Column/variable names referenced unquoted inside dplyr/tidyr NSE calls
# (and torch's `self` inside nn_module method bodies) are not real global
# variables, but R CMD check's static analysis cannot tell that apart from
# an actual missing binding. Declaring them here silences the resulting
# "no visible binding for global variable" NOTE without adding an rlang
# dependency just for the `.data` pronoun.
utils::globalVariables(c(
  ".data", ".pop_group", "Metric", "Value", "all_missing", "all_zero",
  "cluster_key", "count", "date_key", "ds", "event_date", "flag",
  "holiday", "lower_window", "md", "n", "pop", "self",
  "time_multiplier", "upper_window", "y", "year"
))
