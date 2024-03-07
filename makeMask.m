function funcSet = makeMask(funcSet)
forceMaskRedraw = 0;
global srcFs
fIn = funcSet.initFiles.fEstimCatAv;
fOut = replace(fIn,'.nii.gz','-mask.nii.gz');
funcSet.initFiles.manBrainMask = replace(fOut,'volTs-mask.nii.gz','manBrainMask.nii.gz');

%% Create mask manually
if forceMaskRedraw || ~exist(funcSet.initFiles.manBrainMask,'file')
    cmd = {srcFs};
    cmd{end+1} = ['fslview -m single ' fIn];
    cmd = strjoin(cmd,newline); % disp(cmd)
    [status,cmdout] = system(cmd,'-echo'); if status; dbstack; error(cmdout); error('x'); end
    disp('draw mask, save with default name and close fslview')
    copyfile(fOut,funcSet.initFiles.manBrainMask)
end

%% Invert mask
funcSet.initFiles.manBrainMaskInv = replace(funcSet.initFiles.manBrainMask,'.nii.gz','Inv.nii.gz');
if forceMaskRedraw || ~exist(funcSet.initFiles.manBrainMaskInv,'file')
    cmd = {srcFs};
    cmd{end+1} = '3dcalc -overwrite \';
    cmd{end+1} = ['-prefix ' funcSet.initFiles.manBrainMaskInv ' \'];
    cmd{end+1} = ['-a ' funcSet.initFiles.manBrainMask ' \'];
    cmd{end+1} = '-expr ''-(a-1)''';
    cmd = strjoin(cmd,newline); % disp(cmd)
    [status,cmdout] = system(cmd,'-echo'); if status; dbstack; error(cmdout); error('x'); end
end

%% Add to qa
fieldList = {'fFslviewBR' 'fFslviewWR' 'fFslviewSm'};
for i = 1:length(fieldList)
    if ~contains(funcSet.qaFiles.(fieldList{i}),funcSet.initFiles.manBrainMaskInv)
        funcSet.qaFiles.(fieldList{i}) = replace(funcSet.qaFiles.(fieldList{i}),' &',[' \' newline funcSet.initFiles.manBrainMaskInv ' &']);
    end
end

