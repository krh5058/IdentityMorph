function runIdentityMorph(varargin)
% Any arguments in are assumed to be property changes.

% Directory setup
p = mfilename('fullpath');
[p,~,~] = fileparts(p);

% Bin
bin = [p filesep 'bin'];
addpath(bin);

% Object setup
obj = main;
obj.path.base = p;

if nargin > 0 % Property additions
    for nargs = 1:nargin
        if isstruct(varargin{nargs})
            fnames = fieldnames(varargin{nargs});
            for j = 1:length(fnames)
                obj.(inputname(nargs)).(fnames{j}) = varargin{nargs}.(fnames{j});
            end
        else
            obj.(inputname(nargs)) = varargin{nargs};
        end
    end
end

obj.pathset;

% Diary
if obj.debug
else
    d_file = datestr(now,30);
    diary([obj.path.out filesep d_file]);
end

% Preseentation set-up
if obj.debug
else
    ListenChar(2);
    HideCursor;
    
    if ispc
        ShowHideWinTaskbarMex(0)
    end
end

try
    if obj.debug
        fprintf('\nIdentityMorph (runIdentityMorph.m): Key set-up ...\n')
    end
    
    obj.keyset;
    
    if obj.debug
        fprintf('\nIdentityMorph (runIdentityMorph.m): Done!\n')
    end
catch ME
    throw(ME)
end

try
    if obj.debug
        fprintf('\nIdentityMorph (runIdentityMorph.m): Monitor set-up ...\n')
    end
    
    obj.dispset;
    
    if obj.debug
        fprintf('\nIdentityMorph (runIdentityMorph.m): Done!\n')
    end
catch ME
    throw(ME)
end

try
    if obj.debug
        fprintf('\nIdentityMorph (runIdentityMorph.m): Experimental condition set-up ...\n')
    end
    
    obj.expset;
    
    if obj.debug
        fprintf('\nIdentityMorph (runIdentityMorph.m): Done!\n')
    end
catch ME
    throw(ME)
end

try
    if obj.debug
        fprintf('\nIdentityMorph (runIdentityMorph.m): Window set-up ...\n')
    end
    
    % Open and format window
    obj.monitor.w = Screen('OpenWindow',obj.monitor.whichScreen,obj.monitor.black);
    Screen('BlendFunction', obj.monitor.w, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA);
    Screen('TextSize',obj.monitor.w,obj.text.txtSize);
    
    if obj.debug
        fprintf('\nIdentityMorph: Done!\n')
    end
catch ME
    throw(ME)
end

try
    if obj.debug
        fprintf('\nIdentityMorph (runIdentityMorph.m): Beginning practice ...\n')
    end
    
    [tex] = obj.imgshow2([obj.path.general filesep obj.current_condition '_intro.jpg']);
    Screen('Flip',obj.monitor.w);
    
    Screen('Close',tex);
    RestrictKeysForKbCheck(obj.keys.spacekey);
    KbStrokeWait;
    
    [tex] = obj.imgshow2([obj.path.general filesep obj.current_condition '_instruct.jpg']);
    Screen('Flip',obj.monitor.w);
    
    Screen('Close',tex);
    RestrictKeysForKbCheck(obj.keys.spacekey);
    KbStrokeWait;
    
    obj.current_block = ['prac_' obj.prac_block];
    
    [tex] = obj.imgshow2([obj.path.general filesep obj.current_condition '_' obj.current_block '_blockbegin.jpg']);
    Screen('Flip',obj.monitor.w);
    
    Screen('Close',tex);
    RestrictKeysForKbCheck(obj.keys.spacekey);
    KbStrokeWait;
    
    [img, img0, imgnames, img0name] = obj.imgload();
    obj.cycle(img,img0,imgnames,img0name,0);
    
    if obj.debug
        fprintf('\nIdentityMorph (runIdentityMorph.m): Done!\n')
    end
    
catch ME
    throw(ME)
end

if obj.abort
else
    try
        if obj.debug
            fprintf('\nIdentityMorph (runIdentityMorph.m): Beginning task ...\n')
        end
        
        [tex] = obj.imgshow2([obj.path.general filesep 'begin.jpg']);
        Screen('Flip',obj.monitor.w);
        
        Screen('Close',tex);
        RestrictKeysForKbCheck(obj.keys.spacekey);
        KbStrokeWait;
        
        % Randomize block
        s_block = Shuffle(obj.block);
        
        for i = 1:length(s_block)
            
            obj.current_block = ['test_' s_block{i}];
            
            [tex1] = obj.imgshow2([obj.path.general filesep obj.current_condition '_' obj.current_block '_blockbegin.jpg']);
            Screen('Flip',obj.monitor.w);
            
            Screen('Close',tex1);
            RestrictKeysForKbCheck(obj.keys.spacekey);
            KbStrokeWait;
            
            [img, img0, imgnames, img0name] = obj.imgload();
            obj.cycle(img,img0,imgnames,img0name,1);
            
            if obj.abort
                break;
            end
        end
        
            fclose(obj.out.fid);
        
            obj.datproc(2);
            %     disp('Task finished.');
        
        [tex] = obj.imgshow2([obj.path.general filesep 'outro.jpg']);
        Screen('Flip',obj.monitor.w);
        
        Screen('Close',tex);
        RestrictKeysForKbCheck([]);
        KbStrokeWait;
        
        if obj.debug
            fprintf('\nIdentityMorph (runIdentityMorph.m): Done!\n')
        end
    catch ME
        throw(ME)
    end
end

% Clean up
if obj.debug
else
    ListenChar(0);
    ShowCursor;
    
    if ispc
        ShowHideWinTaskbarMex(1)
    end
end

Screen('CloseAll');

end