# Model fitting

Find parameters to a compartmental model that fit actual data. The
python script expects a CSV file with four columns:

```
date,susceptible,infected,recovered,deceased
```

Columns after the date are expected to be absolute numbers of
respective cases. Scripts in the `data` directory can be used to get
"actual" data, which can be fed into the fitter:

```bash
$> root=`git rev-parse --show-toplevel`
$> $root/data/covid19india/get.sh | python myfit.py
```

Both `get.sh` and `myfit.py` make certain assumptions, for example
about the total population. Either can be run with the help option
(`-h` for Bash, `--help` for Python) for more details.

## References

* [GSoC 2019: Introduction of pymc3.ode API: Non-linear Differential Equations](https://docs.pymc.io/notebooks/ODE_API_introduction.html#Non-linear-Differential-Equations)
* [COVID-19 Study with Epidemiology models](https://www.kaggle.com/volpatto/covid-19-study-with-epidemiology-models)
