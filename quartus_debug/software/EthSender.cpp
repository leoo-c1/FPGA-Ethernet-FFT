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

bool EthSender::sendFrame(const std::vector<int16_t>& frame_data) {
    if (!is_initialised) {
        std::cout << "Failed, socket not initialised" << std::endl;
        return false;
    }

    // Calculate the total size in bytes
    int total_bytes = frame_data.size() * sizeof(int16_t);
    const char* data_ptr = reinterpret_cast<const char*>(frame_data.data());

    // If the data is small (<= 1024 bytes), send it as one packet
    if (total_bytes <= 1024) {
        int sent = sendto(data_socket, data_ptr, total_bytes, 0, (sockaddr*)&server_addr, sizeof(server_addr));
        if (sent == SOCKET_ERROR) {
            std::cerr << "Socket Error: " << WSAGetLastError() << std::endl;
            return false;
        }
        return true;
    }

    // If the data is large, split it into two chunks
    // Chunk 1: First 1024 bytes
    int sent1 = sendto(data_socket, data_ptr, 1024, 0, (sockaddr*)&server_addr, sizeof(server_addr));
    if (sent1 == SOCKET_ERROR) return false;

    // Chunk 2: Remaining bytes
    int remaining_bytes = total_bytes - 1024;
    const char* ptr2 = data_ptr + 1024;
    
    int sent2 = sendto(data_socket, ptr2, remaining_bytes, 0, (sockaddr*)&server_addr, sizeof(server_addr));
    if (sent2 == SOCKET_ERROR) return false;

    return true;
}