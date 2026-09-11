# SEEG Detector GUI

This MATLAB app lets you load a `.mat` file, choose a recording and channel, set a time range, and run either the original cleveland clinic detector, Dr. Stephen Thompson's time-frequency method, or both side by side.

You can run either method once over the full range or repeatedly across smaller windows.

## What you need

- MATLAB
- Python 3.12
- To copy this repository

The Python side also uses:

```text
numpy
scipy
ruptures
```

The project includes `requirements.txt`, which lists the Python packages needed for the original detector.

## Set up Python

The original detector runs in Python, so MATLAB needs access to a Python environment.

Check that Python 3.12 is installed.

macOS/Linux:

```bash
python3.12 --version
```

Windows:

```powershell
py -3.12 --version
```

Then create a virtual environment and install the Python packages listed in `requirements.txt`.

If you are already inside the project folder, the install command is:

```bash
pip install -r requirements.txt
```

A full setup looks like this.

macOS/Linux:

```bash
cd /path/to/seeg-changepoint-seizure-segmentation
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
```

Windows:

```powershell
cd C:\path\to\seeg-changepoint-seizure-segmentation
py -3.12 -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

`requirements.txt` is already included in the project. The command above installs the packages listed in that file; it does not download the file itself.

You should only need to do this once.

## Connect MATLAB to Python

Open MATLAB and move into the project folder:

```matlab
cd('/path/to/seeg-changepoint-seizure-segmentation')

projectRoot = char(pwd);

addpath(fullfile(projectRoot, 'application'))
addpath(fullfile(projectRoot, 'application', 'stephen_method'))
```

Point MATLAB to the Python environment you created.

macOS/Linux:

```matlab
pyenv(Version="/path/to/.venv/bin/python", ...
      ExecutionMode="OutOfProcess")
```

Windows:

```matlab
pyenv(Version="C:\path\to\.venv\Scripts\python.exe", ...
      ExecutionMode="OutOfProcess")
```

Then add the project folder to Python's path:

```matlab
if count(py.sys.path, projectRoot) == 0
    insert(py.sys.path, int32(0), projectRoot);
end
```

You can test the connection with:

```matlab
api = py.importlib.import_module('gui.api.detection_api');
api.get_defaults();
```

If that runs without an error, MATLAB can reach the original detector.

## Start the app

```matlab
app = SEEGDetectionApp;
```

## How the original detector is connected

The GUI does not rewrite the original cleveland clinic detector. It passes the selected signal and settings into the existing Python code.

```text
SEEGDetectionApp.m
→ gui/api/detection_api.py
→ src/detection.py
→ src/features.py
```

`src/detection.py` runs the three-phase detector and returns onset, transition, and termination.

`src/features.py` contains the seven features used by the detector:

```text
RMS
Theta
Alpha
Beta
Gamma
Line length
Spectral entropy
```

The feature view uses:

```text
SEEGDetectionApp.m
→ gui/api/features_api.py
→ src/features.py
```

So the GUI is still using the original Python feature code rather than a separate MATLAB version.

`src/metrics.py` is not part of the current detection path. It is intended for evaluating detections against known reference times.

## How Stephen's method is connected

For Stephen's method, the GUI follows the workflow from the four MATLAB files Stephen provided:

```text
pipeline_single.m
emd_baseline.m
ds_changepts.m
knee_pt.m
```

The original files are kept in:

```text
application/stephen_method/
```

The four supplied files provide the reference workflow:

- `pipeline_single.m` shows the overall order of the processing steps.
- `emd_baseline.m` separates the slower baseline from the faster signal component.
- `ds_changepts.m` defines the changepoint search, including candidate changepoint counts, residuals, `Statistic='mean'`, and the minimum spacing rule.
- `knee_pt.m` selects the knee of the residual curve, which determines the selected changepoint fit.

`runStephenMethod.m` is the GUI-facing wrapper around this workflow


## Using the GUI

1. Click `Load File`.
2. Select a `.mat` file.
3. Choose the recording.
4. Choose the channel.
5. Set the analysis start and end times.
6. Choose a method.
7. Choose full-range or iterative analysis.
8. Click `Run Detection`.

## Methods

### Original detector

The original detector reports:

```text
Onset
Transition
End
```

The onset, transition, and end settings can be adjusted in the Controls panel.

The feature view lets you show one, several, or all of the original detector features. You can also choose whether to use the onset, transition, or end window settings for the feature calculation.

### Stephen time-frequency

Stephen's method reports generic changepoints:

```text
CP1
CP2
CP3
...
```

These are not automatically labeled as onset, transition, or end.

The changepoint search uses the mean statistic, matching Stephen's original `ds_changepts.m`.

For full-range analysis, the changepoint-selection plot shows the residual curve and selected knee.

For iterative analysis, it shows the changepoint count selected in each window!

### Compare methods

Compare mode runs both methods on the same signal and time range.

The display keeps the outputs separate:

```text
Original detector onset / transition / end
Stephen changepoints
Loaded LVFA annotation (if this was provided in the original code)
```

It also shows both method-specific views:

```text
Original detector - Feature view
Stephen time-frequency - Changepoint selection
```

## Full-range vs iterative processing

`Analyze full range` runs the selected method once over the whole analysis range.

`Analyze windows iteratively` runs the selected method independently in repeated windows.

For iterative analysis, enter:

```text
Iteration window (s)
Iteration step (s)
```

The Results table shows one row for each window.

## Results

The Original Cleveland clinic detector table shows:

```text
Window
Time range
Onset
Transition
End
```

Stephen's table shows:

```text
Window
Time range
CP count
CP times
```

## After replacing or editing MATLAB files

Close the current app and reload the class:

```matlab
if exist('app','var')
    try
        delete(app)
    catch
    end
    clear app
end

clear functions
clear classes
rehash

app = SEEGDetectionApp;
```
