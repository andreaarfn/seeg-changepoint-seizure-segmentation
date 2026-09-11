function defaults = getStephenDefaults()
%GETSTEPHENDEFAULTS Default values from Stephen's supplied MATLAB workflow.

defaults = struct();

defaults.emdCutoff = 2;
defaults.lowFreq = 2;
defaults.highFreq = 256;
defaults.voicesPerOctave = 5;
defaults.minChanges = 2;
defaults.maxChanges = 9;
defaults.statistic = "mean";
defaults.minSpacing = 2;

end
