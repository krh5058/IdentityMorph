classdef main < handle
% main.m class for Expression and similar tasks.
    
    properties
        debug = 0;
        
        subjinfo
        condition = {'Face','Car'};
        current_condition
        prac_block
        block
        current_block
        vals = {'01','02','03','04','05','06','07','08','09'};
        morph_perc = 20:10:90; % Associated with vals, not including 01 (10%)
        base_perc = 10; % Associated with 01 (10%)
        fix = 1;
        abort = 0;
        timelim = [4.5 .5 2]; % Response duration (1), ITI (2), Display duration (3 - optional)
        
        monitor
        path
        text
        keys
        keymap
        cbfeed = [zeros([5 1]); ones([5 1])]; % Counter-balance measures
        out
    end
    
    methods (Static)
        function d = listDirectory(path,varargin)
            % Search path with optional wildcards
            % path = search directory
            % varargin{1} = name filter
            % varargin{2} = extension filter
            
            narginchk(1,3);
            
            name = [];ext = [];
            
            vin = size(varargin,2);
            
            if vin==1
            name = varargin{1};
            elseif vin==2
                name = varargin{1};
                ext = varargin{2};
            end
            
            if ismac
                [~,d] = system(['ls ' path filesep '*' name '*' ext]);
            elseif ispc
                [~,d] = system(['dir /b ' path filesep '*' name '*' ext]);
            else
                error('main.m (listDirectory): Unsupported OS.');
            end
        end
    end
    
    methods
        %% Constructor
        function obj = main(varargin)
            
            % Query user: subject info, block order, kid/adult condition
            prompt={'Subject ID:'};
            name='Experiment Info';
            numlines=1;
            defaultanswer={datestr(now,30)};
            s=inputdlg(prompt,name,numlines,defaultanswer);
            
            if isempty(s)
                error('main.m (main): User Cancelled.')
            end
            
            obj.subjinfo.sid = s{1};
            
            [s,~] = listdlg('PromptString','Select a condition:',...
                'SelectionMode','single',...
                'ListString',obj.condition);
            
            if isempty(s)
                error('main.m (main): User Cancelled.')
            end
            
            obj.current_condition = lower(obj.condition{s});
            
%             if obj.rescale % Rescale obj.imgsize
%                 
%             end
            
%             % Text prep
%             obj.text.withpic = 'Which face shows more expression?';
%             obj.text.leftarrow = '<';
%             obj.text.rightarrow = '>';
%             obj.text.goodbye = WrapString('Thank you for participating!  You are now finished with this portion of the study.');
            obj.text.cberr = 'Attempted to access cb(11,1); index out of bounds because size(cb)=[10,2].';
            obj.text.txtSize = 30;
            
        end
        %%
        %% Dispset
        function [monitor] = dispset(obj)
            if obj.debug
                % Find out how many screens and use lowest screen number (laptop screen).
                whichScreen = max(Screen('Screens'));
            else
                % Find out how many screens and use largest screen number (desktop screen).
                whichScreen = min(Screen('Screens'));
            end
            
            % Rect for screen
            rect = Screen('Rect', whichScreen);
            
            % Screen center calculations
            center_W = rect(3)/2;
            center_H = rect(4)/2;
            
            % ---------- Color Setup ----------
            % Gets color values.
            
            % Retrieves color codes for black and white and gray.
            black = BlackIndex(whichScreen);  % Retrieves the CLUT color code for black.
            white = WhiteIndex(whichScreen);  % Retrieves the CLUT color code for white.
            
            gray = (black + white) / 2;  % Computes the CLUT color code for gray.
            if round(gray)==white
                gray=black;
            end
            
            % Taking the absolute value of the difference between white and gray will
            % help keep the grating consistent regardless of whether the CLUT color
            % code for white is less or greater than the CLUT color code for black.
            absoluteDifferenceBetweenWhiteAndGray = abs(white - gray);
            
            % Data structure for monitor info
            monitor.whichScreen = whichScreen;
            monitor.rect = rect;
            monitor.center_W = center_W;
            monitor.center_H = center_H;
            monitor.black = black;
            monitor.white = white;
            monitor.gray = gray;
            monitor.absoluteDifferenceBetweenWhiteAndGray = absoluteDifferenceBetweenWhiteAndGray;
            
            obj.monitor = monitor;
            
        end
        
        %% Pathset
        function pathset(obj)
            try
                obj.path.bin = [obj.path.base filesep 'bin'];
                obj.path.out = [obj.path.base filesep 'out'];
                obj.path.content = [obj.path.base filesep 'content'];
                contentcell = {'general','pictures'}; % Add to cell for new directories in 'content'
                for i = 1:length(contentcell)
                    obj.path.(contentcell{i}) = [obj.path.content filesep contentcell{i}];
                end
            catch ME
                disp(ME);
            end
        end
        %%
        
        %% Keyset
        function keyset(obj)
            % Key prep
            KbName('UnifyKeyNames');
            obj.keys.leftkey = KbName('LeftArrow');
            obj.keys.rightkey = KbName('RightArrow');
            obj.keymap = [obj.keys.leftkey obj.keys.rightkey];  % Ordering: 1 = pic1, 2 = pic2
            obj.keys.esckey = KbName('Escape');
            obj.keys.spacekey = KbName('SPACE');
        end
        %%
        
        %% Expset
        function expset(obj)
            d = obj.listDirectory(obj.path.pictures,obj.current_condition);
            d = regexp(d(1:end-1),'\n','split');
            d2 = sort(unique(cellfun(@(y)(regexp(y,[obj.current_condition '_\w*_\w*_'],'match')),d)));
            
            prac = regexp(d2{1},'_','split'); % Prac sorted first
            obj.prac_block = prac{3};
            
            obj.block = cell([(length(d2)-1) 1]);
            
            for i = 2:length(d2) % No prac block
                test = regexp(d2{i},'_','split');
                obj.block{i-1} = test{3};
            end
        end
        %%
        
        %% Rectset
        function [rect1, rect2] = getrects(obj,h1,w1,h2,w2)
            
            middle_buffer = 50;
            x1_left = ((obj.monitor.center_W - (middle_buffer/2)) - w1);
            x1_right = (obj.monitor.center_W - (middle_buffer/2));
            x2_left = (obj.monitor.center_W + (middle_buffer/2));
            x2_right = x2_left + w2;
            
            y1_extra = obj.monitor.rect(4) - h1;
            y2_extra = obj.monitor.rect(4) - h2;
            y_shift = 30;
            y1_top = floor(y1_extra/2)+y_shift;
            y2_top = floor(y2_extra/2)+y_shift;
            y1_bottom = y1_top + h1;
            y2_bottom = y2_top + h2;
            rect1 = [x1_left y1_top x1_right y1_bottom];
            rect2 = [x2_left y2_top x2_right y2_bottom];
            
        end
        %%
        
        %% Cb (Counter-balance matrix)
        function [cbout] = cb(obj)
            cbout = Shuffle(obj.cbfeed);
            cbout = [cbout ~cbout];
        end
        %%
        
        %% Imgload
        function [img, img0, imgnames, img0name] = imgload(obj)
            try
                
                d = obj.listDirectory(obj.path.pictures,obj.current_block,'.bmp'); % current_block format: [test/prac]_[block name]
                d = regexp(d(1:end-1),'\n','split');
                d = sort(d);
                
                img = cell([length(obj.vals)-1 1]);
                imgnames = cell([length(obj.vals)-1 1]);
                
                img0 = imread([obj.path.pictures filesep d{1}]); % First is practice
                img0name = d{1};
                
                for i = 2:length(obj.vals) % Not including practice
                    img{i-1} = imread([obj.path.pictures filesep d{i}]);
                    imgnames{i-1} = d{i};
                end
                
            catch ME
                disp(ME);
            end
        end
        %%
        
        %% Imgshow
        function [tex1, tex2] = imgshow(obj,pic1,pic2,rect1,rect2)
            % pic1 (left), pic2 (right)
            tex1 = Screen('MakeTexture',obj.monitor.w,pic1);
            tex2 = Screen('MakeTexture',obj.monitor.w,pic2);
            Screen('DrawTexture',obj.monitor.w,tex1,[],rect1);
            Screen('DrawTexture',obj.monitor.w,tex2,[],rect2);
        end
        %%
        
        %% Imgshow2
        function [tex] = imgshow2(obj,picstring)
           picmat = imread(picstring);
           tex = Screen('MakeTexture',obj.monitor.w,picmat);
           Screen('DrawTexture',obj.monitor.w,tex);
        end
        %%
        
        %% Practice
        function practice(obj,img100,img0)
            RestrictKeysForKbCheck([obj.keys.esckey obj.keymap]); 
            endflag = 0;
            while ~endflag
                if randi([0 1])
                    pic1 = 'img100';
                    pic2 = 'img0';
                    answer = obj.keymap(1);
                else
                    pic1 = 'img0';
                    pic2 = 'img100';
                    answer = obj.keymap(2);
                end
                
                [tex] = obj.imgshow2([obj.path.general filesep 'practrial.jpg']);
                [tex1,tex2] = obj.imgshow(eval(pic1),eval(pic2));
                Screen('Flip',obj.monitor.w);
                
                Screen('Close',tex);
                Screen('Close',tex1);
                Screen('Close',tex2);
%                 tic
                start = GetSecs;
                keyIsDown = 0;
                drop = 0;
                while (GetSecs-start) < (obj.timelim(1) + obj.pracadd)
                    
                    if ~drop
                        if numel(obj.timelim) >= 3
                            if (GetSecs-start) > (obj.timelim(3) + obj.pracadd)
                                [tex] = obj.imgshow2([obj.path.general filesep 'practrial.jpg']);
                                Screen('Flip',obj.monitor.w);
                                Screen('Close',tex);
                                drop = 1;
%                                 toc
                            end
                        end
                    end
                    
                    [keyIsDown,secs,keyCode]=KbCheck; %#ok<ASGLU>
                    if keyIsDown
                        if find(keyCode) == obj.keys.esckey
                            endflag = 1;
                            obj.abort = 1;
%                             disp('abort')
                        elseif find(keyCode) == answer
                            % Audio
%                             disp('Correct');
                            endflag = 1;
                            if obj.audio_on
                                obj.playaudio(obj.audio.dat{1});
                            end
                        else
                            % Audio
%                             disp('Incorrect');
                            if obj.audio_on
                                obj.playaudio(obj.audio.dat{2});
                            end
                        end
                        break;
                    end
                end
%                 toc
                
                if ~keyIsDown
%                    disp('Incorrect');
                   if obj.audio_on
                       obj.playaudio(obj.audio.dat{2});
                   end
                end
                                    
                if obj.fix
                    Screen('DrawLine',obj.monitor.w,obj.monitor.white,obj.monitor.center_W-20,obj.monitor.center_H,obj.monitor.center_W+20,obj.monitor.center_H,7);
                    Screen('DrawLine',obj.monitor.w,obj.monitor.white,obj.monitor.center_W,obj.monitor.center_H-20,obj.monitor.center_W,obj.monitor.center_H+20,7);
                end
                
                Screen('Flip',obj.monitor.w);
                pause(obj.timelim(2));
%                 toc
            end
        end
        
        %% Cycle
        function cycle(obj,img,img0,imgnames,img0name,record)
            if record
                obj.datproc(1);
            end
            
            endflag = 0;
            cb = obj.cb;
            i = 1;
            step = 6; % Value = '07', img begins with '02'
            track = 0; % Track 5 incorrects
            track_c = 0; % Track 3 corrects on hardest trial (in a row)
            thresh = [];
            threshcalc = []; % Value used in thresh calculation (typically step above, but not if prior trial was incorrect)
            RestrictKeysForKbCheck([obj.keys.esckey obj.keymap]); 
              
            while ~endflag
                try
                    if i > size(cb,1)
                        i = 1;
                    end
                    
                    if cb(i,1)
                        pic1 = 'img{step}';
                        pic1name = imgnames{step};
                        pic2 = 'img0';
                        pic2name = img0name;
   
                        answer = obj.keymap(2); % Right is correct (img0)
                    else
                        pic1 = 'img0';
                        pic1name = img0name;
                        pic2 = 'img{step}';
                        pic2name = imgnames{step};

                        answer = obj.keymap(1); % Left is correct (img0)
                    end
                    
                    [tex] = obj.imgshow2([obj.path.general filesep obj.current_condition '_' obj.current_block '_trial.jpg']);
                    [rect1,rect2] = obj.getrects(size(eval(pic1),1),size(eval(pic1),2),size(eval(pic2),1),size(eval(pic2),2));
                    [tex1,tex2] = obj.imgshow(eval(pic1),eval(pic2),rect1,rect2);
                    Screen('Flip',obj.monitor.w);
                    
                    Screen('Close',tex);
                    Screen('Close',tex1);
                    Screen('Close',tex2);
%                     tic
                    start = GetSecs;
                    keyIsDown = 0;
                    drop = 0;
                    while (GetSecs-start) < obj.timelim(1)
                        
                        if ~drop
                            if numel(obj.timelim) >= 3
                                if (GetSecs-start) > obj.timelim(3)
                                    [tex] = obj.imgshow2([obj.path.general filesep obj.current_condition '_' obj.current_block '_trial.jpg']);
                                    Screen('Flip',obj.monitor.w);
                                    Screen('Close',tex);
                                    drop = 1;
%                                     toc
                                end
                            end
                        end
                        
                        [keyIsDown,secs,keyCode]=KbCheck; 
                        if keyIsDown
                            if find(keyCode) == obj.keys.esckey
                                endflag = 1;
                                obj.abort = 1;
                                
                                if obj.debug
                                    fprintf('main.m (cycle): Aborted!\n')
                                end
                                
                            elseif find(keyCode) == answer
                                
                                threshcalc = obj.morph_perc(step); 

                                if obj.debug
                                    fprintf('main.m (cycle): Correct!\n');
                                    fprintf(['main.m (cycle): Image name - ' imgnames{step} '\n']);
                                    fprintf(['main.m (cycle): threshcalc - ' num2str(threshcalc) '\n']);
                                end
                                
                                if step == 1
                                    track_c = track_c + 1; % Add consecutive successes only for step == 1
                                    if track_c == 3
                                        % Calculate thresh using mean of
                                        % obj.base_perc and obj.morph_perc.
                                        % Average with running thresh and abort
                                        thresh = mean([mean([obj.base_perc obj.morph_perc(step)]) thresh]);
                                        endflag = 1;
                                    end
                                else
                                    step = step - 1;
                                end
                                
                                % Record (after thresh calc if step==1)
                                if record
                                    fprintf(obj.out.fid,'%s,%s,%s,%1.2f,%i,%i,%2.2f\n',obj.subjinfo.sid,pic1name,pic2name,secs-start,1,0,thresh);
                                end
                                
                            else
                                
                                % Record
                                thresh = mean([mean([threshcalc obj.morph_perc(step)]) thresh]);
                                threshcalc = thresh;
                                                             
                                if obj.debug
                                    fprintf('main.m (cycle): Incorrect!\n');
                                    fprintf(['main.m (cycle): Image name - ' imgnames{step} '\n']);
                                    fprintf(['main.m (cycle): threshcalc - ' num2str(threshcalc) '\n']);
                                end
                                
                                if record
                                    fprintf(obj.out.fid,'%s,%s,%s,%1.2f,%i,%i,%2.2f\n',obj.subjinfo.sid,pic1name,pic2name,secs-start,0,1,thresh);
                                end
                                
                                track_c = 0; % Incorrect resets track_c to 0
                                track = track + 1;
                                
                                if track == 5
                                    endflag = 1;
                                else
                                    step = step + 2;
                                    if step > length(obj.morph_perc)
                                        step = length(obj.morph_perc);
                                    end
                                end
                            end
                            break;
                        end
                    end
                    
                    if ~keyIsDown % No response
                        % Record
                        thresh = mean([mean([threshcalc obj.morph_perc(step)]) thresh]);
                        threshcalc = thresh;
                                
                        if obj.debug
                            fprintf('main.m (cycle): No response!\n');
                            fprintf(['main.m (cycle): Image name - ' imgnames{step} '\n']);
                            fprintf(['main.m (cycle): threshcalc - ' num2str(threshcalc) '\n']);
                        end
                        
                        if record
                            fprintf(obj.out.fid,'%s,%s,%s,%1.2f,%i,%i,%2.2f\n',obj.subjinfo.sid,pic1name,pic2name,[],0,1,thresh);
                        end
                        
                        track_c = 0; % Incorrect resets track_c to 0
                        track = track + 1;
                        
                        if track == 5
                            endflag = 1;
                        else
                            step = step + 2;
                            if step > length(obj.morph_perc)
                                step = length(obj.morph_perc);
                            end   
                        end
                    end
%                     toc
                    
                    if obj.debug
                        fprintf(['main.m (cycle): Next image name - ' imgnames{step} '\n']);
                        fprintf(['main.m (cycle): Track number - ' num2str(track) '\n']);
                    end
                    
                    i = i + 1;
                    
                    if obj.fix
                        Screen('DrawLine',obj.monitor.w,obj.monitor.white,obj.monitor.center_W-20,obj.monitor.center_H,obj.monitor.center_W+20,obj.monitor.center_H,7);
                        Screen('DrawLine',obj.monitor.w,obj.monitor.white,obj.monitor.center_W,obj.monitor.center_H-20,obj.monitor.center_W,obj.monitor.center_H+20,7);
                    end
                    
                    Screen('Flip',obj.monitor.w);
                    pause(obj.timelim(2));
%                     toc
                    
                catch ME
                    if strcmp(ME.message,obj.text.cberr)
                        cb = obj.cb;
                        i = 1;
                    else
                        disp(ME.message)
                        endflag = 1;
%                         break;
                    end
                end
            end
        end
        %%
        
        %% Datproc
        function datproc(obj,type)
            if type == 1
                obj.out.h = {'Subject','Left','Right','RT','Acc','Reversal','Thresh Avg.'};
                obj.out.fid = fopen([obj.path.out filesep obj.subjinfo.sid '.csv'],'a');
                fprintf(obj.out.fid,'%s,%s,%s,%s,%s,%s,%s\n',obj.out.h{:});
            elseif type == 2
                
                try
                    obj.out.h2 = {'Condition','TotalTrials','Reversals','FinalThresh','CorrectRT','IncorrectRT'};
                    obj.out.fid2 = fopen([obj.path.out filesep obj.subjinfo.sid '.csv']);
                    dat = textscan(obj.out.fid2, '%s%s%s%s%s%s%s','Delimiter',',');
                    dat = [dat{:}];
                    cond = 0;
                    head = [];
                    
                    for i = 1:size(dat,1)
                        if all(strcmp(dat(i,:),obj.out.h));
                            head = [head i];
                            cond = cond + 1;
                        end
                    end
                    
                    if (head(end) + 1) > size(dat,1)
                        head = head(1:end-1);
                    end
                        
                    temp = cellfun(@(y)(regexp(y,'_','split')),dat(head + 1,2),'UniformOutput',false);
                    condnames = cellfun(@(y)(y{3}),temp,'UniformOutput',false);
                    
                    for i = 1:length(head)
                        if i == length(head)
                            x2 = 'end';
                        else
                            x2 = 'head(i + 1)-1';
                        end
                        dat2.(condnames{i}) = eval(['dat(head(i):' x2 ',:);']);
                    end
                    
                    out2 = cell([length(condnames) length(obj.out.h2)]);
                    out2(:,1) = condnames;
                    
                    for i = 1:length(condnames)
                        out2{i,2} = size(dat2.(condnames{i}),1)-1;
                        rev = regexp([dat2.(condnames{i}){2:end,6}],'1');
                        correct = setxor(2:size(dat2.(condnames{i}),1),rev+1);
                        
                        if ~isempty(rev)
                            out2{i,3} = length(rev);
                        end
                        
                        out2{i,4} = str2num(dat2.(condnames{i}){end,end}); %#ok<*ST2NM>
                        corrRT = cellfun(@(y)(str2num(y)),dat2.(condnames{i})(correct,4),'UniformOutput',false);
                        out2{i,5} = mean([corrRT{:}]);
                        
                        if ~isempty(rev)
                            incorrRT = cellfun(@(y)(str2num(y)),dat2.(condnames{i})(rev+1,4),'UniformOutput',false);
                            out2{i,6} = mean([incorrRT{:}]);
                        end
                        
                    end
                    
                    cell2csv([obj.path.out filesep obj.subjinfo.sid '_summary.csv'],[obj.out.h2; out2]);
                    
                catch ME
                    throw(ME)
                end
            end
        end
    end
    
end

