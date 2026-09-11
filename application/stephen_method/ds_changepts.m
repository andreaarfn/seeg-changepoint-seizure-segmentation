function [ipts] = ds_changepts(TF, fs, limit);

%downsample - find factor to ~100hz
if fs == 2024
    factor = 16;

elseif fs == 1024
    factor = 8; 
    
elseif fs == 512
    factor = 4;
    
end

TF_ds = downsample (TF', factor)';

%find change points

test = 8;

ipts_ds = cell (1,test);
res = zeros (1,test);

%first iteration is 2

for i = 1:test %2 through 9 (error out on 1)

[ipts_ds{i}, res(i)] = findchangepts(log(TF_ds),'Statistic','mean','MaxNumChanges',i+1);

end


%%
%findchangepts(log(TF_ds),'Statistic','mean', 'MaxNumChanges', 4);

%%

[~, res_cut] = uniquetol (res); %find unique values
res_cut = flip (res_cut); %preserve order - unique values

%number of change points - these do mostly the same thing

knee1 = knee_pt (res(res_cut), res_cut);
%knee2 = findchangepts(res(res_cut),'Statistic','linear'));

%plot (res_cut, res(res_cut))

ipts_ds = ipts_ds{knee1}; %first entry is 2 points
%ipts_ds = ipts_ds{knee2};

ipts = ipts_ds .*factor; %correct for sampling

%%

%remove points closer than (limit) seconds

min_change_idx = find (diff (ipts)<limit.*fs); %less than (limit) seconds
drop = [min_change_idx, min_change_idx+1]; %drop set

ipts(drop) = [];


end