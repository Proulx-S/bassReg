function estimMotionWR(files,afni3dAlineateArg,verbose)
forceReestimMotion = 0;
global srcAfni
global srcFs

if ~exist('afni3dAlineateArg','var'); afni3dAlineateArg = {}; end
if ~exist('verbose','var'); verbose = []; end
if isempty(afni3dAlineateArg); afni3dAlineateArg = {'-cost ls' '-interp quintic' '-final wsinc5'}; end
if isempty(verbose); verbose = 0; end


disp(['estimating within-run motion (second-pass moco to ' files.param.baseType '; accounting for smoothing)'])
fMask = files.manBrainMaskInv;
files.fMocoList = cell(size(files.fEstimList));
files.fMocoAvList = cell(size(files.fEstimList));
files.fMocoParamList = cell(size(files.fEstimList));
files.fMocoMatList = cell(size(files.fEstimList));
for I = 1:length(files.fEstimList)
    disp(['run' num2str(I) '/' num2str(length(files.fEstimList))])
    %%% set filename
    fIn = files.fEstimList{I};
    fBase = files.fEstimBaseList{I};
    fOut = strsplit(fIn,filesep); fOut{end} = ['mcWR_' fOut{end}]; fOut = strjoin(fOut,filesep);
    fOutParam = replace(fOut,'.nii.gz','');
    fOutAv = strsplit(fOut,filesep); fOutAv{end} = ['av_' fOutAv{end}]; fOutAv = strjoin(fOutAv,filesep);
    if forceReestimMotion || ~exist(fOut,'file')
        cmd = {srcAfni};
        %%% moco
        cmd{end+1} = '3dAllineate -overwrite \';
        cmd{end+1} = ['-base ' fBase ' \'];
        cmd{end+1} = ['-source ' fIn ' \'];
        cmd{end+1} = ['-prefix ' fOut ' \'];
        cmd{end+1} = ['-1Dparam_save ' fOutParam ' \'];
        cmd{end+1} = ['-1Dmatrix_save ' fOutParam ' \'];
        cmd{end+1} = [strjoin(afni3dAlineateArg,' ') ' \'];
        if ~isempty(fMask)
            cmd{end+1} = ['-emask ' fMask ' \'];
        end
        cmd{end+1} = '-warp shift_rotate -nopad'; % cmd{end+1} = ['-warp shift_rotate -parfix 2 0 -parfix 4 0 -parfix 5 0'];
        cmd = strjoin(cmd,newline); % disp(cmd)
        if verbose
            [status,cmdout] = system(cmd,'-echo'); if status || isempty(cmdout); dbstack; error(cmdout); error('x'); end
        else
            [status,cmdout] = system(cmd); if status || isempty(cmdout); dbstack; error(cmdout); error('x'); end
        end
        
        %%% detect smoothing
        sm = strsplit(fIn,filesep); sm = strsplit(sm{end},'_'); ind = ~cellfun('isempty',regexp(sm,'^sm\d+$')); if any(ind); sm = sm{ind}; else sm = 'sm1'; end; sm = str2num(sm(3:end));
        n = MRIread(fIn,1); n = n.nframes - 1;
        nLim = [0 n] + [1 -1].*((sm+1)/2-1);
        
        %%% average
        cmd = {srcAfni};
        cmd{end+1} = '3dTstat -overwrite \';
        cmd{end+1} = ['-prefix ' fOutAv ' \'];
        cmd{end+1} = '-mean \';
        cmd{end+1} = [fOut '[' num2str(nLim(1)) '..' num2str(nLim(2)) ']'];
        cmd = strjoin(cmd,newline); % disp(cmd)
        if verbose
            [status,cmdout] = system(cmd,'-echo'); if status || isempty(cmdout); dbstack; error(cmdout); error('x'); end
        else
            [status,cmdout] = system(cmd); if status || isempty(cmdout); dbstack; error(cmdout); error('x'); end
        end

        %%% adjust motion estimates for smoothing effects
        editMocoParam([fOutParam '.param.1D'],sm)
        editMocoParam([fOutParam '.aff12.1D'],sm)

        disp(' done')
    else
        disp(' already done, skipping')
    end

    %%% output files
    files.fMocoList{I} = fOut;
    files.fMocoAvList{I} = fOutAv;
    files.fMocoParamList{I} = [fOutParam '.param.1D'];
    files.fMocoMatList{I} = [fOutParam '.aff12.1D'];
end

%%% write means
cmd = {srcFs};
fIn = files.fMocoAvList;
fOut = replace(fIn{1},char(regexp(fIn{1},'run-\d+','match')),'run-catAv'); if ~exist(fileparts(fOut),'dir'); mkdir(fileparts(fOut)); end
fOut = strsplit(fOut,filesep); fOut{end} = replace(fOut{end},'av_',''); fOut = strjoin(fOut,filesep);
if forceReestimMotion || ~exist(fOut,'file')
    cmd{end+1} = ['mri_concat --o ' fOut ' ' strjoin(fIn,' ')];
end
files.fMocoCatAv = fOut;

fIn = fOut;
fOut = strsplit(fIn,filesep); fOut{end} = ['av_' fOut{end}]; fOut = strjoin(fOut,filesep);
if forceReestimMotion || ~exist(fOut,'file')
    cmd{end+1} = ['mri_concat --mean --o ' fOut ' ' fIn];
end
files.fMocoAvCatAv = fOut;

disp(' averaging')
if length(cmd)>1
    cmd = strjoin(cmd,newline); % disp(cmd)
    if verbose
        [status,cmdout] = system(cmd,'-echo'); if status; dbstack; error(cmdout); error('x'); end
    else
        [status,cmdout] = system(cmd); if status; dbstack; error(cmdout); error('x'); end
    end
    disp('  done')
else
    disp('  already done, skipping')
end

