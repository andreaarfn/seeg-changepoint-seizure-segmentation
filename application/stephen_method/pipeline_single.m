%output from BS (data, chans)

fs = 512; %change
signal_all = data.F';
nChans = size(signal_all,2);
nSamples = size(signal_all,1);
time = data.Time';

bad_mask = (data.ChannelFlag == 1);

%get channel names

channels_all = cell  (nChans, 1);

for i = 1: nChans

    channels_all{i} = chans.Channel(i).Name;

end

%%

signal = signal_all(:,1);

figure
plot (time, signal)
axis tight
axis ij

[baseline, fast] = emd_baseline(signal, fs, 2); %2 hz cut for baseline

figure
subplot (2,1,1)
hold on
plot (time, signal)
plot (time, baseline)
axis tight
axis ij

subplot (2,1,2)
hold on
plot (time, fast)
axis tight
axis ij


%%
%wavelet (morse) plot using 'fast' signal

freqBand = [2, 256];
voi = 5; %matlab default is 10

fb = cwtfilterbank('SignalLength', nSamples, 'wavelet', 'Morse', 'SamplingFrequency', fs, 'FrequencyLimits', freqBand, 'VoicesPerOctave', voi); 

fvect1 = centerFrequencies(fb);
coef = cwt (fast, 'Filterbank', fb);
S1 = abs(coef) .^2; %modulus - power

%S1 = S1  .* fvect1; %1/f correction

Cmax1 = quantile(S1, 0.925, 'all');

freq_axis = 2.^(round(log2(freqBand(1))):round(log2(freqBand(2))));

figure
imagesc (time, fvect1, S1);
set(gca,'YDir','normal')
set(gca,'YScal','log')
set (gca, 'Ylim', [min(fvect1), max(fvect1)])
set (gca, 'Clim', [0, Cmax1])
set (gca, 'YTick', freq_axis)

colormap (parula)

%%
%findchangepts on downsampled data

ipts = ds_changepts(S1, fs, 2); %limit 2 second between pts

figure
imagesc (time, fvect1, S1);
set(gca,'YDir','normal')
set(gca,'YScal','log')
set (gca, 'Ylim', [min(fvect1), max(fvect1)])
set (gca, 'Clim', [0, Cmax1])
set (gca, 'YTick', freq_axis)

colormap (parula)

xline (time (ipts(:)), 'Color', 'w')

figure
plot (time, fast)
axis tight
axis ij
xline (time (ipts), 'Color', 'r')


%%
%segments

segs = numel (ipts) +1;

fast_segments = cell (1, segs);
time_segments = cell (1, segs);

fast_segments{1} = fast (1:ipts(1)); %first segment
time_segments{1} = time (1:ipts(1));

for i = 2: segs-1 

    fast_segments{i} = fast (ipts(i-1)+1 : ipts(i));
    
end

for i = 2: segs-1

    time_segments{i} = time (ipts(i-1)+1 : ipts(i));
    
end

fast_segments{segs} = fast (ipts(end) : end); %last segment
time_segments{segs} = time (ipts(end) : end);

%%

figure
subplot (2,1,1)
hold on
plot (time, signal)
plot (time, baseline)
axis tight
axis ij
xline (time (ipts(:)))

subplot (2,1,2)
hold on
plot (time, fast)
axis tight
axis ij
xline (time (ipts(:)))
parent_axis = gca;

figure

for i = 1:segs

subplot (1,segs,i)
plot (time_segments{i}, fast_segments{i})
axis tight
axis ij
set (gca, 'Ylim', parent_axis.YLim)

end

