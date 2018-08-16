%%
%% Copyright 2018 SkySafe Inc.
%%
function samples = generate_ofdm_symbols(symbols, fft_len, occupied_carriers, pilot_carriers, pilot_symbols, cp_len)
  if ~exist('cp_len','var')
    cp_len = 0;
  end
  num_ofdm_symbols = ceil(length(symbols)/length(occupied_carriers));
  ofdm_symbols = zeros(num_ofdm_symbols,fft_len);
  % Setup ofdm symbols
  symbols_temp = symbols;
  for i=1:num_ofdm_symbols
    if length(symbols_temp) >= length(occupied_carriers)
      ofdm_symbols(i,occupied_carriers) = symbols_temp(1:length(occupied_carriers));
      symbols_temp = symbols_temp(length(occupied_carriers)+1:end);
    else
      ofdm_symbols(i,occupied_carriers(1:length(symbols_temp))) = symbols_temp;
    end
    ofdm_symbols(i,pilot_carriers) = pilot_symbols;
  end
  % Create samples
  samples = zeros(1, num_ofdm_symbols*(fft_len+cp_len));
  for i=1:num_ofdm_symbols
    ofdm_symbol_t = ifft(ifftshift(ofdm_symbols(i,:)));
    if cp_len > 0
      samples((cp_len+fft_len)*(i-1)+1:(cp_len+fft_len)*i) = [ofdm_symbol_t(end-cp_len+1:end) ofdm_symbol_t];
    else
      samples(fft_len*(i-1)+1:fft_len*i) = ofdm_symbol_t;
    end
  end
end