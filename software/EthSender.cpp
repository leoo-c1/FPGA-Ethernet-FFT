#include "EthSender.h"
#include <iostream>
#include <algorithm>
#include <thread>
#include <chrono>
#include <cstring>

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

bool EthSender::sendFrame(const std::vector<int16_t>& frame_data) {
    // If socket isn't ready, return false
    if (!is_initialised) {
        std::cout << "Failed, socket not initialised" << std::endl;
        return false;
    }

    // If frame size isn't 1024 samples, return false
    if (frame_data.size() != 1024) {
        std::cerr << "Error: Frame size must be 1024 samples." << std::endl;
        return false;
    }

    // Calculate packet size (samples 0-511 + sequence ID = 1024 bytes)
    int payload_size_bytes = 512 * sizeof(int16_t);
    int total_packet_size = payload_size_bytes + 1;  // Add 1 byte for the sequence ID
    const char* ptr1 = reinterpret_cast<const char*>(frame_data.data());

    // Send packet 1
    std::vector<char> packet1(total_packet_size);
    packet1[0] = 0x01;  // Sequence ID for first half
    
    // Copy the first 512 samples into the packet, offset by 1 byte
    std::memcpy(packet1.data() + 1, frame_data.data(), payload_size_bytes);
    
    int sent1 = sendto(data_socket, packet1.data(), total_packet_size, 0, (sockaddr*)&server_addr, sizeof(server_addr));
    if (sent1 == SOCKET_ERROR) {
        return false;
    }

    // Send packet 2
    std::vector<char> packet2(total_packet_size);
    packet2[0] = 0x02;  // Sequence ID for second half
    
    // Copy the second 512 samples into the packet, offset by 1 byte
    std::memcpy(packet2.data() + 1, frame_data.data() + 512, payload_size_bytes);
    
    int sent2 = sendto(data_socket, packet2.data(), total_packet_size, 0, (sockaddr*)&server_addr, sizeof(server_addr));
    if (sent2 == SOCKET_ERROR) {
        return false;
    }

    return true;

    return true;
}