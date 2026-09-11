# SEEG application

Store these files in the `application` folder:

- `SEEGDetectionApp.m`
- `runIterativeChangePoints.m`
- `buildTimeFrequencyMatrix.m`
- `selectKneePoint.m`

The app supports the existing Cleveland Clinic workflow and a MATLAB time-frequency workflow.

The time-frequency path uses `cwt` and `findchangepts`. Replace the placeholder settings with Stephen Thompson's exact MATLAB settings once his original code is available.
