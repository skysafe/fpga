%%
%% Copyright 2015 Ettus Research LLC
%%

function [D_out, corr_out, pow_out, phase_out, trigger_out] = schmidl_cox(samples,window_len,avg)

  N       = length(samples)-2*window_len;
  D       = zeros(1,N);
  D_avg   = zeros(1,N);
  corr    = zeros(1,N);
  corr_avg = zeros(1,N);
  pow     = zeros(1,N);
  pow_avg = zeros(1,N);
  phase   = zeros(1,N);
  phase_avg = zeros(1,N);
  trigger = zeros(1,N);
  trigger_avg = zeros(1,N);

  for i = 1:N-window_len
    if i == 1
      corr(i) = 0;
      pow(i) = abs(samples(i))^2;
    elseif i <= window_len
      corr(i) = 0;
      pow(i) = pow(i-1) + abs(samples(i))^2/2;      
    elseif i <= 2*window_len
      corr(i) = corr(i-1) + conj(samples(i-window_len))*samples(i);
      pow(i) = pow(i-1) + abs(samples(i))^2/2;        
    else
      corr(i) = corr(i-1) + conj(samples(i-window_len))*samples(i) - conj(samples(i-2*window_len))*samples(i-window_len);
      pow(i) = pow(i-1) + abs(samples(i))^2/2 - abs(samples(i-2*window_len))^2/2;
    end
    phase(i) = angle(corr(i));
    if i <= window_len/2
      corr_avg(i) = sum(corr(1:i))/window_len/2;
      pow_avg(i) = sum(pow(1:i))/window_len/2;
    else
      corr_avg(i) = sum(corr(i-window_len/2:i))/window_len/2;
      pow_avg(i) = sum(pow(i-window_len/2:i))/window_len/2;
    end
    phase_avg(i) = angle(corr_avg(i));
    if (pow(i) == 0)
      D(i) = 0;
    else
      D(i) = abs(corr(i))^2/(pow(i))^2;
    end
    if (pow(i) == 0)
      D_avg(i) = 0;
    else
      D_avg(i) = abs(corr_avg(i)).^2/(pow_avg(i)).^2;
    end
    if ((abs(corr(i)) - (pow(i) - (1/4)*pow(i))) > 0 && i > window_len)
      trigger(i) = 1;
    else
      trigger(i) = 0;
    end
    if ((abs(corr_avg(i)) - (pow_avg(i) - (1/4)*pow_avg(i))) > 0 && i > window_len)
      trigger_avg(i) = 1;
    else
      trigger_avg(i) = 0;
    end
  end
  
  if ~exist('avg','var')
    avg = false;
  end

  if avg
    D_out = D_avg;
    corr_out = corr_avg;
    pow_out = pow_avg;
    phase_out = phase_avg;
    trigger_out = trigger_avg;
  else
    D_out = D;
    corr_out = corr;
    pow_out = pow;
    phase_out = phase;
    trigger_out = trigger;
  end

end