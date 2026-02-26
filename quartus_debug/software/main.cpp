#include <iostream>
#include <vector>
#include <chrono>
#include "EthSender.h"

int main() {
    std::string fpga_ip = "192.0.2.146";
    int fpga_port = 5005;

    EthSender sender(fpga_ip, fpga_port);
    std::vector<int16_t> tiny_frame = {0x7AAA, 0x7AAA}; 
    int packet_count = 0;

    auto interval = std::chrono::microseconds(2000); 
    auto next_send_time = std::chrono::high_resolution_clock::now();

    std::cout << "Starting High-Precision Spin-Wait Test..." << std::endl;

    while (true) {
        auto now = std::chrono::high_resolution_clock::now();

        if (now >= next_send_time) {
            if (sender.sendFrame(tiny_frame)) {
                if (packet_count % 10 == 0) std::cout << "." << std::flush;
                packet_count++;
            }
            
            // Set the next timestamp precisely
            next_send_time += interval;
        }
    }

    return 0;
}