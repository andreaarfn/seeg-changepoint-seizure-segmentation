classdef SEEGDetectionApp < matlab.apps.AppBase

    properties (Access = public)
        UIFigure matlab.ui.Figure
        Grid matlab.ui.container.GridLayout
        LeftPanel matlab.ui.container.Panel
        ControlContent matlab.ui.container.Panel
        PlotPanel matlab.ui.container.Panel
        ResultsPanel matlab.ui.container.Panel
        Axes matlab.ui.control.UIAxes
        ResidualAxes matlab.ui.control.UIAxes

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

        TFMaxChanges matlab.ui.control.EditField
        TFDownsample matlab.ui.control.EditField
        TFLowFreq matlab.ui.control.EditField
        TFHighFreq matlab.ui.control.EditField
        TFStatistic matlab.ui.control.DropDown
        TFMinDistance matlab.ui.control.EditField
        TFScanWindow matlab.ui.control.EditField
        TFScanStep matlab.ui.control.EditField

        OnsetResult matlab.ui.control.Label
        TransitionResult matlab.ui.control.Label
        TerminationResult matlab.ui.control.Label
        TFResult matlab.ui.control.Label
        StatusLabel matlab.ui.control.Label
    end

    properties (Access = private)
        Data
        Signal
        Time
        Fs = 1000
        LVFATimes = []
    end

    methods (Access = private)

        function startupFcn(app)
            app.populateDefaults();
            app.updateMethodPanels();
            app.StatusLabel.Text = "Load a file to begin.";
        end

        function populateDefaults(app)
            app.OnsetWindow.Value = 1000;
            app.OnsetStep.Value = 150;
            app.OnsetPenalty.Value = 11;

            app.TransitionWindow.Value = 700;
            app.TransitionStep.Value = 130;
            app.TransitionPenalty.Value = 7;

            app.TerminationWindow.Value = 1000;
            app.TerminationStep.Value = 200;
            app.TerminationPenalty.Value = 10;

            app.RMSCheck.Value = true;
            app.ThetaCheck.Value = true;
            app.AlphaCheck.Value = true;
            app.BetaCheck.Value = true;
            app.GammaCheck.Value = true;
            app.LLCheck.Value = true;
            app.SECheck.Value = true;

            app.TFMaxChanges.Value = "";
            app.TFDownsample.Value = "";
            app.TFLowFreq.Value = "";
            app.TFHighFreq.Value = "";
            app.TFStatistic.Value = "Select...";
            app.TFMinDistance.Value = "";
            app.TFScanWindow.Value = "";
            app.TFScanStep.Value = "";
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
            app.clearResults();
            cla(app.ResidualAxes);
        end

        function updateMethodPanels(app)
            method = string(app.MethodDropDown.Value);

            if method == "Default approach"
                app.CCPanel.Visible = "on";
                app.TFPanel.Visible = "off";
                app.ResidualAxes.Visible = "off";
            elseif method == "Time-frequency approach"
                app.CCPanel.Visible = "off";
                app.TFPanel.Visible = "on";
                app.ResidualAxes.Visible = "on";
            else
                app.CCPanel.Visible = "on";
                app.TFPanel.Visible = "on";
                app.ResidualAxes.Visible = "on";
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

                if method == "Default approach"
                    app.runCC(signalSegment, timeSegment);
                elseif method == "Time-frequency approach"
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

            app.addMarker(onset, "Onset");
            app.addMarker(transition, "Transition");
            app.addMarker(ending, "End");

            app.OnsetResult.Text = app.formatTime("Onset", onset);
            app.TransitionResult.Text = app.formatTime("Transition", transition);
            app.TerminationResult.Text = app.formatTime("End", ending);
        end

        function runTF(app, signalSegment, timeSegment)
            maxChanges = str2double(string(app.TFMaxChanges.Value));
            downsampleFactor = str2double(string(app.TFDownsample.Value));
            lowFreq = str2double(string(app.TFLowFreq.Value));
            highFreq = str2double(string(app.TFHighFreq.Value));
            minDistance = str2double(string(app.TFMinDistance.Value));
            scanWindow = str2double(string(app.TFScanWindow.Value));
            scanStep = str2double(string(app.TFScanStep.Value));

            values = [ ...
                maxChanges, ...
                downsampleFactor, ...
                lowFreq, ...
                highFreq, ...
                minDistance, ...
                scanWindow, ...
                scanStep];

            if any(~isfinite(values))
                error("Enter all Time-frequency settings before running detection.");
            end

            statistic = string(app.TFStatistic.Value);
            if statistic == "Select..."
                error("Choose a findchangepts statistic before running detection.");
            end

            if maxChanges < 1 || maxChanges ~= round(maxChanges)
                error("Max changes must be a positive whole number.");
            end

            if downsampleFactor < 1 || downsampleFactor ~= round(downsampleFactor)
                error("Downsample factor must be a positive whole number.");
            end

            if minDistance < 1 || minDistance ~= round(minDistance)
                error("Minimum distance must be a positive whole number.");
            end

            if lowFreq < 0 || highFreq <= lowFreq
                error("High frequency must be greater than low frequency.");
            end

            if highFreq >= app.Fs / 2
                error("High frequency must be below half the sampling rate (" + ...
                    sprintf("%.1f Hz", app.Fs / 2) + ").");
            end

            if scanWindow <= 0 || scanStep <= 0
                error("Scan window and scan step must be greater than zero.");
            end

            duration = timeSegment(end) - timeSegment(1);
            if scanWindow > duration
                error("Scan window cannot be longer than the selected analysis range.");
            end

            result = runIterativeChangePoints( ...
                signalSegment, ...
                timeSegment, ...
                app.Fs, ...
                maxChanges, ...
                downsampleFactor, ...
                [lowFreq highFreq], ...
                statistic, ...
                minDistance, ...
                scanWindow, ...
                scanStep);

            for k = 1:numel(result.selectedTimes)
                app.addMarker(result.selectedTimes(k), "CP" + k);
            end

            app.TFResult.Text = ...
                "Detected changes: " + string(numel(result.selectedTimes)) + ...
                " across " + string(result.windowCount) + " windows";

            cla(app.ResidualAxes);
            plot(app.ResidualAxes, result.changeCounts, result.meanResiduals, "-o");
            hold(app.ResidualAxes, "on");

            if isfinite(result.medianSelectedPerWindow)
                xline(app.ResidualAxes, ...
                    result.medianSelectedPerWindow, ...
                    "--", ...
                    "Median selected/window");
            end

            hold(app.ResidualAxes, "off");

            xlabel(app.ResidualAxes, "Change points per window");
            ylabel(app.ResidualAxes, "Mean residual");
            title(app.ResidualAxes, "Fit");
            grid(app.ResidualAxes, "on");
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

            for k = 1:numel(app.LVFATimes)
                xline(app.Axes, app.LVFATimes(k), "-", "LVFA");
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

        function addMarker(app, t, labelText)
            if isempty(t) || isnan(t)
                return
            end

            labelText = string(labelText);

            if startsWith(labelText, "CP")
                xline(app.Axes, t, "--");

                cpNumber = str2double(extractAfter(labelText, "CP"));
                if ~isfinite(cpNumber)
                    cpNumber = 1;
                end

                yLimits = app.Axes.YLim;
                yRange = yLimits(2) - yLimits(1);

                level = mod(cpNumber - 1, 4);
                y = yLimits(2) - (0.06 + 0.08 * level) * yRange;

                text(app.Axes, t, y, labelText, ...
                    "Rotation", 90, ...
                    "HorizontalAlignment", "left", ...
                    "VerticalAlignment", "middle", ...
                    "Clipping", "on");
            else
                xline(app.Axes, t, "--", labelText);
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

        function clearResults(app)
            app.OnsetResult.Text = "Onset: --";
            app.TransitionResult.Text = "Transition: --";
            app.TerminationResult.Text = "End: --";
            app.TFResult.Text = "Selected changes: --";
        end

        function onReset(app, ~, ~)
            app.populateDefaults();

            if ~isempty(app.Time)
                app.setFullRange();
            end

            app.clearResults();
            cla(app.ResidualAxes);
            app.StatusLabel.Text = "Defaults restored.";
        end

        function createComponents(app)
            app.UIFigure = uifigure( ...
                "Name", "SEEG Detector", ...
                "Position", [80 60 1380 860]);

            app.Grid = uigridlayout(app.UIFigure, [2 2]);
            app.Grid.RowHeight = {'1x', 145};
            app.Grid.ColumnWidth = {400, '1x'};
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
                "Position", [0 0 370 1510]);

            left = uigridlayout(app.ControlContent, [12 1]);
            left.RowHeight = {48, 32, 42, 42, 42, 32, 42, 42, 500, 325, 48, 70};
            left.RowSpacing = 10;
            left.Padding = [0 0 0 0];

            app.LoadButton = uibutton(left, ...
                "Text", "Load File", ...
                "FontSize", 14, ...
                "ButtonPushedFcn", @app.onLoad);

            app.FileLabel = uilabel(left, ...
                "Text", "No file loaded", ...
                "FontSize", 13);

            row = uigridlayout(left, [1 2]);
            row.ColumnWidth = {105, '1x'};
            row.Padding = [0 0 0 0];
            row.ColumnSpacing = 10;
            uilabel(row, "Text", "Recording", "FontSize", 13);
            app.RecordingDropDown = uidropdown(row, ...
                "Items", strings(1,0), ...
                "FontSize", 13, ...
                "ValueChangedFcn", @app.onRecordingChanged);

            row = uigridlayout(left, [1 2]);
            row.ColumnWidth = {105, '1x'};
            row.Padding = [0 0 0 0];
            row.ColumnSpacing = 10;
            uilabel(row, "Text", "Channel", "FontSize", 13);
            app.ChannelDropDown = uidropdown(row, ...
                "Items", strings(1,0), ...
                "FontSize", 13, ...
                "ValueChangedFcn", @app.onChannelChanged);

            row = uigridlayout(left, [1 2]);
            row.ColumnWidth = {105, '1x'};
            row.Padding = [0 0 0 0];
            row.ColumnSpacing = 10;
            uilabel(row, "Text", "Method", "FontSize", 13);
            app.MethodDropDown = uidropdown(row, ...
                "Items", ["Default approach", "Time-frequency approach", "Compare methods"], ...
                "Value", "Default approach", ...
                "FontSize", 13, ...
                "ValueChangedFcn", @app.onMethodChanged);

            uilabel(left, "Text", "Analysis range", ...
                "FontWeight", "bold", ...
                "FontSize", 13);

            row = uigridlayout(left, [1 2]);
            row.ColumnWidth = {105, '1x'};
            row.Padding = [0 0 0 0];
            row.ColumnSpacing = 10;
            uilabel(row, "Text", "Start (s)", "FontSize", 13);
            app.StartTimeEdit = uieditfield(row, "numeric", "FontSize", 13);

            row = uigridlayout(left, [1 2]);
            row.ColumnWidth = {105, '1x'};
            row.Padding = [0 0 0 0];
            row.ColumnSpacing = 10;
            uilabel(row, "Text", "End (s)", "FontSize", 13);
            app.EndTimeEdit = uieditfield(row, "numeric", "FontSize", 13);

            methodsGrid = uigridlayout(left, [1 1]);
            methodsGrid.Padding = [0 0 0 0];

            app.CCPanel = uipanel(methodsGrid, "Title", "Default approach");
            cc = uigridlayout(app.CCPanel, [18 2]);
            cc.RowHeight = repmat({27}, 1, 18);
            cc.ColumnWidth = {130, '1x'};
            cc.RowSpacing = 5;
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

            app.RMSCheck = uicheckbox(featureGrid, "Text", "RMS");
            app.ThetaCheck = uicheckbox(featureGrid, "Text", "Theta");
            app.AlphaCheck = uicheckbox(featureGrid, "Text", "Alpha");
            app.BetaCheck = uicheckbox(featureGrid, "Text", "Beta");
            app.GammaCheck = uicheckbox(featureGrid, "Text", "Gamma");
            app.LLCheck = uicheckbox(featureGrid, "Text", "Line length");
            app.SECheck = uicheckbox(featureGrid, "Text", "Entropy");

            app.TFPanel = uipanel(left, "Title", "Time-frequency approach");
            tf = uigridlayout(app.TFPanel, [8 2]);
            tf.RowHeight = repmat({32}, 1, 8);
            tf.ColumnWidth = {135, '1x'};
            tf.Padding = [12 10 12 10];
            tf.RowSpacing = 7;

            uilabel(tf, "Text", "Scan window (s)");
            app.TFScanWindow = uieditfield(tf, "text", "Value", "");

            uilabel(tf, "Text", "Scan step (s)");
            app.TFScanStep = uieditfield(tf, "text", "Value", "");

            uilabel(tf, "Text", "Max changes");
            app.TFMaxChanges = uieditfield(tf, "text", "Value", "");

            uilabel(tf, "Text", "Downsample factor");
            app.TFDownsample = uieditfield(tf, "text", "Value", "");

            uilabel(tf, "Text", "Low freq (Hz)");
            app.TFLowFreq = uieditfield(tf, "text", "Value", "");

            uilabel(tf, "Text", "High freq (Hz)");
            app.TFHighFreq = uieditfield(tf, "text", "Value", "");

            uilabel(tf, "Text", "Statistic");
            app.TFStatistic = uidropdown(tf, ...
                "Items", ["Select...", "mean", "rms", "std", "linear"], ...
                "Value", "Select...");

            uilabel(tf, "Text", "Min distance");
            app.TFMinDistance = uieditfield(tf, "text", "Value", "");

            app.RunButton = uibutton(left, ...
                "Text", "Run Detection", ...
                "FontSize", 14, ...
                "FontWeight", "bold", ...
                "ButtonPushedFcn", @app.onRun);

            bottom = uigridlayout(left, [2 1]);
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

            plotGrid = uigridlayout(app.PlotPanel, [2 1]);
            plotGrid.RowHeight = {'2x', '1x'};
            plotGrid.Padding = [10 8 10 10];
            plotGrid.RowSpacing = 10;

            app.Axes = uiaxes(plotGrid);
            app.ResidualAxes = uiaxes(plotGrid);

            app.ResultsPanel = uipanel(app.Grid, "Title", "Results");
            app.ResultsPanel.Layout.Row = 2;
            app.ResultsPanel.Layout.Column = 2;

            results = uigridlayout(app.ResultsPanel, [2 2]);
            results.Padding = [14 12 14 12];
            results.RowSpacing = 8;
            results.ColumnSpacing = 20;

            app.OnsetResult = uilabel(results, "Text", "Onset: --", "FontSize", 16);
            app.TransitionResult = uilabel(results, "Text", "Transition: --", "FontSize", 16);
            app.TerminationResult = uilabel(results, "Text", "End: --", "FontSize", 16);
            app.TFResult = uilabel(results, "Text", "Selected changes: --", "FontSize", 16);
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
