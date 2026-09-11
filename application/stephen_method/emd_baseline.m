function [baseline, fast] = emd_baseline(x, fs, limit);
    
    [imf,residual,info] = emd(x, 'Interpolation', 'pchip');
    
    xps = info.NumZerocrossing/numel(x) .* fs; %crossing per second
    cut = find(xps < (limit.*2), 1 ); %first less than threshold (2 hz has ~4 crossing)
    
    baseline = (sum(imf(:, cut:end),2)+ residual);
    fast = (sum(imf(:, 1:(cut-1)),2));
       
end
 