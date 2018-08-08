function ea_applynormtofile_menu(~, ~, handles, useinverse, untouchedanchor, asoverlay,expdicom,fname)
if ~exist('untouchedanchor','var')
    untouchedanchor=0;
end

if untouchedanchor
    interp=0;
else
    interp=4;
end

if ~exist('expdicom','var')
    expdicom=0;
end

if ~exist('asoverlay','var')
    asoverlay=0;
end

if ~iscell(handles)
    uipatdir=getappdata(handles.leadfigure,'uipatdir');
else
    uipatdir=handles; % direct supply of cell string.
end

if ~exist('fname','var')
    [fis, path] = uigetfile({'*.nii';'*.nii.gz'}, 'Choose files to apply deformation to...', [ea_space], 'Multiselect', 'on');

    if ~ischar(fis) && ~iscell(fis)
        if ~fis
            return
        end
    end
else
    [path,fis,ext]=fileparts(fname);
    if ~isempty(path) % local file
        path=[path,filesep];
    end
    fis=[fis,ext];
end

for pt=1:length(uipatdir)
    [options.root, options.patientname] = fileparts(uipatdir{pt});
    options.root = [options.root, filesep];
    options.earoot = ea_getearoot;
    options.prefs = ea_prefs(options.patientname);
    [options,presentfiles] = ea_assignpretra(options);
    options.coregmr.method='SPM';

    if ischar(fis)
        fis = {fis};
    end

    to = cell(1, length(fis));
    from = cell(1, length(fis));

    if untouchedanchor && ~useinverse % need to map from untouched anchor anchor first
        keyboard
        ea_coreg2images(options,[options.root, options.patientname, filesep, 'raw_', presentfiles{1}],...
            [options.root, options.patientname, filesep, presentfiles{1}],...
            [options.root, options.patientname, filesep, 'uraw_', presentfiles{1}],...
            from);
    end

    for fi=1:length(fis)
        to{fi} = [uipatdir{pt},filesep, 'gl', fis{fi}];
        if isempty(path)
            from{fi} = [uipatdir{pt},filesep,fis{fi}];
        else
            from{fi} = [path, fis{fi}];
        end
    end

    ea_apply_normalization_tofile(options, from, to, [options.root, options.patientname, filesep], useinverse, interp);

    if untouchedanchor && useinverse % need to map from anchor to un touched (raw) anchor
        ea_coreg2images(options,[options.root, options.patientname, filesep, presentfiles{1}],...
            [options.root, options.patientname, filesep, 'raw_', presentfiles{1}],...
            [options.root, options.patientname, filesep, 'rraw_', presentfiles{1}],...
            to);
        if asoverlay
            untouchedanchor=ea_load_nii([options.root, options.patientname, filesep, 'raw_', presentfiles{1}]);
            overl=ea_load_nii(to{1});
            fused=untouchedanchor;
            fused.img(:)=zscore(fused.img(:));
            fused.img=fused.img+overl.img;
            fused.img=ea_minmax(fused.img);
            fused.img=fused.img*255;
            fused.dt=[2,0];
            [natpath,natfn,natext]=fileparts(untouchedanchor.fname);
            fused.fname=fullfile(natpath,[natfn,'_overlay',natext]);
            ea_write_nii(fused);
        end

        if expdicom
            [natpath,natfn,natext]=fileparts(untouchedanchor.fname);
            [filename,pathname]=uigetfile('*.*','Select sample DICOM',[natpath,filesep,'DICOM']);
            dicom_file=fullfile(pathname,filename);
            merged_file=fused.fname;
            newSeriesNumber=100;
            newSeriesDescription='LeadDBS Plan';
            mkdir(fullfile(natpath,'DICOM','LeadDBSExport'));
            outputDirectory=fullfile(natpath,'DICOM','LeadDBSExport');
            mergedImageVolume=1;
            outputImagePosition=2;

            uw_overlay_convert2dicom(dicom_file, merged_file, newSeriesNumber, newSeriesDescription, outputDirectory, mergedImageVolume, outputImagePosition);
        end
    end
end
