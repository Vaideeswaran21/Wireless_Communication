% Simulation parameters
num_nodes = [1]; % Number of stations
simulation_duration = 86400; % in seconds
packet_sizes = [24000, 24000]; % Packet sizes in bits for data
data_rates_payload = [2e6, 2e6]; % Data rates for transmission of actual data
data_rates_wur = [62.5e3, 62.5e3]; % Data rates for reception in bits per second for data and acknowledgements
wur_sizes = [53, 24]; % Acknowledgement packet sizes in bits for different scenarios
ack_durations = [20e-6, 20e-6]; % Duration of acknowledgement transmission in seconds for different scenarios
time_step = 500e-3; % time after which AP sends a packet to a node randomly 
difs = 50e-6; % DIFS: Distributed Inter-Frame Space
sifs = 10e-6; % SIFS: Short Inter-Frame Space
slot_duration = 20e-6; % Slot duration in seconds. Related to DIFS and SIFS as: DIFS = 2*slot_duration + SIFS
backoff_window = 8; % Backoff window size
drop_prob_phy = 0.1; % Probability of packet drop due to PHY layer errors

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Power consumption parameters
power_sleep = 1e-3; % Power consumption in sleep mode (1 mW per node)
power_rx_idle = 2e-3; % Power consumption in receive idle mode (2 mW)
power_rx_busy = 5e-3; % Power consumption in receive busy mode (5 mW)
power_receiving = 10e-3; % Power consumption while receiving (10 mW)
power_tx_idle = 2e-3; % Power consumption in transmit idle mode (2 mW) = Power consumption in receive idle mode (2 mW)
power_tx_busy_WuR = 100e-3; % Power consumption in transmit busy mode for wakeup packet (100 mW)
power_wakeup_rx = 75e-6; % Power consumption in wakeup receive mode (75 micro W per node)
power_tx_busy_data = 22.4e-3; % Power consumption in transmit busy mode for data (22.4 mW)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Initialize arrays to store power consumption
power_consumption_central = zeros(length(num_nodes), length(packet_sizes));
power_consumption_peripheral = zeros(length(num_nodes), length(packet_sizes));
cumulative_power_central = zeros(1, 2 * floor(simulation_duration/time_step));
cumulative_power_peripheral = zeros(1, 2 * floor(simulation_duration/time_step));
time_stamp = zeros(1, simulation_duration/ time_step);
cumulative_power_count = 1;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Loop over different packet sizes

for s = 1:length(packet_sizes)
    packet_size = packet_sizes(s); 
    data_rate_payload = data_rates_payload(s);
    data_rate_wur = data_rates_wur(s);
    wur_size = wur_sizes(s);
    ack_duration = ack_durations(s);
    
    for n = 1:length(num_nodes)
        
        num_peripheral_nodes = num_nodes(n); % Number of peripheral nodes

        num_packets = floor(simulation_duration / time_step); % Calculate the number of packets sent by the central node

        % Initialize power consumption of the central node and peripheral nodes

        total_power_central = 0;
        total_power_peripheral = 0;

        for t = 1:num_packets

            % Calculate the various times associated with the central node and peripheral node(s).

            wifi_packet_duration = packet_size / data_rate_payload;
            wur_duration = wur_size/data_rate_wur;     
            backoff_duration = randi(backoff_window) * slot_duration;
            sleep_duration = time_step - difs - backoff_duration - wur_duration - wifi_packet_duration - (3 * sifs) - (2 * ack_duration);
            
            X = rand; % Random number to determine if packet is dropped due to PHY layer errors
            tx_count = 1;
            while X <= drop_prob_phy
                 tx_count = tx_count + 1; % Number of retransmissions
                X = rand;
            end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % Total Energy Consumption of the Central Node (We multiply by tx_count to account for retransmissions)
            
            % During DIFS, Backoff and SIFS (after Acknowledgement transmission)
            total_power_central = total_power_central + ((difs + backoff_duration + sifs) * power_rx_idle * tx_count);

            % To transmit the WuR Signal and Transmit the Data Packet
            total_power_central = total_power_central + (((wur_duration * power_tx_busy_WuR) + (wifi_packet_duration * power_tx_busy_data)) * tx_count);
            
            % To receive the Acknowledgement
            total_power_central = total_power_central + (2 * ack_duration * power_receiving * tx_count);

            % During SIFS (before the first and last Acknowledgements)
            total_power_central = total_power_central + (2 * sifs * power_rx_busy * tx_count);
            
            % Sleep mode power consumption
            total_power_central = total_power_central + (sleep_duration * power_sleep * tx_count);

            cumulative_power_central(cumulative_power_count) = total_power_central; % Cumulative power consumption of the central node
            time_stamp(t) = t * time_step; % Time stamp for the current packet

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

            % Total Energy Consumption of the Peripheral Node(s) (We multiply by tx_count to account for retransmissions)

            rx_node_num = 1;

            % Sleep mode power consumption for all nodes except the one receiving the packet
            total_power_peripheral = total_power_peripheral + (num_peripheral_nodes-rx_node_num) * power_sleep * time_step;

            % DIFS and Backoff Duration
            total_power_peripheral = total_power_peripheral + (num_peripheral_nodes * power_sleep * (difs + backoff_duration) * tx_count);
            
            % Wakeup receive mode power consumption for all nodes
            total_power_peripheral = total_power_peripheral + (num_peripheral_nodes * power_wakeup_rx * wur_duration * tx_count);
            
            % Tx Idle mode power consumption for 2 SIFS Durations for a particular set of node(s)
            total_power_peripheral = total_power_peripheral + (rx_node_num * power_tx_idle * 2 * sifs * tx_count);
            
            % Receive busy mode power consumption for 1 SIFS Duration for a particular set of node(s)
            total_power_peripheral = total_power_peripheral + (rx_node_num * power_rx_busy * sifs * tx_count);
            
            % Acknowledgement transmission power consumption for a particular set of node(s)
            total_power_peripheral = total_power_peripheral + (rx_node_num * power_tx_busy_data * 2 * ack_duration * tx_count);
            
            % Receiving busy mode power consumption for a particular set of node(s)
            total_power_peripheral = total_power_peripheral + (rx_node_num * power_receiving * wifi_packet_duration * tx_count);
            
            cumulative_power_peripheral(cumulative_power_count) = total_power_peripheral;
            cumulative_power_count = cumulative_power_count + 1;
        end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

        % Find the average power consumed by the central and peripheral nodes per transmission
        
        power_consumption_central(n, s) = total_power_central / floor((simulation_duration/time_step));
        power_consumption_peripheral(n, s) = total_power_peripheral / ((simulation_duration/time_step) * num_peripheral_nodes);
    end
end

disp("Central Power:")
disp(power_consumption_central)

disp("Peripheral Power:")
disp(power_consumption_peripheral)

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

time_stamp_ds = time_stamp(1:7200:end); % Downsample the time stamp to plot the graph
time_stamp_ds = time_stamp_ds/3600; % Convert time to hours
cumulative_power_central_ds = cumulative_power_central(1:7200:end); % Downsample the cumulative power consumption to plot the graph
cumulative_power_peripheral_ds = cumulative_power_peripheral(1:7200:end); % Downsample the cumulative power consumption to plot the graph

% Plot the total cumulative energy consumption of the central node and peripheral node(s)

figure(1);

plot(time_stamp_ds, cumulative_power_central_ds(1 : floor(length(cumulative_power_central_ds)/2)) , '-o', 'LineWidth', 2, 'DisplayName', 'IEEE801.11ba based HS Frame Format');
hold on;
plot(time_stamp_ds, cumulative_power_central_ds(floor(length(cumulative_power_central_ds)/2) + 1:end), '-o', 'LineWidth', 2, 'DisplayName', 'Customized HS Frame Format');
hold on;
plot(time_stamp_ds, cumulative_power_peripheral_ds(1 : floor(length(cumulative_power_peripheral_ds)/2)) , '-o', 'LineWidth', 2, 'DisplayName', 'IEEE801.11ba based HS Frame Format');
hold on;
plot(time_stamp_ds, cumulative_power_peripheral_ds(floor(length(cumulative_power_peripheral_ds)/2) + 1:end), '-o', 'LineWidth', 2, 'DisplayName', 'Customized HS Frame Format');

xlabel('Time (in hours)');
ylabel('Total Energy Consumed (in J)');
title('Cumulative Energy Consumption of the Central and Peripheral Nodes');
legend('Location', 'Best');
grid on;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Print the average power consumed by the central Node

disp('Average Power Consumption by the Access Point (AP):');
disp(['Wakeup Packet: IEEE802.11ba - ', num2str(power_consumption_central(1, 1)), ' W']);
disp(['Wakeup Packet: Customized - ', num2str(power_consumption_central(1, 2)), ' W']);

% Print the Optimization in the Power Consumption
disp("Power Optimized per Transmission")
disp(power_consumption_central(1, 1) - power_consumption_central(1, 2));

% Print the average power consumed by the peripheral nodes

disp('Average Power Consumption by the Peripheral Nodes:');
disp(['Wakeup Packet: IEEE802.11ba - ', num2str(power_consumption_peripheral(1, 1)), ' W']);
disp(['Wakeup Packet: Customized - ', num2str(power_consumption_peripheral(1, 2)), ' W'])

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%