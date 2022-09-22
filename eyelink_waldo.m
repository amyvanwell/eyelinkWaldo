clc;

%% WHERE'S WALDO EXPERIMENT FOR EYELINK %%%%%%%

%% testing globals
TEST = 0;
EYELINK_DEMO = 0;
dummymode = 0;
minfix = 1;
MINSCREEN = 0;

%% OpenGL and define parameters %%%%%%%%%%%%%%%%%%%%%%%%%
Screen('Preference','SkipSyncTests',1);
AssertOpenGL;
KbName('UnifyKeyNames');
spacebar = KbName('space');
key_left = KbName('f');
key_right = KbName('j');
WaitSecs(0.0001);

%% define the path %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
filepath = which('eyelink_waldo.m');
dir = fileparts(filepath);
if isunix
    savedir = strcat(dir,'/data/');
    stimdir = strcat(dir,'/imgs/');
    listdir = strcat(dir, '/lists/');
    eyelinkdir = strcat(dir,'/eyelink_data/');

elseif ispc
    savedir = strcat(dir,'\data\');  
    stimdir = strcat(dir,'\imgs\');
    listdir = strcat(dir, '\lists\');
    eyelinkdir = strcat(dir,'\eyelink_data\');

end
cd(dir);

%% COLLECT PNUM, GENERATE DATA FILES %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
pnum = 0;
session = 0;

% get participant number
if TEST == 1
    pnum = '999';
else
    prompt = {'Participant Number'};
    pinfo = inputdlg(prompt,'Participant information');
    participant = str2num(pinfo{1});
    if (participant > 0) && (participant < 10)
        pnum = strcat('00',num2str(participant));
    elseif (participant >= 10) && (participant < 100)
        pnum = strcat('0',num2str(participant));
    else
        pnum = num2str(participant);
    end
end

% create the output file with the participant and session number
outfilename = strcat('participant',pnum);
OutputFile = strcat(savedir,outfilename,'.txt');
datafilepointer = fopen(OutputFile,'w');

% create header for data in the data file
fprintf(datafilepointer, 'pnum\ttarget_location\trt_space\trt_click\tcorrect\tbackground\r\n');

% read the background data in
backgrounds = textread('backgrounds.txt','%s');
% randomize the backgrounds
rand_backgrounds = backgrounds(randperm(length(backgrounds)));
num_backgrounds = length(rand_backgrounds);
totalTrials = num_backgrounds * 8 + 8;

% create an eyelink file name from participant number
cd(eyelinkdir);
prompt = {'Enter tracker EDF file name (1 to 8 letters or numbers)'};
dlg_title = 'Create EDF file';
num_lines= 1;
def     = {'DEMO'};
answer  = inputdlg(prompt,dlg_title,num_lines,def);
edfFile = answer{1};
fprintf('EDFFile: %s\n', edfFile )

%% SCREEN SETUP
% Turn off debugging errors
Screen('Preference', 'VisualDebugLevel', 0);

% open window with a white background
% NOTE: rectangle provided to escape full screen mode if testing
screen = max(Screen('Screens'));
if (MINSCREEN == 1)
    [win,windowRect] = Screen('OpenWindow',screen,1,[0 0 840 880]);
else
    [win,windowRect] = Screen('OpenWindow',screen,1);
end
color_white = [255 255 255];
color_black = BlackIndex(screen);
Screen('FillRect',win,color_white);

% get screen dimensions
[screenXpixels,screenYpixels] = Screen('WindowSize',win);

% setup text formatting
Screen('TextSize', win, 20);
Screen('TextFont', win, 'Courier');

% hide the cursor
HideCursor;

% add alpha so images can blend
Screen('BlendFunction', win, 'GL_SRC_ALPHA', 'GL_ONE_MINUS_SRC_ALPHA');

%% calculate the positions for the waldo target %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
x20 = screenXpixels *.2;
y20 = screenYpixels *.2;
x30 = screenXpixels *.3;
y30 = screenYpixels *.3;
x50 = screenXpixels/2;
y50 = screenYpixels/2;

f1.x = x30; f1.y = y30;
f2.x = x50; f2.y = y30;
f3.x = x50 + x20; f3.y = y30;
f4.x = x50 + x20; f4.y = y50; 
f5.x = x50 + x20; f5.y = y50 + y20; 
f6.x = x50; f6.y = y50 + y20; 
f7.x = x30; f7.y = y50 + y20; 
f8.x = x30; f8.y = y50; 

% save to a map for easier reference
positions_map = containers.Map({'f1','f2','f3','f4','f5','f6','f7','f8'}, {f1, f2, f3, f4, f5, f6, f7, f8});

%% Eyelink SETTINGS AND CALIBRATION %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% set up screen settings
% NOTE: this step must occur after opening window (Screen, 'openwindow')
el=EyelinkInitDefaults(win);
    color_black = BlackIndex(el.window);
    color_white = WhiteIndex(el.window);
    el.backgroundcolour = color_white;
    el.msgfontcolour  = color_black;
    el.imgtitlecolour = color_black;
    el.targetbeep = 0;
    el.calibrationtargetcolour = BlackIndex(el.window);
    
    el.calibrationtargetsize= 1;
    el.calibrationtargetwidth=0.5;
    % call this function for changes to the calibration structure to take
    % effect
    EyelinkUpdateDefaults(el);
    
% Initialization of the connection with the Eyelink Gazetracker.
% exit program if this fails.
if ~EyelinkInit(dummymode, 1)
    fprintf('Eyelink Init aborted.\n');
    cleanup;  % cleanup function
    return;
end

 % make sure that we get gaze data from the Eyelink
status=Eyelink('command','link_sample_data = LEFT,RIGHT,GAZE,AREA,GAZERES,HREF,PUPIL,STATUS,INPUT');
if status~=0
    fprintf('link_sample_data error, status: %s',status);
else
    fprintf('Succesfully collected sample data.');
end

 % check if connected
if Eyelink('IsConnected')~=1
        cleanup;
        return;
end

% open file to record data to
cd(eyelinkdir);
i = Eyelink('Openfile', edfFile);
if i~=0
    fprintf('Cannot create EDF file ''%s'' ', edfFile);
    cleanup;
    return;
end

%% EYELINK CONFIGURATION
    % Setting the proper recording resolution, proper calibration type,
    % as well as the data file content;
    Eyelink('command', 'add_file_preamble_text ''Recorded by EyelinkToolbox demo-experiment''');
   
    % This command is crucial to map the gaze positions from the tracker to
    % screen pixel positions to determine fixation
    Eyelink('command','screen_pixel_coords = %ld %ld %ld %ld', 0, 0, screenXpixels-1, screenYpixels-1);
    
    Eyelink('message', 'DISPLAY_COORDS %ld %ld %ld %ld', 0, 0, screenXpixels-1, screenYpixels-1);
    % set calibration type.
    Eyelink('command', 'calibration_type = HV9');
    Eyelink('command', 'generate_default_targets = YES');
    % set parser (conservative saccade thresholds)
    Eyelink('command', 'saccade_velocity_threshold = 35');
    Eyelink('command', 'saccade_acceleration_threshold = 9500');
    % set EDF file contents
        % 5.1 retrieve tracker version and tracker software version
    [v,vs] = Eyelink('GetTrackerVersion');
    fprintf('Running experiment on a ''%s'' tracker.\n', vs );
    vsn = regexp(vs,'\d','match');
    
    if v ==3 && str2double(vsn{1}) == 4 % if EL 1000 and tracker version 4.xx
        
        % remote mode possible add HTARGET ( head target)
        Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
        Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS,INPUT,HTARGET');
        % set link data (used for gaze cursor)
        Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,FIXUPDATE,INPUT');
        Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS,INPUT,HTARGET');
    else
        Eyelink('command', 'file_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,INPUT');
        Eyelink('command', 'file_sample_data  = LEFT,RIGHT,GAZE,HREF,AREA,GAZERES,STATUS,INPUT');
        % set link data (used for gaze cursor)
        Eyelink('command', 'link_event_filter = LEFT,RIGHT,FIXATION,SACCADE,BLINK,MESSAGE,BUTTON,FIXUPDATE,INPUT');
        Eyelink('command', 'link_sample_data  = LEFT,RIGHT,GAZE,GAZERES,AREA,STATUS,INPUT');
    end
    
    % calibration/drift correction target
    Eyelink('command', 'button_function 5 "accept_target_fixation"');
    Screen('HideCursorHelper',win);
   

% enter Eyetracker camera setup mode, perform calibration and validation
EyelinkDoTrackerSetup(el);

% Define Trial Variables
Eyelink('Message', 'TRIAL_VAR_LABELS POSITION TRIAL_NUM');
% Group Trials By Position in Data Viewer
Eyelink('Message', 'V_TRIAL_GROUPING POSITION');

%% INSTRUCTIONS
% Present text indicating experiment will now begin
DrawFormattedText(win, 'Thank you for participating in the calibration of the Eyelink system. We will now proceed to the experiment.\n Press any key to continue.', 'center', 'center', color_black);
% flip the window to display the text
Screen('Flip', win);
% Dismiss text with keyboard response
KbStrokeWait;

% Present instructions
DrawFormattedText(win, 'The current task is very simple. You will perform 10 groups of 8 trials. \n\n Each trial has three parts: \n\n1: Central cross fixation. There will be a black cross in the center of the screen at the beginning of each trial. \nTo proceed to part two, we must record 500ms of consecutive fixation on this cross. \nIn other words, you have to look at the center cross for half a second to proceed to part two.\n', 'center', 'center', color_black);
Screen('Flip', win);
KbStrokeWait;

DrawFormattedText(win, '\n 2: Wheres Waldo Search. After you have held your gaze on the cross for 500ms, a classic Waldo background will appear on the screen. \nAn example background is shown above.\n', 'center', screenYpixels/2 + 300, color_black);
sampleBackgroundImg = imread(strcat(stimdir, 'background1.jpeg'));
sampleBackgroundTexture = Screen('MakeTexture',win,sampleBackgroundImg);
Screen('DrawTexture', win, sampleBackgroundTexture, [], [screenXpixels/2-500 screenYpixels/2-300 screenXpixels/2+500 screenYpixels/2+200])
Screen('Flip', win);
KbStrokeWait;

DrawFormattedText(win, '\n 2: Wheres Waldo Search. \nOnce the background appears, your task is to find the Waldo target on the screen. \nAn example Waldo is shown above. \nOnce you find him on the background, you must PRESS THE SPACEBAR. \nOnce you press the SPACEBAR, you will proceed to the last part of the trial.', 'center', screenYpixels/2 + 100, color_black);
[sampleWaldoImg, ~, alpha] = imread(strcat(stimdir, 'waldo_small.png'));
sampleWaldoImg(:, :, 4) = alpha;
sampleWaldoTexture = Screen('MakeTexture',win,sampleWaldoImg);
Screen('DrawTexture', win, sampleWaldoTexture, [], [screenXpixels/2-50 screenYpixels/2-200 screenXpixels/2+50 screenYpixels/2])
Screen('Flip', win);
KbStrokeWait;

DrawFormattedText(win, '\n 3: Waldo Target Location. \nAfter you press the spacebar, the Waldo target will disappear but the background will stay. \nOn this screen, you need to use the MOUSE to CLICK on the location that Waldo was!\n When you CLICK the MOUSE, the trial has completed and you will move on to the next trial. \n\nYou will know that you are on the next trial when the black cross re-appears.', 'center', 'center', color_black);
Screen('Flip', win);
KbStrokeWait;

DrawFormattedText(win, '\n We will now proceed to 8 practice trials. During the practice, we will give you feedback on whether the mouse click is correct or not.\n As a reminder, trials are composed of 3 parts: \n\n1: CROSS FIXATION: stare a centered cross for 500ms, until it disappears. \n\n2: WALDO SEARCH: Look for a Waldo target on a busy background. PRESS THE SPACEBAR once you found him.\n\n 3:WALDO LOCATION IDENTIFCATION: Once you have found Waldo, CLICK YOUR MOUSE on the location that you just saw him!', 'center', 'center', color_black);
Screen('Flip', win);
KbStrokeWait;

DrawFormattedText(win, '\n Have any questions? Please ask! \n Press any key to proceed to practice trials.', 'center', 'center', color_black);
Screen('Flip', win);
KbStrokeWait;

%% PRACTICE TRIALS %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
RestrictKeysForKbCheck([spacebar,key_left,key_right]);

% Present text indicating experiment will now begin
DrawFormattedText(win, 'ONE PRACTICE WALDO BLOCK.\n Press any key to continue.', 'center', 'center', color_black);
% flip the window to display the text
Screen('Flip', win);
% Dismiss text with keyboard response
% wait for key press
while ~KbCheck()
end
% wait for release
while KbCheck()
end

if ~TEST || EYELINK_DEMO
    % Restrict to the spacebar for actual trials
    RestrictKeysForKbCheck(spacebar);
    
    % Load the background image as the first winter scene
    [practiceBackgroundImg, ~, alpha1] = imread(strcat(stimdir, 'background1.jpeg'));
    [targetImg, ~, alpha2] = imread(strcat(stimdir, 'waldo_small.png'));
    targetImg(:, :, 4) = alpha2;
    
    % random permeation of 8 locations
    rand_position_vector = [1:8];
    rand_position_vector = rand_position_vector(randperm(length(rand_position_vector)));
    
    for i = 1:8
        current_position = rand_position_vector(i);
    
        position_map_key = "f" + int2str(current_position);
        positionX_middle = positions_map(position_map_key).x;
        positionY_middle = positions_map(position_map_key).y;

        % load study image, convert to texture
        backgroundTexture = Screen('MakeTexture',win,practiceBackgroundImg);
        targetTexture = Screen('MakeTexture',win,targetImg);
    

        %% SET UP FIXATION WINDOWS
        % Define a fixation box corresponding to the fixation dot
        baseRect = [0 0 100 100];
        fixationWindow = CenterRectOnPointd(baseRect, positionX_middle, positionY_middle);        
        centerFixationWindow = CenterRect(baseRect, windowRect);

         %% PART ONE OF TRIAL : CROSS TRIAL / 500 MIN DURATION
        % supplies the title at the bottom of the eyetracker display and draws
        % to Eyelink screen during experiment
        if (minfix==1)
            fixationCross(0.500, centerFixationWindow, i, screenXpixels, screenYpixels, win,  color_black, el)
        else
            % draw the fixation cross and display it
            DrawFormattedText(win,'+','center','center',color_black);
            Screen('Flip',win);
            WaitSecs(0.50);
        end
    
        %% PART TWO OF TRIAL: VISUAL SEARCH
        [rt_space, endSecs] = waldoSearch(current_position, backgroundTexture, targetTexture, i, totalTrials, fixationWindow, centerFixationWindow, screenXpixels, screenYpixels, win, positions_map);
    
        %% PART THREE: MOUSE RESPONSE
        % revert text size back to 20 for actual text
           Screen('TextSize', win, 20);

        % draw just the background
        Screen('DrawTexture', win, backgroundTexture)
        Screen('Flip',win);
    
        % wait for the mouse press
        ShowCursor();
        [clicks, x, y] = GetClicks(win);
        click_time = GetSecs;
        rt_click = click_time - endSecs;
    
        correct = 0;
        if (x < positionX_middle + 50 && x > positionX_middle - 50 && y < positionY_middle + 100 && y > positionY_middle - 100)
            disp("correct")
            correct = 1;
            DrawFormattedText(win, 'That was correct!.\n Press any key to continue.', 'center', 'center', color_black);
        else
            disp("incorrect")
            DrawFormattedText(win, 'That was not correct!.\nAs a reminder, you need to use your mouse to click where you saw Waldo.\n Press any key to continue.', 'center', 'center', color_black);
        end
    
        Screen('Flip', win);
        HideCursor;
    
         % wait for key press
        while ~KbCheck()
        end
        % wait for release
        while KbCheck()
        end
    
      %% SAVE PRACTICE TRIAL DATA
        fprintf(datafilepointer, '%s\t%i\t%i\t%i\t%i\t%s\r\n',...
       pnum,...
       current_position,...
       rt_space,...
       rt_click,...
       correct,...
       "practice");
    end
end

DrawFormattedText(win, 'END OF PRACTICE.\nOn to the first real block of trials.\n Press any key to continue.', 'center', 'center', color_black);
Screen('Flip', win);
% Dismiss text with keyboard response
% wait for key press
while ~KbCheck()
end
% wait for release
while KbCheck()
end

if ~EYELINK_DEMO
    for i = 1:num_backgrounds

        if i >1
            % Present text indicating experiment will now begin
            displayText = sprintf('You have completed a block of trials. You have completed %d of %d groups. \n\nIf you need to rest your eyes, you may close them for a few moments.\n Please do not shift your position in the chin rest.\n\nPress any key to proceed to the next group of trials, when you are ready.', i-1, num_backgrounds);
            DrawFormattedText(win, displayText, 'center', 'center', color_black);
            % flip the window to display the text
            Screen('Flip', win);
            % Dismiss text with keyboard response
            KbStrokeWait;
        end

        DrawFormattedText(win, 'Starting a new block of trials.\n Press any key to continue.', 'center', 'center', color_black);
        Screen('Flip', win);
        % Dismiss text with keyboard response
        % wait for key press
        while ~KbCheck()
        end
        % wait for release
        while KbCheck()
        end
    
        curr_background = rand_backgrounds(i);
        curr_background = curr_background{1,1};
    
        % Load the background image and target with alpha channels
        [backgroundImg, ~, alpha1] = imread(strcat(stimdir, curr_background));
        [targetImg, ~, alpha2] = imread(strcat(stimdir, 'waldo_small.png'));
        targetImg(:, :, 4) = alpha2;
    
        % load study image, convert to texture
        backgroundTexture = Screen('MakeTexture',win,backgroundImg);
        targetTexture = Screen('MakeTexture',win,targetImg);
    
        % random permeation of 8 locations
        rand_position_vector = [1:8];
        rand_position_vector = rand_position_vector(randperm(length(rand_position_vector)));

   
        for j = 1:8

            trialNum = i * 8 + j;
            current_position = rand_position_vector(j);

            %% SET UP FIXATION WINDOWS
            position_map_key = "f" + int2str(current_position);
            positionX_middle = positions_map(position_map_key).x;
            positionY_middle = positions_map(position_map_key).y;
            
            % Define a fixation box corresponding to the fixation dot
            baseRect = [0 0 100 100];
            fixationWindow = CenterRectOnPointd(baseRect, positionX_middle, positionY_middle);        
            centerFixationWindow = CenterRect(baseRect, windowRect);
        
            %% PART ONE OF TRIAL : CROSS TRIAL / 500 MIN DURATION
            % supplies the title at the bottom of the eyetracker display and draws
            % to Eyelink screen during experiment
            if (minfix==1)
                fixationCross(0.500, centerFixationWindow, trialNum, screenXpixels, screenYpixels, win, color_black, el)
            else
                % draw the fixation cross and display it
                DrawFormattedText(win,'+','center','center',color_black);
                Screen('Flip',win);
                WaitSecs(0.50);
            end
        
            %% PART TWO OF TRIAL: VISUAL SEARCH
            [rt_space, endSecs] = waldoSearch(current_position, backgroundTexture, targetTexture, trialNum, totalTrials, fixationWindow, centerFixationWindow, screenXpixels, screenYpixels, win, positions_map);

            %% PART THREE: MOUSE RESPONSE
            % revert text size back to 20 for actual text
               Screen('TextSize', win, 20);
    
            % draw just the background
            Screen('DrawTexture', win, backgroundTexture)
            Screen('Flip',win);
        
            % wait for the mouse press
            ShowCursor();
            [clicks, x, y] = GetClicks(win);
            click_time = GetSecs;
            rt_click = click_time - endSecs;
        
            correct = 0;
            if (x < positionX_middle + 50 && x > positionX_middle - 50 && y < positionY_middle + 100 && y > positionY_middle - 100)
                correct = 1;
            end
        
            Screen('Flip', win);
            HideCursor;
        
          %% SAVE REAL TRIAL DATA
            fprintf(datafilepointer, '%s\t%i\t%i\t%i\t%i\t%s\r\n',...
           pnum,...
           current_position,...
           rt_space,...
           rt_click,...
           correct,...
           curr_background);
        end

        %% test mode, only show one full block
        if TEST == 1
            break;
        end
    end
end

%%  END TEXT
% Present text indicating experiment will now begin
DrawFormattedText(win, 'You have finished the experiment! Please get up and let the RA know you are finished.', 'center', 'center', color_black);
% flip the window to display the text
Screen('Flip', win);
% Dismiss text with keyboard response
KbStrokeWait;

%% End Experiment %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Restore keyboard output to Matlab:
ListenChar(0);

% Close eyelink file and open it
status=Eyelink('closefile');
if status ~=0
    fprintf('closefile error, status: %d\n',status)
end

status=Eyelink('ReceiveFile', edfFile);
if status~=0
    fprintf('problem: ReceiveFile status: %d\n', status);
end
if 2==exist(edfFile, 'file')
    fprintf('Data file ''%s'' can be found in ''%s''\n', edfFile, pwd );
else
    disp('unknown where data file went')
end

% Shut down eyelink system and close screen
Eyelink('Shutdown');
sca;

%% Cleanup function
function cleanup
    % Shutdown Eyelink:
    Eyelink('Shutdown');

    % Close window:
    sca;

    % Restore keyboard output to Matlab:
    ListenChar(0);
end

%% In Fixation Window Function
function fix = infixationWindow(fixationWindow, mx,my)
        % determine if gx and gy are within fixation window
        fix = mx > fixationWindow(1) &&  mx <  fixationWindow(3) && ...
            my > fixationWindow(2) && my < fixationWindow(4) ;
    end
    
function fixationCross(time, centerFixationWindow,trialNum, screenXpixels, screenYpixels, win, color_black, el)
    Eyelink('Command', 'record_status_message "Trial %d/%d - Cross Portion"', trialNum, 9);
    % draw a cross and fixation box, visible in DataViewer
    Eyelink('Command', 'clear_screen 0')
    Eyelink('command', 'draw_cross %d %d 15', screenXpixels/2, screenYpixels/2);

   % draw fixation cross
   % increase text size for proper cross formatting
   Screen('TextSize', win, 40);
   DrawFormattedText(win,'+','center','center',color_black);
   Screen('Flip',win);

    % start eyelink system
    Eyelink('StartRecording')
    %record a few samples before we actually start
    WaitSecs(0.1);
    eye_used = Eyelink('EyeAvailable');
    if eye_used == 2 %binocular
        eye_used = 1; % use the right eye data
    end

    % sync to beginning of checking for gaze
    Eyelink('Message', 'SYNCTIME')

   %WAIT TO PROCEED UNTIL 500MS OF CROSS FIXATION HAS BEEN REGISTERED
   fixationDuration = 0;
   fixationStart = GetSecs;
   while (fixationDuration < time)
    % CHECK IF STILL RECORDING
       error = Eyelink('CheckRecording');
       if error~=0
           disp('Error in Recording');
           break;
       end

      % Get eye gaze position info
      if Eyelink( 'NewFloatSampleAvailable') > 0
                    % get the sample in the form of an event structure
                    evt = Eyelink( 'NewestFloatSample');
                    evt.gx
                    evt.gy
                    if eye_used ~= -1 % do we know which eye to use yet?
                        % if we do, get current gaze position from sample
                        x = evt.gx(eye_used+1); % +1 as we're accessing MATLAB array
                        y = evt.gy(eye_used+1);
                        % do we have valid data and is the pupil visible?
                        if x~=el.MISSING_DATA && y~=el.MISSING_DATA && evt.pa(eye_used+1)>0

                            %fprintf('IN THE LOOP FOR NOT MISSING DATA')
                            fprintf('%d = x and %d = y', x,y )
                            fprintf( 'Fixation window is %d %d %d %d', centerFixationWindow(1),  centerFixationWindow(2),centerFixationWindow(3),centerFixationWindow(4))

                            mx=x;
                            my=y;
                        end

                        % Check if the current gaze position is within
                        % a fixation window around the center cross
                        if ~infixationWindow(centerFixationWindow, x, y)
                            % if not in the fixation window, restart
                            % the timer and set duration to zero
                            fixationDuration = 0;
                            fixationStart = GetSecs;
                        else
                            % if in window, increase the counters
                            fixationDuration = GetSecs - fixationStart;
                        end
                    end
      end
   end

   % WRITE TO EYELINK
    WaitSecs(0.001);
    % Defining interest area
    Eyelink('Message', '!V IAREA RECTANGLE 2 %d %d %d %d cross', centerFixationWindow(1), centerFixationWindow(2), centerFixationWindow(3), centerFixationWindow(4));

    % Define trial vars
    Eyelink('Message', '!V TRIAL_VAR TRIAL_NUM %d', trialNum);
    Eyelink('Message', '!V TRIAL_VAR POSITION CROSS');

     % INDICATE END OF TRIAL
    Eyelink('Message', 'TRIAL_RESULT 0'); 
    WaitSecs(0.001);

   Eyelink('StopRecording');
   WaitSecs(0.001);


%    if (TEST ==1)
%         DrawFormattedText(win, 'Minimum gaze detected. Press any key to continue.', 'center', 'center', color_black);
%         % flip the window to display the text
%          Screen('Flip', win);
% 
%         % Dismiss text with keyboard response
%         KbStrokeWait;
%    end
end

function [rt_space, endSecs] = waldoSearch(location, backgroundTexture, targetTexture, trialNum, totalTrials, fixationWindow, centerFixationWindow, screenXpixels, screenYpixels, win, positions_map)
    % send a 'trialID' message to mark the start of a trial in Data Viewer
        Eyelink('Message', 'Trial %d', trialNum);
        % supplies the title at the bottom of the eyetracker display and draws
        % to Eyelink screen during experiment
        Eyelink('Command', 'record_status_message "Trial %d/%d"', trialNum, totalTrials);
        % draw a cross and fixation box, visible in DataViewer
        Eyelink('Command', 'clear_screen 0')
        Eyelink('command', 'draw_cross %d %d 15', screenXpixels/2, screenYpixels/2);
        Eyelink('command', 'draw_box %d %d %d %d 15', fixationWindow(1), fixationWindow(2), fixationWindow(3), fixationWindow(4));              
       
        % start eyelink system
        Eyelink('StartRecording');
        
        % determine which eye is being used
        eye_used = Eyelink('EyeAvailable');
        if eye_used == 2 %binocular
            eye_used = 1; % use the right eye data
        end

        %record a few samples before we actually start
        WaitSecs(0.1);

        Screen('DrawTexture', win, backgroundTexture)
        current_position = location;
    
        position_map_key = "f" + int2str(current_position);
        positionX_middle = positions_map(position_map_key).x;
        positionY_middle = positions_map(position_map_key).y;
        Screen('DrawTexture', win, targetTexture, [], [positionX_middle-25 positionY_middle-55 positionX_middle+25 positionY_middle+55])

        Screen('Flip',win);
       
        startSecs = GetSecs;
        % Dismiss text with keyboard response
        % wait for key press
        while ~KbCheck()
        end
        % wait for release
        while KbCheck()
        end
        endSecs = GetSecs;
        rt_space = endSecs - startSecs;

        %% STOP RECORDING AFTER SPACE BAR PRESS

        % WRITE TO EYELINK
        WaitSecs(0.001);
        % Defining interest area
        Eyelink('Message', '!V IAREA RECTANGLE 1 %d %d %d %d waldo', fixationWindow(1), fixationWindow(2), fixationWindow(3), fixationWindow(4));
        Eyelink('Message', '!V IAREA RECTANGLE 2 %d %d %d %d cross', centerFixationWindow(1), centerFixationWindow(2), centerFixationWindow(3), centerFixationWindow(4));

        % Define trial vars
        Eyelink('Message', '!V TRIAL_VAR TRIAL_NUM %d', trialNum);
        Eyelink('Message', '!V TRIAL_VAR POSITION %d', current_position);

         % INDICATE END OF TRIAL
        Eyelink('Message', 'TRIAL_RESULT 0'); 
        WaitSecs(0.001);
        
        Eyelink('StopRecording');
        WaitSecs(0.001);
end