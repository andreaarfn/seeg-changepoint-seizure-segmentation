# SEEG Detector GUI

This GUI runs from MATLAB and supports two detection methods:

- **Original detector** — MATLAB sends the selected signal and settings to the existing Python detector in `src/`.
- **Stephen time-frequency** — MATLAB runs the MATLAB workflow built from the four files Dr Thompson provided.

The two methods can be run separately or side by side.

## What you need

- MATLAB
- Signal Processing Toolbox
- Wavelet Toolbox
- Python 3.12
- This full project folder

The project should include:

```text
application/
gui/
src/
requirements.txt
```

## 1. Put the project on your computer

Download or copy the full project folder to a location you can keep, for example:

```text
Documents/seeg-changepoint-seizure-segmentation
```

Do not move individual files out of the project unless needed.

## 2. Set up Python once

The original detector uses Python in the background.

### Check Python

Open Terminal (macOS/Linux) or Command Prompt / PowerShell (Windows):

```bash
python3.12 --version
```

If that does not work, install Python 3.12 first.

### Create a virtual environment

Move to the folder that contains the project.

macOS/Linux:

```bash
cd /path/to/the/folder/containing/the/project
python3.12 -m venv .venv
source .venv/bin/activate
pip install -r seeg-changepoint-seizure-segmentation/requirements.txt
```

Windows:

```powershell
cd C:\path\to\the\folder\containing\the\project
py -3.12 -m venv .venv
.venv\Scripts\activate
pip install -r seeg-changepoint-seizure-segmentation\requirements.txt
```

This only needs to be done once.

## 3. Connect MATLAB to Python

Start MATLAB and move into the project folder:

```matlab
cd('/path/to/seeg-changepoint-seizure-segmentation')

projectRoot = char(pwd);
```

Add the MATLAB application folders:

```matlab
addpath(fullfile(projectRoot, 'application'))
addpath(fullfile(projectRoot, 'application', 'stephen_method'))
```

Point MATLAB to the Python environment Dr Thompson created.

macOS/Linux example:

```matlab
pyenv(Version="/path/to/.venv/bin/python", ...
      ExecutionMode="OutOfProcess")
```

Windows example:

```matlab
pyenv(Version="C:\path\to\.venv\Scripts\python.exe", ...
      ExecutionMode="OutOfProcess")
```

Allow Python to find the local project modules:

```matlab
if count(py.sys.path, projectRoot) == 0
    insert(py.sys.path, int32(0), projectRoot);
end
```

Optional check:

```matlab
api = py.importlib.import_module('gui.api.detection_api');
api.get_defaults();
```

If that runs without an error, the original detector is available.

## 4. Start the GUI

```matlab
app = SEEGDetectionApp;
```

## Using the GUI

### Load data

1. Click **Load File**.
2. Choose a Brainstorm-exported `.mat` file.
3. Choose the recording and channel.
4. Set the analysis start and end times.

If the loaded file contains an LVFA annotation, it is shown separately as a loaded annotation.

### Run mode

There are two options:

- **Analyze full range** — runs the selected method once over the full analysis range.
- **Analyze windows iteratively** — repeats the selected method over smaller time windows.

When iterative analysis is selected, enter:

- **Iteration window (s)** — length of each analysis window
- **Iteration step (s)** — how far forward the next window begins

### Original detector

This uses the existing Python detector in `src/`, mainly:

```text
src/features.py
src/detection.py
```

The GUI lets you adjust the original onset, transition, and end settings and select the features used by the detector.

Full-range results are reported as:

```text
Onset
Transition
End
```

For iterative analysis, the GUI shows the onset, transition, and end returned for each individual window.

### Stephen time-frequency

This uses the MATLAB workflow built from the four supplied files:

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

The GUI provides editable settings for the EMD, wavelet, and changepoint analysis.

Results are shown as generic changepoints:

```text
CP1
CP2
CP3
...
```

These changepoints are not automatically labeled as onset, transition, or end.

### Compare methods

**Compare methods** runs both methods on the same channel and analysis range.

The display controls let you show or hide:

- Original detector markers
- Stephen time-frequency markers
- Loaded LVFA annotation

The results remain separated so it is clear which method produced each output.

## Results

Each method has its own result table.

For full-range analysis, the table shows one row for the selected range.

For iterative analysis, the table shows one row per window.

Use **Expand results** to open a larger, resizable table.

## If MATLAB has trouble finding the app

From the project folder:

```matlab
projectRoot = char(pwd);

addpath(fullfile(projectRoot, 'application'))
addpath(fullfile(projectRoot, 'application', 'stephen_method'))

rehash
```

Check:

```matlab
which SEEGDetectionApp -all
```

## After replacing or editing MATLAB files

Close the existing app and reload the class:

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

## MATLAB toolbox check

If the time-frequency method does not run:

```matlab
which emd
which cwt
which cwtfilterbank
which findchangepts
```

`emd`, `cwt`, and `cwtfilterbank` require the relevant MATLAB signal/wavelet functionality, and `findchangepts` requires Signal Processing Toolbox.

## Notes

- Python is only required for the original detector.
- Stephen's time-frequency method runs in MATLAB.
- `metrics.py` is not part of the current detection path; it is intended for evaluation against known reference times.
- The loaded LVFA annotation comes from the data file and is not generated by either detector.
