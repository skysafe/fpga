%%
%% Copyright 2018 SkySafe Inc.
%%
function symbols = generate_qpsk_symbols(bytes)
  % Note: Only lower two bits are used
  num_symbols = length(bytes);
  symbols = zeros(1,num_symbols);
  for k=1:num_symbols
    bits = bitand(int8(bytes(k)),3);
    i = 2*double(bitshift(bits, -1)) - 1;
    q = 2*double(bitand(bits, 1)) - 1;
    symbols(k) = sqrt(2)/2.*(i+j*q);
  end
end