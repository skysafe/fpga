%%
%% Copyright 2018 SkySafe Inc.
%%
%% Adapted from Software-Defined Radios for Engineers (Getz, Wyglinski) page 283
%%
%% Note: It is assumed the first sample is aligned at beginning of long preamble.

function samples_eq = equalize_ls(samples, fft_length, cp_length, lp_carriers, guard_carriers, pilot_carriers, pilot_symbols, long_ts_f)
  
long_preamble = [samples(1:fft_length), samples(fft_length+1:2*fft_length)];
data_samples = samples(2*fft_length+cp_length+1:end);
  
% Zero forcing equalizer
chan_estimates = zeros(2,fft_length);
for i = 1:2
  lp_fft = fftshift(fft(long_preamble((i-1)*fft_length+1:i*fft_length)));
  chan_est = lp_fft(lp_carriers)./long_ts_f(lp_carriers);
  chan_estimates(i,lp_carriers) = chan_est;
end
H = mean(chan_estimates);

num_symbols = ceil(length(samples)/(fft_length+cp_length));
samples_eq = zeros(1, num_symbols*fft_length);
for i = 1:num_symbols
  if i <= 2
    samps_t = long_preamble(fft_length*(i-1)+1:(fft_length)*i);
    samps_f = fftshift(fft(samps_t));
    samps_eq = samps_f./H;
    samps_eq(guard_carriers) = 0;
    samps_eq(pilot_carriers) = 0;
    samples_eq(fft_length*(i-1)+1:fft_length*i) = samps_eq;
  else
    samps_t = data_samples((fft_length+cp_length)*(i-3)+1:(fft_length)*(i-2)+cp_length*(i-3));
    samps_f = fftshift(fft(samps_t));
    % Apply averaged pilot symbols
    samps_lp_eq = samps_f./H;
    pilot_chan_est = conj(mean(samps_lp_eq(pilot_carriers).*conj(pilot_symbols)));
    samps_eq = samps_lp_eq.*pilot_chan_est;
    samps_eq(guard_carriers) = 0;
    samps_eq(pilot_carriers) = 0;
    samples_eq(fft_length*(i-1)+1:fft_length*i) = samps_eq;
  end
end