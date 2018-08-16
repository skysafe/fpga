%%
%% Copyright 2018 SkySafe Inc.
%%
%% Decision directed equalization
%%
%% Note: It is assumed the first sample is aligned with the beginning of the long preamble.

function samples_eq = equalize_decision_directed(samples, fft_length, cp_length, lp_carriers, occupied_carriers, guard_carriers, pilot_carriers, pilot_symbols, long_ts_f)

alpha = 0.5;
beta = 1;

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
    samps_t = samples(1:fft_length);
    samps_f = fftshift(fft(samps_t));
    samps_eq = zeros(1,fft_length);
    samps_eq(lp_carriers) = samps_f(lp_carriers)./H(lp_carriers);
    samps_eq(guard_carriers) = 0;
    samps_eq(pilot_carriers) = 0;
    samples_eq(fft_length*(i-1)+1:fft_length*i) = samps_eq;
  else
    samps_t = data_samples((fft_length+cp_length)*(i-3)+1:(fft_length)*(i-2)+cp_length*(i-3));
    samps_f = fftshift(fft(samps_t));
    samps_eq = zeros(1,fft_length);
    % Equalize with existing carriers
    samps_eq(lp_carriers) = samps_f(lp_carriers)./H(lp_carriers);
    pilot_chan_est = conj(mean(samps_eq(pilot_carriers).*conj(pilot_symbols)));
    % Output samples before updating H
    samps_eq = samps_eq.*pilot_chan_est;
    samps_eq(guard_carriers) = 0;
    samps_eq(pilot_carriers) = 0;
    samples_eq(fft_length*(i-1)+1:fft_length*i) = samps_eq;
    % Decisions
    samps_decision = zeros(1,fft_length);
    samps_decision(pilot_carriers) = pilot_symbols;  % Truth
    for l=occupied_carriers
      % Assume QPSK for now...
      inphase = 2*(real(samps_eq(l)) >= 0) - 1;
      quadrature = 2*(imag(samps_eq(l)) >= 0) - 1;
      samps_decision(l) = (sqrt(2)/2)*(inphase+j*quadrature);
    end
    H_pre_avg = zeros(1,fft_length);
    H_pre_avg(lp_carriers) = samps_f(lp_carriers)./samps_decision(lp_carriers);
    % Average neighbors
    H_update = zeros(1,fft_length);
    for l=lp_carriers
      n = 0;
      s = 0;
      for k=l-beta:l+beta 
        % Skip guard bands & DC bin
        if (~isempty(find(l == k, 1)))
          n = n+1;
          s = s+H_pre_avg(l);
        end
      end
      H_update(l) = s/n;
    end
    H = (1-alpha).*H + alpha.*(H_pre_avg);
  end
end