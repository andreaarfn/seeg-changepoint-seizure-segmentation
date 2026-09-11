classdef SEEGDetectionApp < matlab.apps.AppBase

    properties (Access = public)
        UIFigure matlab.ui.Figure
        Grid matlab.ui.container.GridLayout
        LeftPanel matlab.ui.container.Panel
        ControlContent matlab.ui.container.Panel
        ControlGrid matlab.ui.container.GridLayout
        PlotPanel matlab.ui.container.Panel
        ResultsPanel matlab.ui.container.Panel
        DisplayPanel matlab.ui.container.Panel
        OriginalResultsPanel matlab.ui.container.Panel
        StephenResultsPanel matlab.ui.container.Panel
        AnnotationResultsPanel matlab.ui.container.Panel
        OriginalSummaryLabel matlab.ui.control.Label
        StephenSummaryLabel matlab.ui.control.Label
        OriginalResultsTable matlab.ui.control.Table
        StephenResultsTable matlab.ui.control.Table
        OriginalExpandButton matlab.ui.control.Button
        StephenExpandButton matlab.ui.control.Button
        Axes matlab.ui.control.UIAxes
        ResidualAxes matlab.ui.control.UIAxes
        PlotGrid matlab.ui.container.GridLayout
        ResultsGrid matlab.ui.container.GridLayout
        OriginalResultsGrid matlab.ui.container.GridLayout
        StephenResultsGrid matlab.ui.container.GridLayout

        LoadButton matlab.ui.control.Button
        RunButton matlab.ui.control.Button
        ResetButton matlab.ui.control.Button

        FileLabel matlab.ui.control.Label
        RecordingDropDown matlab.ui.control.DropDown
        ChannelDropDown matlab.ui.control.DropDown
        MethodDropDown matlab.ui.control.DropDown
        FsEdit matlab.ui.control.NumericEditField
        StartTimeEdit matlab.ui.control.NumericEditField
        EndTimeEdit matlab.ui.control.NumericEditField

        CCPanel matlab.ui.container.Panel
        TFPanel matlab.ui.container.Panel
        RunModePanel matlab.ui.container.Panel

        OnsetWindow matlab.ui.control.NumericEditField
        OnsetStep matlab.ui.control.NumericEditField
        OnsetPenalty matlab.ui.control.NumericEditField
        TransitionWindow matlab.ui.control.NumericEditField
        TransitionStep matlab.ui.control.NumericEditField
        TransitionPenalty matlab.ui.control.NumericEditField
        TerminationWindow matlab.ui.control.NumericEditField
        TerminationStep matlab.ui.control.NumericEditField
        TerminationPenalty matlab.ui.control.NumericEditField

        RMSCheck matlab.ui.control.CheckBox
        ThetaCheck matlab.ui.control.CheckBox
        AlphaCheck matlab.ui.control.CheckBox
        BetaCheck matlab.ui.control.CheckBox
        GammaCheck matlab.ui.control.CheckBox
        LLCheck matlab.ui.control.CheckBox
        SECheck matlab.ui.control.CheckBox

        RunModeDropDown matlab.ui.control.DropDown
        IterationWindow matlab.ui.control.EditField
        IterationStep matlab.ui.control.EditField
        IterationWindowLabel matlab.ui.control.Label
        IterationStepLabel matlab.ui.control.Label

        StephenEMDCutoff matlab.ui.control.NumericEditField
        StephenLowFreq matlab.ui.control.NumericEditField
        StephenHighFreq matlab.ui.control.NumericEditField
        StephenVoices matlab.ui.control.NumericEditField
        StephenMinChanges matlab.ui.control.NumericEditField
        StephenMaxChanges matlab.ui.control.NumericEditField
        StephenStatistic matlab.ui.control.DropDown
        StephenMinSpacing matlab.ui.control.NumericEditField

        OnsetResult matlab.ui.control.Label
        TransitionResult matlab.ui.control.Label
        TerminationResult matlab.ui.control.Label
        TFResult matlab.ui.control.Label
        StatusLabel matlab.ui.control.Label

        ShowOriginalCheck matlab.ui.control.CheckBox
        ShowStephenCheck matlab.ui.control.CheckBox
        ShowLVFACheck matlab.ui.control.CheckBox
        LoadedAnnotationResult matlab.ui.control.Label

    end

    properties (Access = private)
        Data
        Signal
        Time
        Fs = 1000
        LVFATimes = []

        LastOriginalOnset = NaN
        LastOriginalTransition = NaN
        LastOriginalEnd = NaN
        LastOriginalOnsets = []
        LastOriginalTransitions = []
        LastOriginalEnds = []
        LastStephenTimes = []
        OriginalResultData = cell(0,5)
        StephenResultData = cell(0,4)
    end

    methods (Access = private)

        function startupFcn(app)
            app.populateDefaults();
            app.updateMethodPanels();
            app.updateResultsLayout();
            app.updateRunModeControls();
            app.StatusLabel.Text = "Load a file to begin.";
        end

        function populateDefaults(app)
            % Read the original detector defaults from the Python backend.
            % Fall back to the repository defaults if Python is not available yet.
            try
                api = py.importlib.import_module('gui.api.detection_api');
                defaults = api.get_defaults();

                onset = defaults{'onset'};
                transition = defaults{'transition'};
                termination = defaults{'termination'};

                app.OnsetWindow.Value = double(onset{'window_size'}) * 1000 / app.Fs;
                app.OnsetStep.Value = double(onset{'step'}) * 1000 / app.Fs;
                app.OnsetPenalty.Value = double(onset{'penalty'});

                app.TransitionWindow.Value = double(transition{'window_size'}) * 1000 / app.Fs;
                app.TransitionStep.Value = double(transition{'step'}) * 1000 / app.Fs;
                app.TransitionPenalty.Value = double(transition{'penalty'});

                app.TerminationWindow.Value = double(termination{'window_size'}) * 1000 / app.Fs;
                app.TerminationStep.Value = double(termination{'step'}) * 1000 / app.Fs;
                app.TerminationPenalty.Value = double(termination{'penalty'});
            catch
                app.OnsetWindow.Value = 1000;
                app.OnsetStep.Value = 150;
                app.OnsetPenalty.Value = 11;

                app.TransitionWindow.Value = 700;
                app.TransitionStep.Value = 130;
                app.TransitionPenalty.Value = 7;

                app.TerminationWindow.Value = 1000;
                app.TerminationStep.Value = 200;
                app.TerminationPenalty.Value = 10;
            end

            app.RMSCheck.Value = true;
            app.ThetaCheck.Value = true;
            app.AlphaCheck.Value = true;
            app.BetaCheck.Value = true;
            app.GammaCheck.Value = true;
            app.LLCheck.Value = true;
            app.SECheck.Value = true;

            app.RunModeDropDown.Value = "Analyze full range";
            app.IterationWindow.Value = "";
            app.IterationStep.Value = "";


            app.ShowOriginalCheck.Value = false;
            app.ShowStephenCheck.Value = false;
            app.ShowLVFACheck.Value = true;

            s = getStephenDefaults();
            app.StephenEMDCutoff.Value = s.emdCutoff;
            app.StephenLowFreq.Value = s.lowFreq;
            app.StephenHighFreq.Value = s.highFreq;
            app.StephenVoices.Value = s.voicesPerOctave;
            app.StephenMinChanges.Value = s.minChanges;
            app.StephenMaxChanges.Value = s.maxChanges;
            app.StephenStatistic.Value = s.statistic;
            app.StephenMinSpacing.Value = s.minSpacing;
        end


        function showOriginalResultsTable(app)
            app.OriginalResultsTable.Visible = "on";
            app.OriginalExpandButton.Visible = "on";
            app.OriginalResultsGrid.RowHeight = {34, 205, '1x', 38};
        end

        function showStephenResultsTable(app)
            app.StephenResultsTable.Visible = "on";
            app.StephenExpandButton.Visible = "on";
            app.StephenResultsGrid.RowHeight = {34, 205, '1x', 38};
        end

        function hideResultTables(app)
            app.OriginalResultsTable.Visible = "off";
            app.StephenResultsTable.Visible = "off";
            app.OriginalExpandButton.Visible = "off";
            app.StephenExpandButton.Visible = "off";

            app.OriginalResultsGrid.RowHeight = {34, 0, 0, 0};
            app.StephenResultsGrid.RowHeight = {34, 0, 0, 0};
        end

        function onExpandOriginalResults(app, ~, ~)
            app.openExpandedResults( ...
                "Original detector results", ...
                app.OriginalResultsTable.ColumnName, ...
                app.OriginalResultData, ...
                app.OriginalSummaryLabel.Text);
        end

        function onExpandStephenResults(app, ~, ~)
            app.openExpandedResults( ...
                "Stephen time-frequency results", ...
                app.StephenResultsTable.ColumnName, ...
                app.StephenResultData, ...
                app.StephenSummaryLabel.Text);
        end

        function openExpandedResults(~, titleText, columnNames, tableData, summaryText)
            fig = uifigure( ...
                "Name", titleText, ...
                "Position", [180 140 980 520], ...
                "Resize", "on");

            grid = uigridlayout(fig, [2 1]);
            grid.RowHeight = {52, '1x'};
            grid.Padding = [16 16 16 16];
            grid.RowSpacing = 12;

            uilabel(grid, ...
                "Text", summaryText, ...
                "FontSize", 14, ...
                "FontWeight", "bold", ...
                "WordWrap", "on");

            t = uitable(grid, ...
                "Data", tableData, ...
                "ColumnName", columnNames, ...
                "RowName", []);
            t.ColumnWidth = "auto";
        end

        function value = displayTime(~, t)
            if isempty(t) || ~isfinite(t)
                value = "N/A";
            else
                value = sprintf("%.2f s", t);
            end
        end

        function rangeText = displayRange(~, startTime, endTime)
            rangeText = sprintf("%.2f–%.2f s", startTime, endTime);
        end

        function onDisplayChanged(app, ~, ~)
            app.refreshSignalDisplay();
        end

        function refreshSignalDisplay(app)
            app.plotSignal();

            if isempty(app.Signal)
                return
            end

            if isfinite(app.StartTimeEdit.Value) && isfinite(app.EndTimeEdit.Value) && ...
                    app.StartTimeEdit.Value < app.EndTimeEdit.Value
                app.markAnalysisRange();
            end

            method = string(app.MethodDropDown.Value);

            if app.ShowOriginalCheck.Value && ...
                    (method == "Original detector" || method == "Compare methods")

                if ~isempty(app.LastOriginalOnsets)
                    for k = 1:numel(app.LastOriginalOnsets)
                        app.addMarker(app.LastOriginalOnsets(k), "O" + k, "original");
                    end
                    for k = 1:numel(app.LastOriginalTransitions)
                        app.addMarker(app.LastOriginalTransitions(k), "T" + k, "original");
                    end
                    for k = 1:numel(app.LastOriginalEnds)
                        app.addMarker(app.LastOriginalEnds(k), "E" + k, "original");
                    end
                else
                    app.addMarker(app.LastOriginalOnset, "Onset", "original");
                    app.addMarker(app.LastOriginalTransition, "Transition", "original");
                    app.addMarker(app.LastOriginalEnd, "End", "original");
                end
            end

            if app.ShowStephenCheck.Value && ...
                    (method == "Stephen time-frequency" || method == "Compare methods")
                for k = 1:numel(app.LastStephenTimes)
                    app.addMarker(app.LastStephenTimes(k), "CP" + k, "stephen");
                end
            end
        end

        function updateResultsLayout(app)
            method = string(app.MethodDropDown.Value);

            if method == "Original detector"
                app.OriginalResultsPanel.Visible = "on";
                app.StephenResultsPanel.Visible = "off";
                app.AnnotationResultsPanel.Visible = "on";
                app.ResultsGrid.ColumnWidth = {'2x', 0, '1x'};

            elseif method == "Stephen time-frequency"
                app.OriginalResultsPanel.Visible = "off";
                app.StephenResultsPanel.Visible = "on";
                app.AnnotationResultsPanel.Visible = "on";
                app.ResultsGrid.ColumnWidth = {0, '2x', '1x'};

            else
                app.OriginalResultsPanel.Visible = "on";
                app.StephenResultsPanel.Visible = "on";
                app.AnnotationResultsPanel.Visible = "on";
                app.ResultsGrid.ColumnWidth = {'1.35x', '1.35x', '0.7x'};
            end
        end

        function onLoad(app, ~, ~)
            [file, folder] = uigetfile("*.mat", "Choose SEEG file");
            if isequal(file, 0)
                return
            end

            try
                app.Data = load(fullfile(folder, file));
                app.FileLabel.Text = file;

                names = app.findRecordings();
                if isempty(names)
                    error("No recording structures with F and Time were found.");
                end

                app.RecordingDropDown.Items = names;
                app.RecordingDropDown.Value = names{1};

                app.loadChannelNames();
                app.readSelectedSignal();
                app.readLVFA();
                app.setFullRange();
                app.plotSignal();
                app.clearResults();

                app.StatusLabel.Text = "File loaded.";
            catch ME
                app.StatusLabel.Text = "Could not load file.";
                uialert(app.UIFigure, ME.message, "File issue");
            end
        end

        function names = findRecordings(app)
            fields = fieldnames(app.Data);
            names = {};

            for k = 1:numel(fields)
                value = app.Data.(fields{k});
                if isstruct(value) && isfield(value, "F") && isfield(value, "Time")
                    names{end+1} = fields{k}; %#ok<AGROW>
                end
            end
        end

        function loadChannelNames(app)
            rec = app.Data.(app.RecordingDropDown.Value);
            nChannels = size(rec.F, 1);
            names = strings(1, nChannels);

            if isfield(app.Data, "chans") && isfield(app.Data.chans, "Channel")
                channels = app.Data.chans.Channel;

                for k = 1:min(numel(channels), nChannels)
                    if isfield(channels(k), "Name") && ~isempty(channels(k).Name)
                        names(k) = string(channels(k).Name);
                    elseif isfield(channels(k), "Comment") && ~isempty(channels(k).Comment)
                        names(k) = string(channels(k).Comment);
                    end
                end
            end

            for k = 1:nChannels
                if strlength(names(k)) == 0
                    names(k) = "Channel " + k;
                end
            end

            app.ChannelDropDown.Items = cellstr(names);
            app.ChannelDropDown.ItemsData = 1:nChannels;
            app.ChannelDropDown.Value = 1;
        end

        function onRecordingChanged(app, ~, ~)
            app.loadChannelNames();
            app.readSelectedSignal();
            app.readLVFA();
            app.setFullRange();
            app.plotSignal();
            app.clearResults();
        end

        function onChannelChanged(app, ~, ~)
            app.readSelectedSignal();
            app.plotSignal();
            app.clearResults();
        end

        function onMethodChanged(app, ~, ~)
            app.updateMethodPanels();
            app.updateResultsLayout();

            app.ShowOriginalCheck.Value = false;
            app.ShowStephenCheck.Value = false;

            app.clearResults();
            cla(app.ResidualAxes);
            app.refreshSignalDisplay();
        end


        function onRunModeChanged(app, ~, ~)
            app.updateRunModeControls();
        end

        function updateRunModeControls(app)
            iterative = string(app.RunModeDropDown.Value) == "Analyze windows iteratively";

            app.RunModePanel.Visible = "on";

            if iterative
                app.IterationWindowLabel.Visible = "on";
                app.IterationWindow.Visible = "on";
                app.IterationStepLabel.Visible = "on";
                app.IterationStep.Visible = "on";

                currentRows = app.ControlGrid.RowHeight;
                currentRows{9} = 150;
                app.ControlGrid.RowHeight = currentRows;
            else
                app.IterationWindowLabel.Visible = "off";
                app.IterationWindow.Visible = "off";
                app.IterationStepLabel.Visible = "off";
                app.IterationStep.Visible = "off";

                currentRows = app.ControlGrid.RowHeight;
                currentRows{9} = 72;
                app.ControlGrid.RowHeight = currentRows;
            end
        end

        function updateMethodPanels(app)
            method = string(app.MethodDropDown.Value);
            if string(app.RunModeDropDown.Value) == "Analyze windows iteratively"
                runModeHeight = 150;
            else
                runModeHeight = 72;
            end

            baseRows = {48, 32, 42, 42, 42, 32, 42, 42, runModeHeight};

            if method == "Original detector"
                app.CCPanel.Visible = "on";
                app.TFPanel.Visible = "off";

                app.ShowOriginalCheck.Visible = "on";
                app.ShowOriginalCheck.Enable = "on";
                app.ShowStephenCheck.Visible = "off";
                app.ShowLVFACheck.Visible = "on";

                app.ResidualAxes.Visible = "off";
                app.PlotGrid.RowHeight = {44, '1x', 0};
                app.ControlGrid.RowHeight = [baseRows, {560, 0, 48, 80}];

            elseif method == "Stephen time-frequency"
                app.CCPanel.Visible = "off";
                app.TFPanel.Visible = "on";

                app.ShowOriginalCheck.Visible = "off";
                app.ShowStephenCheck.Visible = "on";
                app.ShowStephenCheck.Enable = "on";
                app.ShowLVFACheck.Visible = "on";

                app.ResidualAxes.Visible = "on";
                app.PlotGrid.RowHeight = {44, '2x', '1x'};
                app.ControlGrid.RowHeight = [baseRows, {0, 390, 48, 80}];

            else
                app.CCPanel.Visible = "on";
                app.TFPanel.Visible = "on";

                app.ShowOriginalCheck.Visible = "on";
                app.ShowOriginalCheck.Enable = "on";
                app.ShowStephenCheck.Visible = "on";
                app.ShowStephenCheck.Enable = "on";
                app.ShowLVFACheck.Visible = "on";

                app.ResidualAxes.Visible = "on";
                app.PlotGrid.RowHeight = {44, '2x', '1x'};
                app.ControlGrid.RowHeight = [baseRows, {560, 390, 48, 80}];
            end
        end

        function readSelectedSignal(app)
            rec = app.Data.(app.RecordingDropDown.Value);
            F = double(rec.F);
            t = double(rec.Time(:));
            channelIndex = app.ChannelDropDown.Value;

            if size(F, 2) == numel(t)
                app.Signal = F(channelIndex, :)';
            elseif size(F, 1) == numel(t)
                app.Signal = F(:, channelIndex);
            else
                error("Signal dimensions do not match the Time vector.");
            end

            app.Time = t;

            if numel(t) > 1
                dt = median(diff(t));
                if isfinite(dt) && dt > 0
                    app.Fs = 1 / dt;
                    app.FsEdit.Value = app.Fs;

                    if app.StephenHighFreq.Value > app.Fs / 2
                        app.StephenHighFreq.Value = app.Fs / 2;
                    end
                end
            end
        end

        function readLVFA(app)
            app.LVFATimes = [];
            rec = app.Data.(app.RecordingDropDown.Value);

            if ~isfield(rec, "Events") || isempty(rec.Events)
                return
            end

            for k = 1:numel(rec.Events)
                e = rec.Events(k);

                if isfield(e, "label") && strcmpi(string(e.label), "LVFA") && ...
                        isfield(e, "times") && ~isempty(e.times)
                    app.LVFATimes = [app.LVFATimes; double(e.times(:))]; %#ok<AGROW>
                end
            end

            app.LVFATimes = unique(app.LVFATimes);
        end

        function setFullRange(app)
            if isempty(app.Time)
                return
            end

            app.StartTimeEdit.Value = app.Time(1);
            app.EndTimeEdit.Value = app.Time(end);
        end

        function [signalSegment, timeSegment] = selectedRange(app)
            startTime = app.StartTimeEdit.Value;
            endTime = app.EndTimeEdit.Value;

            if ~isfinite(startTime) || ~isfinite(endTime)
                error("Start and end times must be finite.");
            end

            if startTime >= endTime
                error("Start time must be earlier than end time.");
            end

            if startTime < app.Time(1) || endTime > app.Time(end)
                error("Analysis range must stay inside the loaded recording.");
            end

            mask = app.Time >= startTime & app.Time <= endTime;

            if nnz(mask) < 3
                error("The selected analysis range is too short.");
            end

            signalSegment = app.Signal(mask);
            timeSegment = app.Time(mask);
        end

        function onRun(app, ~, ~)
            if isempty(app.Signal)
                uialert(app.UIFigure, "Load a signal first.", "No signal");
                return
            end

            try
                [signalSegment, timeSegment] = app.selectedRange();

                app.StatusLabel.Text = "Running detection...";
                drawnow;

                app.plotSignal();
                app.markAnalysisRange();

                method = string(app.MethodDropDown.Value);
                app.updateResultsLayout();

                if method == "Original detector"
                    app.ShowOriginalCheck.Value = false;
                elseif method == "Stephen time-frequency"
                    app.ShowStephenCheck.Value = false;
                else
                    app.ShowOriginalCheck.Value = false;
                    app.ShowStephenCheck.Value = false;
                end

                app.refreshSignalDisplay();

                if method == "Original detector"
                    app.runCC(signalSegment, timeSegment);
                elseif method == "Stephen time-frequency"
                    app.runTF(signalSegment, timeSegment);
                else
                    app.runCC(signalSegment, timeSegment);
                    app.runTF(signalSegment, timeSegment);
                end

                app.StatusLabel.Text = "Detection complete.";
            catch ME
                app.StatusLabel.Text = "Detection failed.";
                uialert(app.UIFigure, ME.message, "Detection error");
            end
        end

        function runCC(app, signalSegment, timeSegment)
            params = app.buildParams();

            if string(app.RunModeDropDown.Value) == "Analyze full range"
                api = py.importlib.import_module('gui.api.detection_api');
                py.importlib.reload(api);

                result = api.detect_from_signal( ...
                    py.numpy.array(signalSegment), ...
                    app.Fs, ...
                    params, ...
                    true);

                seconds = result{'detected_seconds'};

                onset = app.toAbsoluteTime(app.pyValue(seconds{'onset'}), timeSegment);
                transition = app.toAbsoluteTime(app.pyValue(seconds{'transition'}), timeSegment);
                ending = app.toAbsoluteTime(app.pyValue(seconds{'termination'}), timeSegment);

                app.LastOriginalOnset = onset;
                app.LastOriginalTransition = transition;
                app.LastOriginalEnd = ending;
                app.LastOriginalOnsets = [];
                app.LastOriginalTransitions = [];
                app.LastOriginalEnds = [];

                app.ShowOriginalCheck.Enable = "on";
                app.ShowOriginalCheck.Value = true;
                if app.ShowOriginalCheck.Value
                    app.addMarker(onset, "Onset", "original");
                    app.addMarker(transition, "Transition", "original");
                    app.addMarker(ending, "End", "original");
                end

                app.OnsetResult.Text = app.formatTime("Onset", onset);
                app.TransitionResult.Text = app.formatTime("Transition", transition);
                app.TerminationResult.Text = app.formatTime("End", ending);

                app.OriginalSummaryLabel.Text = "Full-range result";
                app.OriginalResultData = { ...
                    'Full range', ...
                    char(app.displayRange(timeSegment(1), timeSegment(end))), ...
                    char(app.displayTime(onset)), ...
                    char(app.displayTime(transition)), ...
                    char(app.displayTime(ending))};
                app.OriginalResultsTable.Data = app.OriginalResultData;
                app.showOriginalResultsTable();
                return
            end

            scanWindow = str2double(string(app.IterationWindow.Value));
            scanStep = str2double(string(app.IterationStep.Value));

            if ~isfinite(scanWindow) || ~isfinite(scanStep) || ...
                    scanWindow <= 0 || scanStep <= 0
                error("Enter positive Iteration window and Iteration step values.");
            end

            duration = timeSegment(end) - timeSegment(1);
            if scanWindow > duration
                error("Iteration window cannot be longer than the selected analysis range.");
            end

            result = runIterativeDefaultDetection( ...
                signalSegment, ...
                timeSegment, ...
                app.Fs, ...
                params, ...
                scanWindow, ...
                scanStep);

            app.ShowOriginalCheck.Value = false;
            app.ShowStephenCheck.Value = false;
            app.ShowOriginalCheck.Enable = "on";
            app.ShowStephenCheck.Enable = "on";

            app.LastOriginalOnset = NaN;
            app.LastOriginalTransition = NaN;
            app.LastOriginalEnd = NaN;
            app.LastOriginalOnsets = result.onsets(:);
            app.LastOriginalTransitions = result.transitions(:);
            app.LastOriginalEnds = result.ends(:);
            app.ShowOriginalCheck.Enable = "on";
            app.ShowOriginalCheck.Value = true;

            if app.ShowOriginalCheck.Value
                for k = 1:numel(result.onsets)
                    app.addMarker(result.onsets(k), "O" + k, "original");
                end

                for k = 1:numel(result.transitions)
                    app.addMarker(result.transitions(k), "T" + k, "original");
                end

                for k = 1:numel(result.ends)
                    app.addMarker(result.ends(k), "E" + k, "original");
                end
            end

            nWindows = result.windowCount;
            nOnset = sum(arrayfun(@(x) isfinite(x.onset), result.windowResults));
            nTransition = sum(arrayfun(@(x) isfinite(x.transition), result.windowResults));
            nEnd = sum(arrayfun(@(x) isfinite(x.endTimeDetected), result.windowResults));

            app.OnsetResult.Text = "Onset returned: " + nOnset + " / " + nWindows + " windows";
            app.TransitionResult.Text = "Transition returned: " + nTransition + " / " + nWindows + " windows";
            app.TerminationResult.Text = "End returned: " + nEnd + " / " + nWindows + " windows";

            app.OriginalSummaryLabel.Text = ...
                nWindows + " windows | " + ...
                sprintf("%.1f s window | %.1f s step", ...
                    result.scanWindowSeconds, result.scanStepSeconds);

            tableData = cell(nWindows, 5);
            for w = 1:nWindows
                wr = result.windowResults(w);
                tableData{w,1} = char("W" + w);
                tableData{w,2} = char(app.displayRange(wr.startTime, wr.endTime));
                tableData{w,3} = char(app.displayTime(wr.onset));
                tableData{w,4} = char(app.displayTime(wr.transition));
                tableData{w,5} = char(app.displayTime(wr.endTimeDetected));
            end

            app.OriginalResultData = tableData;
            app.OriginalResultsTable.Data = tableData;
            app.showOriginalResultsTable();
        end

        function runTF(app, signalSegment, timeSegment)
            params = struct();
            params.emdCutoff = app.StephenEMDCutoff.Value;
            params.lowFreq = app.StephenLowFreq.Value;
            params.highFreq = app.StephenHighFreq.Value;
            params.voicesPerOctave = app.StephenVoices.Value;
            params.minChanges = app.StephenMinChanges.Value;
            params.maxChanges = app.StephenMaxChanges.Value;
            params.statistic = string(app.StephenStatistic.Value);
            params.minSpacing = app.StephenMinSpacing.Value;

            if params.emdCutoff <= 0
                error("EMD cutoff must be greater than zero.");
            end

            if params.lowFreq <= 0 || params.highFreq <= params.lowFreq
                error("Frequency range must have High freq greater than Low freq.");
            end

            if params.highFreq > app.Fs / 2
                error("High frequency cannot exceed half the sampling rate (" + ...
                    sprintf("%.1f Hz", app.Fs / 2) + ").");
            end

            if params.voicesPerOctave < 1 || params.voicesPerOctave ~= round(params.voicesPerOctave)
                error("Voices per octave must be a positive whole number.");
            end

            if params.minChanges < 1 || params.maxChanges < params.minChanges || ...
                    params.minChanges ~= round(params.minChanges) || ...
                    params.maxChanges ~= round(params.maxChanges)
                error("Candidate changepoint range must contain positive whole numbers.");
            end

            if params.minSpacing < 0
                error("Minimum spacing cannot be negative.");
            end

            if string(app.RunModeDropDown.Value) == "Analyze full range"
                result = runStephenMethod( ...
                    signalSegment, ...
                    timeSegment, ...
                    app.Fs, ...
                    params);

                app.LastStephenTimes = result.changeTimes(:);
                app.ShowStephenCheck.Enable = "on";
                app.ShowStephenCheck.Enable = "on";
                app.ShowStephenCheck.Value = true;

                if app.ShowStephenCheck.Value
                    for k = 1:numel(result.changeTimes)
                        app.addMarker(result.changeTimes(k), "CP" + k, "stephen");
                    end
                end

                app.TFResult.Text = app.formatStephenTimes(result.changeTimes, ...
                    "Selected fit: " + string(result.selectedMaxChanges));

                app.StephenSummaryLabel.Text = ...
                    "Full-range result | Selected fit: " + string(result.selectedMaxChanges);

                cpText = "N/A";
                if ~isempty(result.changeTimes)
                    parts = strings(numel(result.changeTimes),1);
                    for kk = 1:numel(result.changeTimes)
                        parts(kk) = sprintf("%.2f s", result.changeTimes(kk));
                    end
                    cpText = strjoin(parts, ", ");
                end

                app.StephenResultData = { ...
                    'Full range', ...
                    char(app.displayRange(timeSegment(1), timeSegment(end))), ...
                    numel(result.changeTimes), ...
                    char(cpText)};
                app.StephenResultsTable.Data = app.StephenResultData;
                app.showStephenResultsTable();

                cla(app.ResidualAxes);
                plot(app.ResidualAxes, result.candidateCounts, result.residuals, "-o");
                hold(app.ResidualAxes, "on");
                xline(app.ResidualAxes, result.selectedMaxChanges, "--", "Selected");
                hold(app.ResidualAxes, "off");

                xlabel(app.ResidualAxes, "Maximum changepoints");
                ylabel(app.ResidualAxes, "Residual");
                title(app.ResidualAxes, "Residual knee");
                grid(app.ResidualAxes, "on");
            else
                iterationWindow = str2double(string(app.IterationWindow.Value));
                iterationStep = str2double(string(app.IterationStep.Value));

                if ~isfinite(iterationWindow) || ~isfinite(iterationStep) || ...
                        iterationWindow <= 0 || iterationStep <= 0
                    error("Enter positive Iteration window and Iteration step values.");
                end

                duration = timeSegment(end) - timeSegment(1);
                if iterationWindow > duration
                    error("Iteration window cannot be longer than the selected analysis range.");
                end

                result = runIterativeStephenMethod( ...
                    signalSegment, ...
                    timeSegment, ...
                    app.Fs, ...
                    params, ...
                    iterationWindow, ...
                    iterationStep);

                app.LastStephenTimes = result.changeTimes(:);
                app.ShowStephenCheck.Value = true;

                if app.ShowStephenCheck.Value
                    for k = 1:numel(result.changeTimes)
                        app.addMarker(result.changeTimes(k), "CP" + k, "stephen");
                    end
                end

                app.TFResult.Text = app.formatStephenTimes(result.changeTimes, ...
                    string(result.windowCount) + " windows");

                app.StephenSummaryLabel.Text = ...
                    result.windowCount + " windows | " + ...
                    sprintf("%.1f s window | %.1f s step", ...
                        result.iterationWindowSeconds, result.iterationStepSeconds);

                tableData = cell(result.windowCount, 4);
                for w = 1:result.windowCount
                    wr = result.windowResults(w);
                    tableData{w,1} = char("W" + w);
                    tableData{w,2} = char(app.displayRange(wr.startTime, wr.endTime));
                    tableData{w,3} = wr.changeCount;

                    if isempty(wr.changeTimes)
                        tableData{w,4} = 'N/A';
                    else
                        parts = strings(numel(wr.changeTimes),1);
                        for kk = 1:numel(wr.changeTimes)
                            parts(kk) = sprintf("%.2f s", wr.changeTimes(kk));
                        end
                        tableData{w,4} = char(strjoin(parts, ", "));
                    end
                end

                app.StephenResultData = tableData;
                app.StephenResultsTable.Data = tableData;
                app.showStephenResultsTable();

                cla(app.ResidualAxes);
                xlabel(app.ResidualAxes, "Window");
                ylabel(app.ResidualAxes, "Selected changepoints");
                title(app.ResidualAxes, "Changepoints selected by window");
                if ~isempty(result.selectedPerWindow)
                    plot(app.ResidualAxes, 1:numel(result.selectedPerWindow), ...
                        result.selectedPerWindow, "-o");
                    grid(app.ResidualAxes, "on");
                end
            end
        end

        function params = buildParams(app)
            features = app.selectedFeatures();

            onsetWindow = max(1, round(app.OnsetWindow.Value * app.Fs / 1000));
            onsetStep = max(1, round(app.OnsetStep.Value * app.Fs / 1000));

            transitionWindow = max(1, round(app.TransitionWindow.Value * app.Fs / 1000));
            transitionStep = max(1, round(app.TransitionStep.Value * app.Fs / 1000));

            terminationWindow = max(1, round(app.TerminationWindow.Value * app.Fs / 1000));
            terminationStep = max(1, round(app.TerminationStep.Value * app.Fs / 1000));

            params = py.dict();

            params{'onset'} = py.dict(pyargs( ...
                'window_size', int32(onsetWindow), ...
                'step', int32(onsetStep), ...
                'penalty', app.OnsetPenalty.Value, ...
                'features', py.list(features)));

            params{'transition'} = py.dict(pyargs( ...
                'window_size', int32(transitionWindow), ...
                'step', int32(transitionStep), ...
                'penalty', app.TransitionPenalty.Value, ...
                'features', py.list(features)));

            params{'termination'} = py.dict(pyargs( ...
                'window_size', int32(terminationWindow), ...
                'step', int32(terminationStep), ...
                'penalty', app.TerminationPenalty.Value, ...
                'features', py.list(features)));
        end

        function features = selectedFeatures(app)
            features = {};

            if app.RMSCheck.Value, features{end+1} = 'rms'; end %#ok<AGROW>
            if app.ThetaCheck.Value, features{end+1} = 'theta'; end %#ok<AGROW>
            if app.AlphaCheck.Value, features{end+1} = 'alpha'; end %#ok<AGROW>
            if app.BetaCheck.Value, features{end+1} = 'beta'; end %#ok<AGROW>
            if app.GammaCheck.Value, features{end+1} = 'gamma'; end %#ok<AGROW>
            if app.LLCheck.Value, features{end+1} = 'll'; end %#ok<AGROW>
            if app.SECheck.Value, features{end+1} = 'se'; end %#ok<AGROW>

            if isempty(features)
                error("Choose at least one feature.");
            end
        end

        function value = toAbsoluteTime(~, relativeSeconds, timeSegment)
            if isnan(relativeSeconds)
                value = NaN;
            else
                value = timeSegment(1) + relativeSeconds;
            end
        end

        function plotSignal(app)
            cla(app.Axes);

            if isempty(app.Signal)
                return
            end

            plot(app.Axes, app.Time, app.Signal);
            hold(app.Axes, "on");

            if ~isempty(app.ShowLVFACheck) && isvalid(app.ShowLVFACheck) && ...
                    app.ShowLVFACheck.Value
                for k = 1:numel(app.LVFATimes)
                    xline(app.Axes, app.LVFATimes(k), "-", "LVFA", ...
                        "Color", [0.4660 0.6740 0.1880], ...
                        "LineWidth", 1.4);
                end
            end

            hold(app.Axes, "off");

            xlabel(app.Axes, "Time (s)");
            ylabel(app.Axes, "Signal");

            if ~isempty(app.ChannelDropDown.Items)
                idx = app.ChannelDropDown.Value;
                title(app.Axes, app.ChannelDropDown.Items{idx});
            end

            grid(app.Axes, "on");
        end

        function markAnalysisRange(app)
            hold(app.Axes, "on");
            xline(app.Axes, app.StartTimeEdit.Value, ":", "Start");
            xline(app.Axes, app.EndTimeEdit.Value, ":", "End");
            hold(app.Axes, "off");
        end

        function addMarker(app, t, labelText, source)
            if nargin < 4
                source = "original";
            end

            if isempty(t) || ~isfinite(t)
                return
            end

            labelText = string(labelText);
            source = string(source);

            if source == "stephen"
                markerColor = [0.8500 0.3250 0.0980];
            else
                markerColor = [0 0.4470 0.7410];
            end

            isNumbered = ~isempty(regexp(char(labelText), '^(CP|O|T|E)\d+$', 'once'));

            if isNumbered
                xline(app.Axes, t, "--", ...
                    "Color", markerColor, ...
                    "LineWidth", 1.3);

                numberText = regexp(char(labelText), '\d+$', 'match', 'once');
                markerNumber = str2double(numberText);
                if ~isfinite(markerNumber)
                    markerNumber = 1;
                end

                yLimits = app.Axes.YLim;
                yRange = yLimits(2) - yLimits(1);
                level = mod(markerNumber - 1, 4);
                y = yLimits(2) - (0.06 + 0.08 * level) * yRange;

                text(app.Axes, t, y, labelText, ...
                    "Color", markerColor, ...
                    "Rotation", 90, ...
                    "HorizontalAlignment", "left", ...
                    "VerticalAlignment", "middle", ...
                    "Clipping", "on");
            else
                xline(app.Axes, t, "--", labelText, ...
                    "Color", markerColor, ...
                    "LineWidth", 1.3);
            end
        end

        function value = pyValue(~, pyObj)
            if isequal(class(pyObj), 'py.NoneType')
                value = NaN;
            else
                value = double(pyObj);
            end
        end

        function text = formatTime(~, labelText, value)
            if isempty(value) || isnan(value)
                text = labelText + ": not found";
            else
                text = labelText + ": " + sprintf("%.2f s", value);
            end
        end

        function textValue = formatStephenTimes(~, changeTimes, suffix)
            if nargin < 3
                suffix = "";
            end

            changeTimes = double(changeTimes(:));

            if isempty(changeTimes)
                textValue = "No changepoints detected";
                return
            end

            pieces = strings(numel(changeTimes), 1);
            for k = 1:numel(changeTimes)
                pieces(k) = "CP" + k + ": " + sprintf("%.2f s", changeTimes(k));
            end

            textValue = strjoin(pieces, "   ");

            if strlength(string(suffix)) > 0
                textValue = textValue + "   |   " + string(suffix);
            end
        end

        function clearResults(app)
            app.OnsetResult.Text = "Onset: --";
            app.TransitionResult.Text = "Transition: --";
            app.TerminationResult.Text = "End: --";
            app.TFResult.Text = "No changepoints yet";

            app.OriginalSummaryLabel.Text = "No results yet";
            app.StephenSummaryLabel.Text = "No results yet";
            app.OriginalResultData = cell(0,5);
            app.StephenResultData = cell(0,4);
            app.OriginalResultsTable.Data = app.OriginalResultData;
            app.StephenResultsTable.Data = app.StephenResultData;
            app.hideResultTables();

            app.LastOriginalOnset = NaN;
            app.LastOriginalTransition = NaN;
            app.LastOriginalEnd = NaN;
            app.LastOriginalOnsets = [];
            app.LastOriginalTransitions = [];
            app.LastOriginalEnds = [];
            app.LastStephenTimes = [];

            if isempty(app.LVFATimes)
                app.LoadedAnnotationResult.Text = "LVFA: not present";
            else
                parts = strings(numel(app.LVFATimes), 1);
                for k = 1:numel(app.LVFATimes)
                    parts(k) = sprintf("%.2f s", app.LVFATimes(k));
                end
                app.LoadedAnnotationResult.Text = "LVFA: " + strjoin(parts, ", ");
            end
        end

        function onReset(app, ~, ~)
            app.populateDefaults();

            if ~isempty(app.Time)
                app.setFullRange();
            end

            app.clearResults();
            app.updateRunModeControls();
            cla(app.ResidualAxes);
            app.StatusLabel.Text = "Defaults restored.";
        end

        function createComponents(app)
            app.UIFigure = uifigure( ...
                "Name", "SEEG Detector", ...
                "Position", [80 60 1380 860]);

            app.Grid = uigridlayout(app.UIFigure, [2 2]);
            app.Grid.RowHeight = {'1x', 430};
            app.Grid.ColumnWidth = {430, '1x'};
            app.Grid.Padding = [10 10 10 10];
            app.Grid.RowSpacing = 10;
            app.Grid.ColumnSpacing = 10;

            app.LeftPanel = uipanel(app.Grid, ...
                "Title", "Controls", ...
                "Scrollable", "on");
            app.LeftPanel.Layout.Row = [1 2];
            app.LeftPanel.Layout.Column = 1;

            app.ControlContent = uipanel(app.LeftPanel, ...
                "BorderType", "none", ...
                "Position", [0 0 400 2100]);

            app.ControlGrid = uigridlayout(app.ControlContent, [13 1]);
            app.ControlGrid.RowHeight = {48, 32, 42, 42, 42, 32, 42, 42, 150, 560, 0, 48, 80};
            app.ControlGrid.RowSpacing = 10;
            app.ControlGrid.Padding = [0 0 0 0];

            app.LoadButton = uibutton(app.ControlGrid, ...
                "Text", "Load File", ...
                "FontSize", 14, ...
                "ButtonPushedFcn", @app.onLoad);

            app.FileLabel = uilabel(app.ControlGrid, ...
                "Text", "No file loaded", ...
                "FontSize", 13);

            row = uigridlayout(app.ControlGrid, [1 2]);
            row.ColumnWidth = {105, '1x'};
            row.Padding = [0 0 0 0];
            row.ColumnSpacing = 10;
            uilabel(row, "Text", "Recording", "FontSize", 13);
            app.RecordingDropDown = uidropdown(row, ...
                "Items", strings(1,0), ...
                "FontSize", 13, ...
                "ValueChangedFcn", @app.onRecordingChanged);

            row = uigridlayout(app.ControlGrid, [1 2]);
            row.ColumnWidth = {105, '1x'};
            row.Padding = [0 0 0 0];
            row.ColumnSpacing = 10;
            uilabel(row, "Text", "Channel", "FontSize", 13);
            app.ChannelDropDown = uidropdown(row, ...
                "Items", strings(1,0), ...
                "FontSize", 13, ...
                "ValueChangedFcn", @app.onChannelChanged);

            row = uigridlayout(app.ControlGrid, [1 2]);
            row.ColumnWidth = {105, '1x'};
            row.Padding = [0 0 0 0];
            row.ColumnSpacing = 10;
            uilabel(row, "Text", "Method", "FontSize", 13);
            app.MethodDropDown = uidropdown(row, ...
                "Items", ["Original detector", "Stephen time-frequency", "Compare methods"], ...
                "Value", "Original detector", ...
                "FontSize", 13, ...
                "ValueChangedFcn", @app.onMethodChanged);

            uilabel(app.ControlGrid, "Text", "Analysis range", ...
                "FontWeight", "bold", ...
                "FontSize", 13);

            row = uigridlayout(app.ControlGrid, [1 2]);
            row.ColumnWidth = {105, '1x'};
            row.Padding = [0 0 0 0];
            row.ColumnSpacing = 10;
            uilabel(row, "Text", "Start (s)", "FontSize", 13);
            app.StartTimeEdit = uieditfield(row, "numeric", "FontSize", 13);

            row = uigridlayout(app.ControlGrid, [1 2]);
            row.ColumnWidth = {105, '1x'};
            row.Padding = [0 0 0 0];
            row.ColumnSpacing = 10;
            uilabel(row, "Text", "End (s)", "FontSize", 13);
            app.EndTimeEdit = uieditfield(row, "numeric", "FontSize", 13);

            app.RunModePanel = uipanel(app.ControlGrid, "Title", "Run mode");
            runModeGrid = uigridlayout(app.RunModePanel, [3 2]);
            runModeGrid.RowHeight = {32, 32, 32};
            runModeGrid.ColumnWidth = {145, '1x'};
            runModeGrid.Padding = [12 10 12 10];
            runModeGrid.RowSpacing = 7;

            uilabel(runModeGrid, "Text", "Mode");
            app.RunModeDropDown = uidropdown(runModeGrid, ...
                "Items", ["Analyze full range", "Analyze windows iteratively"], ...
                "Value", "Analyze full range", ...
                "ValueChangedFcn", @app.onRunModeChanged);

            app.IterationWindowLabel = uilabel(runModeGrid, "Text", "Iteration window (s)");
            app.IterationWindow = uieditfield(runModeGrid, "text", "Value", "");

            app.IterationStepLabel = uilabel(runModeGrid, "Text", "Iteration step (s)");
            app.IterationStep = uieditfield(runModeGrid, "text", "Value", "");

            app.CCPanel = uipanel(app.ControlGrid, "Title", "Original detector");
            cc = uigridlayout(app.CCPanel, [18 2]);
            cc.RowHeight = repmat({29}, 1, 18);
            cc.ColumnWidth = {145, '1x'};
            cc.RowSpacing = 6;
            cc.ColumnSpacing = 10;
            cc.Padding = [12 8 12 8];

            uilabel(cc, "Text", "Sampling rate");
            app.FsEdit = uieditfield(cc, ...
                "numeric", ...
                "Value", 1000, ...
                "Limits", [1 Inf], ...
                "Editable", "off");

            uilabel(cc, "Text", "Onset", "FontWeight", "bold");
            uilabel(cc, "Text", "");
            uilabel(cc, "Text", "Window (ms)");
            app.OnsetWindow = uieditfield(cc, "numeric", "Limits", [1 Inf]);
            uilabel(cc, "Text", "Step (ms)");
            app.OnsetStep = uieditfield(cc, "numeric", "Limits", [1 Inf]);
            uilabel(cc, "Text", "Penalty");
            app.OnsetPenalty = uieditfield(cc, "numeric", "Limits", [0 Inf]);

            uilabel(cc, "Text", "Transition", "FontWeight", "bold");
            uilabel(cc, "Text", "");
            uilabel(cc, "Text", "Window (ms)");
            app.TransitionWindow = uieditfield(cc, "numeric", "Limits", [1 Inf]);
            uilabel(cc, "Text", "Step (ms)");
            app.TransitionStep = uieditfield(cc, "numeric", "Limits", [1 Inf]);
            uilabel(cc, "Text", "Penalty");
            app.TransitionPenalty = uieditfield(cc, "numeric", "Limits", [0 Inf]);

            uilabel(cc, "Text", "End", "FontWeight", "bold");
            uilabel(cc, "Text", "");
            uilabel(cc, "Text", "Window (ms)");
            app.TerminationWindow = uieditfield(cc, "numeric", "Limits", [1 Inf]);
            uilabel(cc, "Text", "Step (ms)");
            app.TerminationStep = uieditfield(cc, "numeric", "Limits", [1 Inf]);
            uilabel(cc, "Text", "Penalty");
            app.TerminationPenalty = uieditfield(cc, "numeric", "Limits", [0 Inf]);

            uilabel(cc, "Text", "Features", "FontWeight", "bold");
            uilabel(cc, "Text", "");

            featureGrid = uigridlayout(cc, [4 2]);
            featureGrid.Layout.Row = [16 18];
            featureGrid.Layout.Column = [1 2];
            featureGrid.Padding = [0 0 0 0];
            featureGrid.RowHeight = {28, 28, 28, 28};
            featureGrid.RowSpacing = 4;

            app.RMSCheck = uicheckbox(featureGrid, "Text", "RMS");
            app.ThetaCheck = uicheckbox(featureGrid, "Text", "Theta");
            app.AlphaCheck = uicheckbox(featureGrid, "Text", "Alpha");
            app.BetaCheck = uicheckbox(featureGrid, "Text", "Beta");
            app.GammaCheck = uicheckbox(featureGrid, "Text", "Gamma");
            app.LLCheck = uicheckbox(featureGrid, "Text", "Line length");
            app.SECheck = uicheckbox(featureGrid, "Text", "Entropy");


            app.TFPanel = uipanel(app.ControlGrid, "Title", "Stephen time-frequency");
            tf = uigridlayout(app.TFPanel, [8 2]);
            tf.RowHeight = repmat({36}, 1, 8);
            tf.ColumnWidth = {155, '1x'};
            tf.Padding = [12 14 12 14];
            tf.RowSpacing = 8;

            uilabel(tf, "Text", "EMD cutoff (Hz)");
            app.StephenEMDCutoff = uieditfield(tf, ...
                "numeric", "Value", 2, "Limits", [eps Inf]);

            uilabel(tf, "Text", "Low freq (Hz)");
            app.StephenLowFreq = uieditfield(tf, ...
                "numeric", "Value", 2, "Limits", [eps Inf]);

            uilabel(tf, "Text", "High freq (Hz)");
            app.StephenHighFreq = uieditfield(tf, ...
                "numeric", "Value", 256, "Limits", [eps Inf]);

            uilabel(tf, "Text", "Voices / octave");
            app.StephenVoices = uieditfield(tf, ...
                "numeric", "Value", 5, "Limits", [1 Inf], ...
                "RoundFractionalValues", "on");

            uilabel(tf, "Text", "Min candidate CPs");
            app.StephenMinChanges = uieditfield(tf, ...
                "numeric", "Value", 2, "Limits", [1 Inf], ...
                "RoundFractionalValues", "on");

            uilabel(tf, "Text", "Max candidate CPs");
            app.StephenMaxChanges = uieditfield(tf, ...
                "numeric", "Value", 9, "Limits", [1 Inf], ...
                "RoundFractionalValues", "on");

            uilabel(tf, "Text", "Statistic");
            app.StephenStatistic = uidropdown(tf, ...
                "Items", ["mean", "rms", "std", "linear"], ...
                "Value", "mean");

            uilabel(tf, "Text", "Min spacing (s)");
            app.StephenMinSpacing = uieditfield(tf, ...
                "numeric", "Value", 2, "Limits", [0 Inf]);

            app.RunButton = uibutton(app.ControlGrid, ...
                "Text", "Run Detection", ...
                "FontSize", 14, ...
                "FontWeight", "bold", ...
                "ButtonPushedFcn", @app.onRun);

            bottom = uigridlayout(app.ControlGrid, [2 1]);
            bottom.RowHeight = {34, 28};
            bottom.Padding = [0 0 0 0];
            bottom.RowSpacing = 8;

            app.ResetButton = uibutton(bottom, ...
                "Text", "Reset Defaults", ...
                "ButtonPushedFcn", @app.onReset);

            app.StatusLabel = uilabel(bottom, ...
                "Text", "", ...
                "WordWrap", "on");

            app.PlotPanel = uipanel(app.Grid, "Title", "Signal");
            app.PlotPanel.Layout.Row = 1;
            app.PlotPanel.Layout.Column = 2;

            app.PlotGrid = uigridlayout(app.PlotPanel, [3 1]);
            app.PlotGrid.RowHeight = {44, '1x', 0};
            app.PlotGrid.Padding = [10 8 10 10];
            app.PlotGrid.RowSpacing = 10;

            app.DisplayPanel = uipanel(app.PlotGrid, ...
                "BorderType", "none");

            displayGrid = uigridlayout(app.DisplayPanel, [1 4]);
            displayGrid.ColumnWidth = {65, 150, 170, 150};
            displayGrid.Padding = [0 0 0 0];
            displayGrid.ColumnSpacing = 12;

            uilabel(displayGrid, ...
                "Text", "Display", ...
                "FontWeight", "bold");

            app.ShowOriginalCheck = uicheckbox(displayGrid, ...
                "Text", "Original detector", ...
                "Value", false, ...
                "Enable", "on", ...
                "FontColor", [0 0.4470 0.7410], ...
                "ValueChangedFcn", @app.onDisplayChanged);

            app.ShowStephenCheck = uicheckbox(displayGrid, ...
                "Text", "Stephen time-frequency", ...
                "Value", false, ...
                "Enable", "on", ...
                "FontColor", [0.8500 0.3250 0.0980], ...
                "ValueChangedFcn", @app.onDisplayChanged);

            app.ShowLVFACheck = uicheckbox(displayGrid, ...
                "Text", "Loaded LVFA", ...
                "Value", true, ...
                "FontColor", [0.4660 0.6740 0.1880], ...
                "ValueChangedFcn", @app.onDisplayChanged);

            app.Axes = uiaxes(app.PlotGrid);
            app.ResidualAxes = uiaxes(app.PlotGrid);

            app.ResultsPanel = uipanel(app.Grid, "Title", "Results");
            app.ResultsPanel.Layout.Row = 2;
            app.ResultsPanel.Layout.Column = 2;

            app.ResultsGrid = uigridlayout(app.ResultsPanel, [1 3]);
            app.ResultsGrid.ColumnWidth = {'2x', 0, '1x'};
            app.ResultsGrid.Padding = [10 8 10 8];
            app.ResultsGrid.ColumnSpacing = 10;

            app.OriginalResultsPanel = uipanel(app.ResultsGrid, ...
                "Title", "Original detector", ...
                "Scrollable", "on");
            app.OriginalResultsGrid = uigridlayout(app.OriginalResultsPanel, [4 1]);
            app.OriginalResultsGrid.RowHeight = {34, 0, 0, 0};
            app.OriginalResultsGrid.Padding = [12 10 12 10];
            app.OriginalResultsGrid.RowSpacing = 10;

            app.OriginalSummaryLabel = uilabel(app.OriginalResultsGrid, ...
                "Text", "No results yet", ...
                "FontWeight", "bold", ...
                "FontSize", 14, ...
                "WordWrap", "on");

            app.OriginalResultsTable = uitable(app.OriginalResultsGrid, ...
                "Data", cell(0,5), ...
                "ColumnName", {"Window", "Time range", "Onset", "Transition", "End"}, ...
                "RowName", [], ...
                "Visible", "off");
            app.OriginalResultsTable.ColumnWidth = {85, 180, 125, 125, 125};

            uilabel(app.OriginalResultsGrid, "Text", "");

            app.OriginalExpandButton = uibutton(app.OriginalResultsGrid, ...
                "Text", "Expand results", ...
                "Visible", "off", ...
                "ButtonPushedFcn", @app.onExpandOriginalResults);

            % Hidden compatibility labels; parented outside the result grid
            % so they do not consume layout rows.
            app.OnsetResult = uilabel(app.UIFigure, ...
                "Visible", "off", ...
                "Position", [1 1 1 1]);
            app.TransitionResult = uilabel(app.UIFigure, ...
                "Visible", "off", ...
                "Position", [1 1 1 1]);
            app.TerminationResult = uilabel(app.UIFigure, ...
                "Visible", "off", ...
                "Position", [1 1 1 1]);

            app.StephenResultsPanel = uipanel(app.ResultsGrid, ...
                "Title", "Stephen time-frequency", ...
                "Scrollable", "on");
            app.StephenResultsGrid = uigridlayout(app.StephenResultsPanel, [4 1]);
            app.StephenResultsGrid.RowHeight = {34, 0, 0, 0};
            app.StephenResultsGrid.Padding = [12 10 12 10];
            app.StephenResultsGrid.RowSpacing = 10;

            app.StephenSummaryLabel = uilabel(app.StephenResultsGrid, ...
                "Text", "No results yet", ...
                "FontWeight", "bold", ...
                "FontSize", 14, ...
                "WordWrap", "on");

            app.StephenResultsTable = uitable(app.StephenResultsGrid, ...
                "Data", cell(0,4), ...
                "ColumnName", {"Window", "Time range", "CP count", "CP times"}, ...
                "RowName", [], ...
                "Visible", "off");
            app.StephenResultsTable.ColumnWidth = {85, 180, 100, 340};

            uilabel(app.StephenResultsGrid, "Text", "");

            app.StephenExpandButton = uibutton(app.StephenResultsGrid, ...
                "Text", "Expand results", ...
                "Visible", "off", ...
                "ButtonPushedFcn", @app.onExpandStephenResults);

            % Hidden compatibility label; parented outside the result grid.
            app.TFResult = uilabel(app.UIFigure, ...
                "Visible", "off", ...
                "Position", [1 1 1 1]);

            app.AnnotationResultsPanel = uipanel(app.ResultsGrid, ...
                "Title", "Loaded annotation");
            annotationResults = uigridlayout(app.AnnotationResultsPanel, [1 1]);
            annotationResults.Padding = [10 6 10 6];

            app.LoadedAnnotationResult = uilabel(annotationResults, ...
                "Text", "LVFA: --", ...
                "FontSize", 13, ...
                "WordWrap", "on");
        end
    end

    methods (Access = public)

        function app = SEEGDetectionApp
            createComponents(app)
            startupFcn(app)
        end

        function delete(app)
            if ~isempty(app.UIFigure) && isvalid(app.UIFigure)
                delete(app.UIFigure)
            end
        end
    end
end
