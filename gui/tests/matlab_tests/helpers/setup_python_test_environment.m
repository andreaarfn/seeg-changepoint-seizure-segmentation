function setup_python_test_environment()
%SETUP_PYTHON_TEST_ENVIRONMENT Configure MATLAB for Python integration tests.
%
% This helper is shared by every MATLAB integration test. It:
%   1. Finds the project's Python virtual environment.
%   2. Configures MATLAB to use that Python interpreter.
%   3. Adds the repository to Python's import path.
%   4. Refreshes Python's import cache.

%% ------------------------------------------------------------------------
% Locate the project folders
% -------------------------------------------------------------------------

helperFolder = fileparts(mfilename("fullpath"));

% Folder structure:
%
% project/
% ├── .venv/
% └── seeg-changepoint-seizure-segmentation/
%     └── gui/
%         └── tests/
%             └── matlab_tests/
%                 ├── helpers/
%                 ├── integration_tests/
%                 └── mock_data/

matlabTestsFolder = fileparts(helperFolder);
testsFolder = fileparts(matlabTestsFolder);
guiFolder = fileparts(testsFolder);
repositoryFolder = fileparts(guiFolder);
projectFolder = fileparts(repositoryFolder);

%% ------------------------------------------------------------------------
% Locate the virtual environment
% -------------------------------------------------------------------------

pythonExecutable = fullfile( ...
    projectFolder, ...
    ".venv", ...
    "bin", ...
    "python" ...
);

if ~isfile(pythonExecutable)
    error( ...
        "SEEG:PythonNotFound", ...
        "Could not find the project's Python interpreter:%s%s", ...
        newline, ...
        pythonExecutable ...
    );
end

%% ------------------------------------------------------------------------
% Configure MATLAB to use the correct Python interpreter
% -------------------------------------------------------------------------

environment = pyenv();

if environment.Status == "NotLoaded"

    pyenv( ...
        "Version", pythonExecutable, ...
        "ExecutionMode", "OutOfProcess" ...
    );

elseif string(environment.Executable) ~= string(pythonExecutable)

    error( ...
        "SEEG:WrongPythonEnvironment", ...
        [ ...
        "MATLAB is already using a different Python interpreter.", ...
        newline, ...
        "Restart MATLAB before running these tests.", ...
        newline, ...
        newline, ...
        "Expected:", newline, pythonExecutable, ...
        newline, ...
        newline, ...
        "Current:", newline, char(environment.Executable) ...
        ] ...
    );

end

%% ------------------------------------------------------------------------
% Add the repository to Python's import path
% -------------------------------------------------------------------------

repositoryPath = char(repositoryFolder);

pythonPath = cell(py.list(py.sys.path));

if ~any(strcmp(pythonPath, repositoryPath))
    insert(py.sys.path, int32(0), repositoryPath);
end

%% ------------------------------------------------------------------------
% Refresh Python's import cache
% -------------------------------------------------------------------------

py.importlib.invalidate_caches();

end