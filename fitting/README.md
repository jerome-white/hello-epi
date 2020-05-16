# Model fitting

My attempt at using probabilistic programming to

1. find parameters to a compartmental model that fit actual data
   (`estimate.py`), and

2. use those parameters to forcast trends in each compartment
   (`project.py`).

See the Bash script (`run.sh`) for an example of how to run the
workflow, including gathering actual data and visualizing the final
results. Un-pipe the commands to get a sense for intermediate output.

This is very much a work-in-progress!

## References

* [GSoC 2019: Introduction of pymc3.ode API: Non-linear Differential Equations](https://docs.pymc.io/notebooks/ODE_API_introduction.html#Non-linear-Differential-Equations)
* [COVID-19 Study with Epidemiology models](https://www.kaggle.com/volpatto/covid-19-study-with-epidemiology-models)

## Known issues

Theano may complain about locking issues during projection. This
apparently is a known issue with not concrete solution.
