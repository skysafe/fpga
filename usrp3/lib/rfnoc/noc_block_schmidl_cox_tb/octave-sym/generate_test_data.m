%%
%% Copyright 2015 Ettus Research LLC
%%

clc;
close all;

%% User variables
gap                     = 300;   % Number of zero samples between packets
phase_offset            = pi/7;  % Phase offset
freq_offset_ppm         = -20;   % TCXO frequency offset in parts per million, typical value would be +/-20
gain                    = 0;     % dB
snr                     = 30;    % dB
D_threshold             = 0.8;   % Note: This value is later quantized to the nearest power of two of 1/sqrt(D_threshold)
data_symbols_per_packet = 200;   % Number of symbols per packet (excluding preamble)
num_packets             = 2;     % Number of packets to generate

%% Simulation variables (generally should not need to touch these)
tx_freq         = 5.3e9;
sample_rate     = 200e6;
cp_length       = 16;
fft_length      = 64;
window_length   = 64;
cordic_bitwidth = 16;
cordic_bitwidth_adj = cordic_bitwidth-3; % Lose 3 bits due to Xilinx's CORDIC scaled radians format

%% Generate test data
% From 802.11 specification
% Short preamble
short_ts_f = sqrt(13/6)*[0,0,0,0,0,0,0,0,1+j,0,0,0,-1-j,0,0,0,1+j,0,0,0,-1-j,0,0,0,-1-j,0,0,0,1+j,0,0,0,0,0,0,0,-1-j,0,0,0,-1-j,0,0,0,1+j,0,0,0,1+j,0,0,0,1+j,0,0,0,1+j,0,0,0,0,0,0,0];
short_ts_t = ifft(ifftshift(short_ts_f));
% Long preamble
long_ts_f = [0,0,0,0,0,0,1,1,-1,-1,1,1,-1,1,-1,1,1,1,1,1,1,-1,-1,1,1,-1,1,-1,1,1,1,1,0,1,-1,-1,1,1,-1,1,-1,1,-1,-1,-1,-1,-1,1,1,-1,-1,1,-1,1,-1,1,1,1,1,0,0,0,0,0];
long_ts_t = ifft(ifftshift(long_ts_f));
% Carriers
occupied_carriers = [7,8,9,10,12,13,14,15,16,17,18,19,20,21,22,23,24,26,27,28,29,30,31,32,34,35,36,37,38,40,41,42,43,44,45,46,47,48,49,50,51,52,54,55,56,57,58,59];
pilot_carriers = [11,25,39,53];
pilot_symbols = [1,1,1,1];
guard_carriers = [1,2,3,4,5,6,33,60,61,62,63,64];
lp_carriers = [occupied_carriers, pilot_carriers];

short_preamble = zeros(1,160);
for i=1:10
  short_preamble(16*(i-1)+1:16*i) = short_ts_t(1:(64/4));
end
long_preamble = [long_ts_t(end-31:end) long_ts_t long_ts_t];

%% Generate packets
preamble_offset = gap+length(short_preamble)+length(long_preamble);
packet_length = length(short_preamble)+length(long_preamble)+data_symbols_per_packet*(cp_length+fft_length);
test_data = zeros(1,num_packets*(gap+packet_length)+4*length(short_preamble));
for i=1:num_packets
  data_symbols = generate_qpsk_symbols(randi(4, data_symbols_per_packet*length(occupied_carriers))-1);
  ofdm_data_symbols = generate_ofdm_symbols(data_symbols, fft_length, occupied_carriers, pilot_carriers, pilot_symbols, 16);
  test_data(1,(gap+packet_length)*(i-1)+1:(gap+packet_length)*i) = [zeros(1, gap), short_preamble, long_preamble, ofdm_data_symbols];
end

%% Add phase offset
test_data_phase_offset = exp(2*j*phase_offset)*test_data;

%% Add frequency offset
offset = ((freq_offset_ppm/1e6)*tx_freq)/sample_rate;
expected_phase_word = ((2^cordic_bitwidth_adj)/window_length)*angle(exp(j*(window_length)*2*pi*offset))/pi;
fprintf("Expected phase word: %d (%f)\n",round(expected_phase_word),expected_phase_word);
test_data_freq_offset = add_freq_offset(test_data_phase_offset , offset);

%% Add noise, gain
test_data_n = awgn(test_data_freq_offset, snr, 'measured');
test_data_n = test_data_n  .* 10^(gain/20);

%% Schmidl Cox
[D, corr, power, phase, trigger] = schmidl_cox(test_data_n , window_length, true);
% Find peak via differentiation
D_thresh_quant = ceil(log2(1/(1-sqrt(D_threshold))));
D_approx = (abs(corr) - (power - (1/D_thresh_quant)*power));
D_approx = (D_approx > 0).*D_approx;
D_approx_diff = D_approx(2:end) - D_approx(1:end-1);
D_max = 0;
% Find first peak
for i=2:length(D_approx_diff)
    if D_approx_diff(i) < 0 && D_approx_diff(i-1) > 0
        D_max = D(i);
        peak_index = i;
        break;
    end
end

if (D_max > 0)
    fprintf("Short preamble peak found at: %d\n", peak_index);
else
    fprintf("Short preamble not detected\n");
    return
end

% figure;
% hold on;
% plot(abs(corr), 'r');
% plot(power, 'b');
% plot(real(test_data_n), 'k');
% plot(D_approx,'m');
% plot(D, 'g');
% plot(trigger, 'c');

%% Align to start of short preamble based on detected peak from Schmidl Cox
peak_offset = length(short_preamble);  % Peak is this far into short preamble
packet = test_data_n(peak_index-peak_offset:peak_index-peak_offset+packet_length+10);

%% Frequency correction
freq_corr = -phase(peak_index)/(2*window_length*pi);
fprintf("Short preamble phase word: %d (%f)\n",round(-2*freq_corr*2^cordic_bitwidth_adj),-2*freq_corr*2^cordic_bitwidth_adj);
packet_freq_corr = add_freq_offset(packet, freq_corr);

%% Remove short preamble
packet_post_sp = packet_freq_corr(length(short_preamble)-10:end); % -10 to start xcorr slightly before long preamble

%% Xcorr long preamble for detection, fine timing, and frequency offset
coeff = conj(fliplr([long_ts_t(end-15:end) long_ts_t]));
% Quantize to +/-1, reduces complex mult to 
coeff_quant = zeros(1,length(coeff));
for i = 1:length(coeff)
   coeff_quant(i) = (2*(real(coeff(i)) > 0)-1) + j*(2*(imag(coeff(i)) > 0)-1);
end
lp_xcorr = filter(coeff_quant, 1, packet_post_sp);  % Complex in, complex coefficient FIR
lp_xcorr_abs = abs(lp_xcorr);
[lp_xcorr_abs_sorted, lp_xcorr_abs_sorted_indexs] = sort(lp_xcorr_abs(1:160));
lp_xcorr_peak_indexes = sort(lp_xcorr_abs_sorted_indexs(end-1:end));  % grab two largest values, sort to make sure earlier index is first
if (lp_xcorr_peak_indexes(2) - lp_xcorr_peak_indexes(1)) ~= window_length
  fprintf("ERROR: Did not find long preamble! Peak separation incorrect!\n")
  return
else
  fprintf("Long preamble peak found at: %d\n", lp_xcorr_peak_indexes(1))
end

%% Align to start of LP
lp_start = lp_xcorr_peak_indexes(1);
packet_lp_aligned = packet_post_sp(lp_start-cp_length/2:end); % i.e. -8 from start of first lp symbol (not the cyclic prefix!)

%% Equalize
packet_eq_f = zeros(2, (data_symbols_per_packet+2)*fft_length);
packet_eq_f(1,:) = equalize_ls(packet_lp_aligned, fft_length, cp_length, lp_carriers, guard_carriers, pilot_carriers, pilot_symbols, long_ts_f);
packet_eq_f(2,:) = equalize_decision_directed(packet_lp_aligned, fft_length, cp_length, lp_carriers, occupied_carriers, guard_carriers, pilot_carriers, pilot_symbols, long_ts_f);

%% Plot
figure();
subplot(1,2,1);
plot(real(packet_eq_f(2,1:200*64)));
subplot(1,2,2);
hold on;
grid on;
plot(packet_eq_f(1,2*64:200*64),'g.');
plot(packet_eq_f(2,2*64:200*64),'b.');
plot(sqrt(2)/2.*[1+j, 1-j, -1+j, -1-j],'r*');
axis([-2 2 -2 2]);


%% Write to disk
% Convert to sc16
test_data_sc16 = zeros(1,2*length(test_data_n ));
test_data_sc16(1:2:end-1) = int16((2^15).*real(test_data_n ));
test_data_sc16(2:2:end) = int16((2^15).*imag(test_data_n ));

% Complex float
test_data_cplx_float = zeros(1,2*length(test_data_n ));
test_data_cplx_float(1:2:end-1) = real(test_data_n );
test_data_cplx_float(2:2:end) = imag(test_data_n ); 

fileId = fopen('test-sc16.bin', 'w');
fwrite(fileId, test_data_sc16, 'int16');
fclose(fileId);
fileId = fopen('test-float.bin', 'w');
fwrite(fileId, test_data_cplx_float, 'float');
fclose(fileId);
