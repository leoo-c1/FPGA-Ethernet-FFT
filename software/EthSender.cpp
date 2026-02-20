#include "EthSender.h"
#include <iostream>
#include <algorithm>
#include <thread>
#include <chrono>

EthSender::EthSender(const std::string& ip_address, int port) {
    is_initialised = false;
    WSADATA wsadata;

    // Initialise winsocket
    int startup = WSAStartup(MAKEWORD(2, 2), &wsadata);

    if (startup == 0) {
        std::cout << "Winsock initialised." << std::endl;

        // Create a socket with IPv4 and UDP
        data_socket = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP);

        if (data_socket == INVALID_SOCKET) {
            std::cout << "Socket creation failed, error code: " << WSAGetLastError() << std::endl;
        }

        else {
            std::cout << "Socket created." << std::endl;
            
            // Clear the current class member for server address
            memset(&server_addr, 0, sizeof(server_addr));
            server_addr.sin_family = AF_INET;
            server_addr.sin_port = htons(port);     // Format the bytes as big endian instead of little endian
            inet_pton(AF_INET, ip_address.c_str(), &server_addr.sin_addr);

            std::cout << "Address struct created." << std::endl;
            is_initialised = true;
            }
    }

    else {
        std::cout << "Failed. Error code: " << startup << std::endl;
    }
}

EthSender::~EthSender() {
    if (is_initialised && data_socket != INVALID_SOCKET) {
        closesocket(data_socket);
    }
    WSACleanup();
}

bool EthSender::sendData(const std::vector<int16_t>& data, uint32_t sample_rate) {
    // If socket isn't ready, return false
    if (!is_initialised) {
        std::cout << "Failed, socket not initialised" << std::endl;
        return false;
    }

    int total_samples = data.size();
    int samples_sent = 0;
    const int MAX_SAMPLES_PER_PACKET = 736;
    bool success = true;

    // Loop until all samples are sent
    while (samples_sent < total_samples) {
        // Calculate number of samples to send
        int samples_to_send = std::min(MAX_SAMPLES_PER_PACKET, total_samples - samples_sent);
        int bytes_to_send = samples_to_send * sizeof(int16_t);

        // Get memory address of current sample chunk
        const char* buffer_ptr = reinterpret_cast<const char*>(data.data() + samples_sent);

        int send_result = sendto(data_socket, buffer_ptr, bytes_to_send, 0, (sockaddr*)&server_addr, sizeof(server_addr));

        if (send_result == SOCKET_ERROR) {
            std::cout << "Send failed, error code: " << WSAGetLastError() << std::endl;
            success = false;
            break;
        }

        else {
            std::cout << "Sent " << send_result << " bytes" << std::endl;
            // Update sent samples count
            samples_sent += samples_to_send;

            // Add delay for the length that the byte chunk plays for
            unsigned long long delay_us = (samples_to_send * 1000000LL) / sample_rate;
            std::this_thread::sleep_for(std::chrono::microseconds(delay_us));
        }
    }

    return success;
}